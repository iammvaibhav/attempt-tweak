@interface DDSearchResultDictionarySection
-(NSArray *)results;
@end

@interface DDSearchResultFooterSection
-(NSArray *)results;
-(void)setResults:(NSArray *)arg1 ;
@end

@interface SFFormattedText
@property (copy) NSString * text;
@end

@interface SFRichText : NSObject
-(NSArray *)formattedTextPieces;
-(void)setText:(NSString *)arg1 ;
-(NSString *)text;
-(id)init;
@end

@interface SFSearchResult : NSObject
-(SFRichText *)title;
-(void)setTitle:(SFRichText*)arg1;
-(id)init;
@end

@interface SearchUIDetailedRowModel
-(void)setTitle:(SFRichText *)arg1 ;
-(SFRichText *)title;
@end

@interface SearchUITableViewController
@property UIViewController *parentViewController;
@end

@interface DDParsecServiceCollectionViewController : NSObject
-(void)doneButtonPressed:(id)arg1;
-(void)showLoadingSpinner:(BOOL)arg1;
-(NSArray *)sections;
@end

@interface FirebaseHandler
+ (void)handleWord:(NSString*)word;
+ (void)addWordToFirebase:(NSString*)word withSession:(NSURLSession*)session;
+ (void)updateAccessedWord:(NSDictionary*)word key:(NSString*)key withSession:(NSURLSession*)session;
+ (void)removeSavedWord:(void (^)(void))onDelete;
@end

@interface SiriWordHandler
+(void)reset;
+(void)handleTitle:(NSString*)title;
+(void)handleWord:(NSString*)word;
@end

@interface SiriUISashItem
@property NSString* title;
@end

@interface SiriUIReusableHeaderView
@property NSString* titleText;
@end