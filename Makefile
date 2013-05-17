export FW_DEVICE_IP=10.0.1.4

include theos/makefiles/common.mk

TOOL_NAME = extensionmand
extensionmand_FILES = main.mm
extensionmand_INSTALL_PATH = /usr/bin/
extensionmand_FRAMEWORKS = CoreFoundation
extensionmand_PRIVATE_FRAMEWORKS = AppSupport

BUNDLE_NAME = ExtensionManager
ExtensionManager_FILES = ExtensionManager.mm
ExtensionManager_INSTALL_PATH = /Library/PreferenceBundles
ExtensionManager_FRAMEWORKS = UIKit CoreGraphics
ExtensionManager_PRIVATE_FRAMEWORKS = Preferences AppSupport

include $(THEOS_MAKE_PATH)/bundle.mk
include $(THEOS_MAKE_PATH)/tool.mk

internal-stage::
	$(ECHO_NOTHING)mkdir -p $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences$(ECHO_END)
	$(ECHO_NOTHING)cp entry.plist $(THEOS_STAGING_DIR)/Library/PreferenceLoader/Preferences/ExtensionManager.plist$(ECHO_END)
