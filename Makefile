TARGET := iphone:clang:latest:7.0
INSTALL_TARGET_PROCESSES = SpringBoard


include $(THEOS)/makefiles/common.mk

TWEAK_NAME = import
BUNDLE_NAME = ImportPrefs

import_FRAMEWORKS = StoreKit UIKit
import_FILES = $(wildcard ./src/*.xm) $\
	$(wildcard ./src/*.m) $\
	$(wildcard ./src/**/*.m) $\
	$(wildcard ./SharedLibraries/*.m) $\
	$(wildcard ../SharedLibraries/*.m) $\
	Tweak.xm
import_RESOURCE_FILES = Config.plist
import_CFLAGS = -fobjc-arc
import_CFLAGS += -DAPI_HOST=@\"$(API_HOST)\"

ImportPrefs_FILES = prefs/ImportPrefsRootListController.m
ImportPrefs_FRAMEWORKS = UIKit
ImportPrefs_PRIVATE_FRAMEWORKS = Preferences
ImportPrefs_INSTALL_PATH = /Library/PreferenceBundles
ImportPrefs_RESOURCE_FILES = prefs/Resources/Root.plist
ImportPrefs_CFLAGS = -fobjc-arc

include $(THEOS_MAKE_PATH)/tweak.mk
include $(THEOS_MAKE_PATH)/bundle.mk

before-package::
	@mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences
	@cp prefs/ImportPrefs.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ImportPrefs.plist
