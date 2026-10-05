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
