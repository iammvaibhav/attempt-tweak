TARGET := iphone:clang:14.4:7.0
INSTALL_TARGET_PROCESSES = DDActionsService Siri
ARCHS = arm64 arm64e
THEOS_DEVICE_IP = 192.168.29.145


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = Attempt

$(TWEAK_NAME)_FRAMEWORKS = UIKit
$(TWEAK_NAME)_PRIVATE_FRAMEWORKS = SearchUI SearchFoundation

Attempt_FILES = Tweak.x
Attempt_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
