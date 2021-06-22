#include "Headers.h"
#include "RemoteLog.h"

static NSString* firebaseDatabaseURL = @"<--firebase-database-url-->";
static NSString* wordToStore = nil;
static NSString* wordKeyInFirebase = nil;

%subclass FirebaseHandler : NSObject

/**
 * Handle the "word". If it doesn't exist, add it. Otherwise touch it to reflect that it has been looked up again
 */
%new
+ (void)handleWord:(NSString*)word {
	NSString* getWordURL = [NSString stringWithFormat:@"%@/words.json?orderBy=\"word\"&equalTo=\"%@\"", firebaseDatabaseURL, word];
	getWordURL = [getWordURL stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLQueryAllowedCharacterSet]];
	NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:getWordURL]];

	[urlRequest setHTTPMethod:@"GET"];

	NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
	NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

	NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
  		NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
  		if(httpResponse.statusCode == 200) {
    		NSError *parseError = nil;
    		NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
			if ([responseDictionary count] == 0) { // word doesn't exist. Create a new entry
				[%c(FirebaseHandler) addWordToFirebase:word withSession:session];
			} else { // word already exist. Update the hit count
				for (NSString *key in responseDictionary) {
					wordKeyInFirebase = key;
    				NSDictionary* word = responseDictionary[key];
    				[%c(FirebaseHandler) updateAccessedWord:word key:key withSession:session];
				}
			}
  		} else {
    		NSLog(@"Error %@", error);
  		}
	}];
	[dataTask resume];
}

/**
 * Add a new word to the word list in firebase
 */
%new
+ (void)addWordToFirebase:(NSString*)word withSession:(NSURLSession*)session {
	long long currentTimeInMillis = (long long)([[NSDate date] timeIntervalSince1970] * 1000.0);
	NSDictionary *wordObject = @{
		@"word": word,
		@"lastUpdated": @(currentTimeInMillis),
		@"hitCount": @1
	};

	NSError *error; 
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:wordObject 
											options:0 // Pass NSJSONWritingPrettyPrinted for pritty print
                                         	error:&error];

	if (!jsonData) {
    	NSLog(@"Got an error: %@", error);
	} else {
    	// NSString *wordJSONBody = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
		NSString* saveWordURL = [NSString stringWithFormat:@"%@/words.json", firebaseDatabaseURL];
		NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:saveWordURL]];
		[urlRequest setHTTPMethod:@"POST"];
		[urlRequest setHTTPBody: jsonData];
		
		NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
  			NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
  			if(httpResponse.statusCode == 200) {
    			NSError *parseError = nil;
    			NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
				wordKeyInFirebase = responseDictionary[@"name"];
  			} else {
    			NSLog(@"Error %@", error);
  			}
		}];
		[dataTask resume];
	}
}

/**
 * Given a word object, update its hitCount & lastAccessed. This currently DOES NOT takes care of race condition
 */
%new
+ (void) updateAccessedWord:(NSDictionary*)word key:(NSString*)key withSession:(NSURLSession*)session {
	NSNumber* currentTimeInMillis = @((long long)([[NSDate date] timeIntervalSince1970] * 1000.0));
	NSNumber* updatedHitCount = [NSNumber numberWithInt:[word[@"hitCount"] intValue] + 1];

	NSDictionary* updatedValues = @{
		@"hitCount": updatedHitCount,
		@"lastUpdated": currentTimeInMillis
	};
	
	NSError *error; 
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:updatedValues 
											options:0 // Pass NSJSONWritingPrettyPrinted for pritty print
                                         	error:&error];

	if (!jsonData) {
    	NSLog(@"Got an error: %@", error);
	} else {
		NSString* updateWordURL = [NSString stringWithFormat:@"%@/words/%@.json", firebaseDatabaseURL, key];
		NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:updateWordURL]];
		[urlRequest setHTTPMethod:@"PATCH"];
		[urlRequest setHTTPBody: jsonData];

		NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
  			NSHTTPURLResponse *httpResponse = (NSHTTPURLResponse *)response;
  			if(httpResponse.statusCode == 200) {
    			// NSError *parseError = nil;
    			// NSDictionary *responseDictionary = [NSJSONSerialization JSONObjectWithData:data options:0 error:&parseError];
  			} else {
    			NSLog(@"Error %@", error);
  			}
		}];
		[dataTask resume];
	}

}

/**
 * Remove the word from firebase
 */
%new
+ (void) removeSavedWord:(void (^)(void))onDelete {
	if (wordKeyInFirebase != nil) {
		NSString* deleteWordURL = [NSString stringWithFormat:@"%@/words/%@.json", firebaseDatabaseURL, wordKeyInFirebase];
		NSMutableURLRequest *urlRequest = [[NSMutableURLRequest alloc] initWithURL:[NSURL URLWithString:deleteWordURL]];

		[urlRequest setHTTPMethod:@"DELETE"];

		NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
		NSURLSession *session = [NSURLSession sessionWithConfiguration:config];

		NSURLSessionDataTask *dataTask = [session dataTaskWithRequest:urlRequest completionHandler:^(NSData *data, NSURLResponse *response, NSError *error) {
			onDelete();
		}];
		[dataTask resume];
	}
}

%end;

// -------------- Saving words searched via Lookup --------------
%group Lookup

/**
 * Add the looked-up word
 */
%hook DDLookupQuery

+(DDSearchResultDictionarySection*)dictionarySectionForString:(id)arg1 queryId:(unsigned long long)arg2  {
	wordToStore = [arg1 lowercaseString];
	
	DDSearchResultDictionarySection* dictionarySection = %orig;

	if (dictionarySection) {
		NSArray* results = [dictionarySection results];
		for (SFSearchResult* result in results) {
    		NSArray* formattedTextPieces = [[result title] formattedTextPieces];
			if ([formattedTextPieces count] > 0) {
				SFFormattedText* formattedText = formattedTextPieces[0];
				if (![formattedText.text containsString:@"·"]) {
					wordToStore = formattedText.text;
					break;
				}
			}
		}
	}
	
	[%c(FirebaseHandler) handleWord:wordToStore];
	
	return dictionarySection;
}

%end

/**
 * Add the remove word section in the footer
 */
%hook DDSearchResultFooterSection
-(NSArray*)results {
	NSArray* results = %orig;
	NSMutableArray *modifiedResults = [NSMutableArray arrayWithCapacity:3];
	SFSearchResult* removeWord = [[SFSearchResult alloc] init];
	SFRichText* removeWordText = [[SFRichText alloc] init];
	[removeWordText setText:[[NSString alloc] initWithFormat:@"Remove: %@", wordToStore]];
	[removeWord setTitle:removeWordText];
	[modifiedResults addObject:removeWord];

	// add original results
	for (id result in results) {
		[modifiedResults addObject:result];
	}
	
	return modifiedResults;
}
%end

/**
 * Detect if user clicked on Remove word button and remove the word
 */
%hook SearchUITableViewController
-(void)tableView:(id)arg1 didSelectRowAtIndexPath:(NSIndexPath*)indexPath {

	UIViewController* root = [[[[[UIApplication sharedApplication] keyWindow] rootViewController] childViewControllers] firstObject];
	if (root != nil && [root isKindOfClass:%c(DDParsecServiceCollectionViewController)]) {
		DDParsecServiceCollectionViewController* rootController = (DDParsecServiceCollectionViewController*) root;
		NSArray* sections = [rootController sections];

		if (indexPath.section == [sections count] - 1) {
			// last section, first result should be Remove...
			if (sections != nil && [[sections lastObject] isKindOfClass:%c(DDSearchResultFooterSection)]) {
				DDSearchResultFooterSection* footerSection = [sections lastObject];
				SFSearchResult* removeResult = [[footerSection results] firstObject];
				if (removeResult != nil && [[[removeResult title] text] isEqualToString:[[NSString alloc] initWithFormat:@"Remove: %@", wordToStore]]) {
					//remove the word
					[rootController showLoadingSpinner:YES];
					[%c(FirebaseHandler) removeSavedWord:^{
						[rootController doneButtonPressed:nil];
					}];
					
				} else {
					%orig;
				}
			} else {
				%orig;
			}
		} else {
			%orig;
		}
	} else {
		%orig;
	}
}

%end

/**
 * Clean up
 */
%hook DDParsecServiceCollectionViewController
-(void)doneButtonPressed:(id)arg1 {
	RLog(@"doneButtonPressed");
	wordToStore = nil;
	wordKeyInFirebase = nil;
	%orig;
}
%end

%end

// -------------- Saving words searched via Siri --------------
%group Siri

%subclass SiriWordHandler : NSObject
	static NSString* sashItemTitle = nil;
	static BOOL firstReceived = NO;

	%new 
	+(void) reset {
		sashItemTitle = nil;
		firstReceived = NO;
	}

	%new
	+(void) handleTitle:(NSString*)title {
		sashItemTitle = title;
	}

	%new
	+(void) handleWord:(NSString*)word {
		if (!firstReceived) {
			firstReceived = YES;
		} else {
			if ([sashItemTitle isEqualToString:@"DICTIONARY"]) {
				[%c(FirebaseHandler) handleWord:word];
				[%c(SiriWordHandler) reset];
			}
		}
	}

%end

%hook SiriUISashItem
-(id) title {
	NSString* r = %orig;
	[%c(SiriWordHandler) handleTitle:r];
	return r;
}
%end

%hook SiriUIReusableHeaderView
- (void)setTitleText:(id)word {
	%orig;
	[%c(SiriWordHandler) handleWord:[word lowercaseString]];
}
%end

%end

%ctor {
	%init
    NSString *bundleID = NSBundle.mainBundle.bundleIdentifier;
    if ([bundleID isEqualToString:@"com.apple.datadetectors.DDActionsService"]) {
        %init(Lookup);
    } else if ([bundleID isEqualToString:@"com.apple.siri"]) {
        %init(Siri);
    } else {
        NSLog(@"Tweak loaded into unexpected process, not hooking");
    }
}