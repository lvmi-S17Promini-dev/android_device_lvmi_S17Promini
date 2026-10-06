# System bring-up target with original boot and a cleaned stock vendor image.
# Let Lineage select ro.adb.secure=0 without adding a duplicate property.
ifneq ($(filter userdebug eng,$(TARGET_BUILD_VARIANT)),)
WITH_ADB_INSECURE := true
endif
$(call inherit-product, device/lvmi/S17Promini/common.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_release.mk)
$(call inherit-product, vendor/lvmi/S17Promini/S17Promini-vendor.mk)

PRODUCT_NAME := lineage_S17Promini
PRODUCT_SHIPPING_API_LEVEL := 31
PRODUCT_EXTRA_VNDK_VERSIONS := 31
PRODUCT_BUILD_BOOT_IMAGE := true
PRODUCT_BUILD_RECOVERY_IMAGE := true
PRODUCT_BUILD_VENDOR_BOOT_IMAGE := false
PRODUCT_BUILD_PRODUCT_IMAGE := false
PRODUCT_BUILD_SYSTEM_EXT_IMAGE := false
PRODUCT_PRODUCT_PROPERTIES += ro.sf.lcd_density=180
PRODUCT_COPY_FILES += \
    device/lvmi/S17Promini/rootdir/init.s17promini-rom.rc:$(TARGET_COPY_OUT_SYSTEM)/etc/init/init.s17promini-rom.rc

# Non-A/B block OTA needs the existing cache size in target-files metadata.
PRODUCT_BUILD_USERDATA_IMAGE := false
PRODUCT_BUILD_CACHE_IMAGE := true
