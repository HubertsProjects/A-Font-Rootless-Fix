ifeq ($(THEOS_PACKAGE_SCHEME),rootless)
TARGET = iphone:14.5:14.5
PREFIX="/Applications/Xcode.app/Contents/Developer/Toolchains/XcodeDefault.xctoolchain/usr/bin/"
else
TARGET = iphone:12.2:12.2
PREFIX="/Library/Developer/TheosToolchains/Xcode11.xctoolchain/usr/bin/"
endif
ARCHS = arm64 arm64e

include $(THEOS)/makefiles/common.mk

BUNDLE_NAME = AFontPrefs
AFontPrefs_FILES = AFPRootListController.m AFPBlackListController.m
AFontPrefs_INSTALL_PATH = /Library/PreferenceBundles
AFontPrefs_FRAMEWORKS = UIKit
AFontPrefs_PRIVATE_FRAMEWORKS = Preferences CoreServices
# AFontPrefs_LIBRARIES = applist

include $(THEOS_MAKE_PATH)/bundle.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/AFontPrefs.plist$(ECHO_END)
