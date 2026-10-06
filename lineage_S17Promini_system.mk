# System-only first-boot target; retain the original boot and vendor on device.
# Let Lineage select ro.adb.secure=0 without adding a duplicate property.
ifneq ($(filter userdebug eng,$(TARGET_BUILD_VARIANT)),)
WITH_ADB_INSECURE := true
endif
$(call inherit-product, device/lvmi/S17Promini/lineage_S17Promini.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_release.mk)

PRODUCT_NAME := lineage_S17Promini_system
PRODUCT_SHIPPING_API_LEVEL := 31
PRODUCT_EXTRA_VNDK_VERSIONS := 31
PRODUCT_BUILD_BOOT_IMAGE := false
PRODUCT_BUILD_RECOVERY_IMAGE := false
PRODUCT_BUILD_VENDOR_BOOT_IMAGE := false
PRODUCT_BUILD_PRODUCT_IMAGE := false
PRODUCT_BUILD_SYSTEM_EXT_IMAGE := false
PRODUCT_PRODUCT_PROPERTIES += ro.sf.lcd_density=180
PRODUCT_COPY_FILES += \
    device/lvmi/S17Promini/rootdir/init.s17promini-rom.rc:$(TARGET_COPY_OUT_SYSTEM)/etc/init/init.s17promini-rom.rc
