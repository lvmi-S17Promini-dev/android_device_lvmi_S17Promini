LOCAL_PATH := device/lvmi/S17Promini
# Phase 1: recovery only; retain stock vendor/odm on device.
PRODUCT_SHIPPING_API_LEVEL := 31
PRODUCT_USE_DYNAMIC_PARTITIONS := true
PRODUCT_PACKAGES += fastbootd
PRODUCT_COPY_FILES += $(LOCAL_PATH)/recovery/root/init.recovery.mt6765.rc:root/init.recovery.mt6765.rc
