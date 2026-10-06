# Settings for lineage_S17Promini only; included by BoardConfig.mk.

# SELinux
# Stock vendor owns the fuseblk label; omit the duplicate Lineage rule.
TARGET_USES_PREBUILT_VENDOR_SEPOLICY := true
TARGET_HAS_FUSEBLK_SEPOLICY_ON_VENDOR := true
SYSTEM_EXT_PRIVATE_SEPOLICY_DIRS += $(DEVICE_PATH)/sepolicy/private

# VINTF
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE := $(DEVICE_PATH)/compatibility_matrix.xml

# Partitions
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 134217728
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_PARTITION_SIZE := 1427996672
BOARD_MAIN_PARTITION_LIST := system vendor

# Partition paths
# Product and system_ext are fused into system; odm is embedded in vendor.
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_ODM := vendor/odm
TARGET_COPY_OUT_PRODUCT := system/product
TARGET_COPY_OUT_SYSTEM_EXT := system/system_ext

# VNDK
BOARD_VNDK_VERSION := current
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true
TARGET_USES_64_BIT_BINDER := true

# Metadata
BOARD_USES_METADATA_PARTITION := true

# Audio
USE_XML_AUDIO_POLICY_CONF := 1

# Vendor blobs
BOARD_PREBUILT_VENDOR_DIR := vendor/lvmi/S17Promini/proprietary/vendor
BOARD_PREBUILT_VENDOR_FS_CONFIG := $(DEVICE_PATH)/vendor-config/fs_config
BOARD_PREBUILT_VENDOR_MAP := $(OUT_DIR)/target/product/S17Promini/obj/PACKAGING/s17_vendor_intermediates/vendor.map

# OTA
BOARD_COPY_BOOT_IMAGE_TO_TARGET_FILES := true
TARGET_RELEASETOOLS_EXTENSIONS := $(DEVICE_PATH)

# Verified Boot
# Package AVB metadata with verification disabled for the unlocked device.
BOARD_AVB_ENABLE := true
BOARD_AVB_ROLLBACK_INDEX := 0
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_SYSTEM_ROLLBACK_INDEX := 0
BOARD_AVB_SYSTEM_ROLLBACK_INDEX_LOCATION := 1
BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS += --hash_algorithm sha256
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA2048
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 0
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 2

# Boot image
# Preserve the tested stock first-stage init/fstab.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 buildvariant=user
BOARD_MKBOOTIMG_ARGS += --ramdisk $(DEVICE_PATH)/prebuilt/boot-ramdisk.img
BOARD_MKBOOTIMG_ARGS += --os_version 12.0.0 --os_patch_level 2024-03
BOARD_MKBOOTIMG_ARGS += --cmdline "bootopt=64S3,32N2,64N2 buildvariant=user"
BOOTIMAGE_EXTRA_DEPS += $(DEVICE_PATH)/prebuilt/boot-ramdisk.img

# Recovery image
# Recovery uses its generated ramdisk, separately from normal boot.
BOARD_RECOVERY_MKBOOTIMG_ARGS := --header_version 2
BOARD_RECOVERY_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET) --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_RECOVERY_MKBOOTIMG_ARGS += --tags_offset $(BOARD_TAGS_OFFSET) --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_RECOVERY_MKBOOTIMG_ARGS += --dtb $(DEVICE_PATH)/prebuilt/dtb.img
BOARD_RECOVERY_MKBOOTIMG_ARGS += --os_version 12.0.0 --os_patch_level 2024-03

# Generated vendor image configuration
include vendor/lvmi/S17Promini/BoardConfigVendor.mk
