# Inherit common device and Lineage configuration
$(call inherit-product, device/lvmi/S17Promini/common.mk)

# Product identity
PRODUCT_NAME := lineage_S17Promini_recovery

# Images
# Build only the independent recovery image.
PRODUCT_BUILD_RECOVERY_IMAGE := true
PRODUCT_BUILD_BOOT_IMAGE := false
PRODUCT_BUILD_VENDOR_BOOT_IMAGE := false
PRODUCT_BUILD_SYSTEM_IMAGE := false
PRODUCT_BUILD_VENDOR_IMAGE := false
PRODUCT_BUILD_PRODUCT_IMAGE := false
PRODUCT_BUILD_SYSTEM_EXT_IMAGE := false
PRODUCT_BUILD_USERDATA_IMAGE := false
PRODUCT_BUILD_CACHE_IMAGE := false
