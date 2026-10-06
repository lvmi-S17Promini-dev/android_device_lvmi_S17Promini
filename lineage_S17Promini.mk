# ADB
# Select Lineage's unauthenticated ADB defaults before inheriting its config.
ifneq ($(filter userdebug eng,$(TARGET_BUILD_VARIANT)),)
WITH_ADB_INSECURE := true
endif

# Inherit common device and Lineage configuration
$(call inherit-product, device/lvmi/S17Promini/common.mk)

# GSI compatibility
# Keep the stock first-stage mount layout and provide additional VNDK support.
$(call inherit-product, $(SRC_TARGET_DIR)/product/gsi_release.mk)

# Inherit vendor blobs
$(call inherit-product, vendor/lvmi/S17Promini/S17Promini-vendor.mk)

# Product identity
PRODUCT_NAME := lineage_S17Promini

# Shipping API level
PRODUCT_SHIPPING_API_LEVEL := 31

# VNDK
PRODUCT_EXTRA_VNDK_VERSIONS := 31

# Images
PRODUCT_BUILD_BOOT_IMAGE := true
PRODUCT_BUILD_RECOVERY_IMAGE := true
PRODUCT_BUILD_VENDOR_BOOT_IMAGE := false
PRODUCT_BUILD_PRODUCT_IMAGE := false
PRODUCT_BUILD_SYSTEM_EXT_IMAGE := false
PRODUCT_BUILD_USERDATA_IMAGE := false

# Cache
# Standard non-A/B OTA requires the physical cache size in target-files.
PRODUCT_BUILD_CACHE_IMAGE := true

# Display
PRODUCT_PRODUCT_PROPERTIES += \
    ro.sf.lcd_density=180

# Init
PRODUCT_COPY_FILES += \
    device/lvmi/S17Promini/rootdir/init.s17promini-rom.rc:$(TARGET_COPY_OUT_SYSTEM)/etc/init/init.s17promini-rom.rc
