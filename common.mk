# Inherit 64-bit architecture configuration
$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)

# Inherit base product configuration
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)

# Inherit device configuration
$(call inherit-product, device/lvmi/S17Promini/device.mk)

# Inherit Lineage configuration
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)

# Device identity
PRODUCT_DEVICE := S17Promini
PRODUCT_BRAND := lvmi
PRODUCT_MODEL := S17 Pro mini
PRODUCT_MANUFACTURER := lvmi
