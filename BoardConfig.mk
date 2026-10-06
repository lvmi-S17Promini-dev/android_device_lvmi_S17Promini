DEVICE_PATH := device/lvmi/S17Promini
TARGET_ARCH := arm64
TARGET_ARCH_VARIANT := armv8-a
TARGET_CPU_ABI := arm64-v8a
TARGET_CPU_VARIANT := generic
TARGET_CPU_VARIANT_RUNTIME := cortex-a53
TARGET_2ND_ARCH := arm
TARGET_2ND_ARCH_VARIANT := armv7-a-neon
TARGET_2ND_CPU_ABI := armeabi-v7a
TARGET_2ND_CPU_ABI2 := armeabi
TARGET_2ND_CPU_VARIANT := generic
TARGET_2ND_CPU_VARIANT_RUNTIME := cortex-a53
TARGET_BOARD_PLATFORM := mt6765
TARGET_BOOTLOADER_BOARD_NAME := r65v3_pmz_w1a
TARGET_NO_BOOTLOADER := true
TARGET_SCREEN_DENSITY := 180
# Measured panel: 384x854. Private 374px text PNGs use an 18px font.
# Do not enable the stock fixed-40px text generator on this narrow panel.

# Stock kernel and DT tables; no source build.
TARGET_KERNEL_SOURCE := kernel/lvmi/S17Promini
TARGET_PREBUILT_KERNEL := $(DEVICE_PATH)/prebuilt/kernel
BOARD_KERNEL_IMAGE_NAME := Image.gz
BOARD_BOOT_HEADER_VERSION := 2
BOARD_KERNEL_BASE := 0x40078000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x11a88000
BOARD_TAGS_OFFSET := 0x07808000
BOARD_DTB_OFFSET := 0x07808000
# Stock CONFIG_SECURITY_SELINUX_DEVELOP=n: recovery must work enforcing.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.hardware=mt6765
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET) --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_TAGS_OFFSET) --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_MKBOOTIMG_ARGS += --dtb $(DEVICE_PATH)/prebuilt/dtb.img
BOARD_INCLUDE_RECOVERY_DTBO := true
BOARD_PREBUILT_RECOVERY_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/recovery_dtbo.img
BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
BOARD_FLASH_BLOCK_SIZE := 131072
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_CACHEIMAGE_PARTITION_SIZE := 452984832
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/recovery.fstab
# Same pixel format as stock recovery prop.default.
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888
# Non-A/B native dynamic partitions, from stock LP metadata.
BOARD_SUPER_PARTITION_SIZE := 7134339072
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_SIZE := 7132241920
BOARD_MAIN_PARTITION_LIST := system vendor product
# LK acceptance of an unsigned recovery must be tested.
BOARD_AVB_ENABLE := false

# r3 contexts are preserved for investigation, not included in this build.
# Use the device-verified runtime relabel workaround in recovery init instead.

# System bring-up with stock vendor blobs; retain the recovery product.
ifeq ($(TARGET_PRODUCT),lineage_S17Promini)
# Stock vendor defines fuseblk with its own type; omit Lineage's duplicate.
TARGET_USES_PREBUILT_VENDOR_SEPOLICY := true
TARGET_HAS_FUSEBLK_SEPOLICY_ON_VENDOR := true
BOARD_SYSTEMIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_SYSTEMIMAGE_PARTITION_RESERVED_SIZE := 134217728
BOARD_VENDORIMAGE_FILE_SYSTEM_TYPE := ext4
BOARD_VENDORIMAGE_PARTITION_SIZE := 1427996672
include vendor/lvmi/S17Promini/BoardConfigVendor.mk
TARGET_COPY_OUT_VENDOR := vendor
TARGET_COPY_OUT_ODM := vendor/odm
TARGET_COPY_OUT_PRODUCT := system/product
TARGET_COPY_OUT_SYSTEM_EXT := system/system_ext
BOARD_VNDK_VERSION := current
BOARD_PROPERTY_OVERRIDES_SPLIT_ENABLED := true
BOARD_USES_METADATA_PARTITION := true
TARGET_USES_64_BIT_BINDER := true
BOARD_MAIN_PARTITION_LIST := system vendor
BOARD_COPY_BOOT_IMAGE_TO_TARGET_FILES := true
BOARD_AVB_RECOVERY_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_RECOVERY_ALGORITHM := SHA256_RSA2048
BOARD_AVB_RECOVERY_ROLLBACK_INDEX := 0
BOARD_AVB_RECOVERY_ROLLBACK_INDEX_LOCATION := 2
BOARD_PREBUILT_VENDOR_DIR := vendor/lvmi/S17Promini/proprietary/vendor
BOARD_PREBUILT_VENDOR_FS_CONFIG := $(DEVICE_PATH)/vendor-config/fs_config
BOARD_PREBUILT_VENDOR_MAP := $(OUT_DIR)/target/product/S17Promini/obj/PACKAGING/s17_vendor_intermediates/vendor.map
TARGET_RELEASETOOLS_EXTENSIONS := $(DEVICE_PATH)
DEVICE_FRAMEWORK_COMPATIBILITY_MATRIX_FILE := $(DEVICE_PATH)/compatibility_matrix.xml
USE_XML_AUDIO_POLICY_CONF := 1
# Verification is disabled for this system-only bring-up image.
BOARD_AVB_ENABLE := true
BOARD_AVB_ROLLBACK_INDEX := 0
BOARD_AVB_MAKE_VBMETA_IMAGE_ARGS += --flags 3
BOARD_AVB_SYSTEM_KEY_PATH := external/avb/test/data/testkey_rsa2048.pem
BOARD_AVB_SYSTEM_ALGORITHM := SHA256_RSA2048
BOARD_AVB_SYSTEM_ROLLBACK_INDEX := 0
BOARD_AVB_SYSTEM_ROLLBACK_INDEX_LOCATION := 1
BOARD_AVB_SYSTEM_ADD_HASHTREE_FOOTER_ARGS += --hash_algorithm sha256
# Keep the tested stock first-stage init/fstab; omit the diagnostic PID1 wrapper.
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 buildvariant=user
BOARD_MKBOOTIMG_ARGS += --ramdisk $(DEVICE_PATH)/prebuilt/boot-ramdisk.img
BOARD_MKBOOTIMG_ARGS += --os_version 12.0.0 --os_patch_level 2024-03
BOARD_MKBOOTIMG_ARGS += --cmdline "bootopt=64S3,32N2,64N2 buildvariant=user"
# Recovery must use its generated ramdisk, not boot's stock first-stage ramdisk.
BOARD_RECOVERY_MKBOOTIMG_ARGS := --header_version 2
BOARD_RECOVERY_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET) --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_RECOVERY_MKBOOTIMG_ARGS += --tags_offset $(BOARD_TAGS_OFFSET) --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_RECOVERY_MKBOOTIMG_ARGS += --dtb $(DEVICE_PATH)/prebuilt/dtb.img
BOARD_RECOVERY_MKBOOTIMG_ARGS += --os_version 12.0.0 --os_patch_level 2024-03
BOOTIMAGE_EXTRA_DEPS += $(DEVICE_PATH)/prebuilt/boot-ramdisk.img
endif
