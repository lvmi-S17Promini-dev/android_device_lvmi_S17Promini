$(call inherit-product, $(SRC_TARGET_DIR)/product/core_64_bit.mk)
$(call inherit-product, $(SRC_TARGET_DIR)/product/full_base.mk)
$(call inherit-product, device/lvmi/S17Promini/device.mk)
$(call inherit-product, vendor/lineage/config/common_full_phone.mk)
PRODUCT_NAME := lineage_S17Promini
PRODUCT_DEVICE := S17Promini
PRODUCT_BRAND := lvmi
PRODUCT_MODEL := S17 Pro mini
PRODUCT_MANUFACTURER := lvmi
