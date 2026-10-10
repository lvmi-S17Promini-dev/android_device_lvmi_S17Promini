# Device
DEVICE_PATH := device/lvmi/S17Promini

# Architecture
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

# Bootloader
TARGET_BOOTLOADER_BOARD_NAME := r65v3_pmz_w1a
TARGET_NO_BOOTLOADER := true

# Platform
TARGET_BOARD_PLATFORM := mt6765

# Display
# Panel: 384x854. Recovery text PNGs use an 18px font within 374px.
TARGET_SCREEN_DENSITY := 180

# Kernel
BOARD_KERNEL_IMAGE_NAME := Image.gz
BOARD_BOOT_HEADER_VERSION := 2
BOARD_KERNEL_BASE := 0x40078000
BOARD_KERNEL_PAGESIZE := 2048
BOARD_KERNEL_OFFSET := 0x00008000
BOARD_RAMDISK_OFFSET := 0x11a88000
BOARD_TAGS_OFFSET := 0x07808000
BOARD_DTB_OFFSET := 0x07808000
BOARD_KERNEL_CMDLINE := bootopt=64S3,32N2,64N2 androidboot.hardware=mt6765

# Always build the S17 source kernel and its board DTB.
TARGET_KERNEL_SOURCE := kernel/lvmi/mt6765
TARGET_KERNEL_CONFIG := S17Promini_defconfig S17Promini_boot_test.config
TARGET_KERNEL_CLANG_COMPILE := true
TARGET_KERNEL_CLANG_VERSION := r416183b
TARGET_KERNEL_ADDITIONAL_FLAGS := LLVM_IAS=1 -j8
KERNEL_LD := LD=$(abspath prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-ld.bfd)
BOARD_INCLUDE_DTB_IN_BOOTIMG := true
BOARD_CUSTOM_DTBIMG_MK := $(DEVICE_PATH)/source-kernel-dtb.mk
BOARD_MKBOOTIMG_ARGS += --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET) --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_MKBOOTIMG_ARGS += --tags_offset $(BOARD_TAGS_OFFSET) --dtb_offset $(BOARD_DTB_OFFSET)

# Partitions
BOARD_FLASH_BLOCK_SIZE := 131072
BOARD_BOOTIMAGE_PARTITION_SIZE := 33554432
BOARD_RECOVERYIMAGE_PARTITION_SIZE := 33554432
BOARD_CACHEIMAGE_PARTITION_SIZE := 452984832

# Partitions - dynamic
# Non-A/B layout. ROM overrides the stock logical partition list.
BOARD_SUPER_PARTITION_SIZE := 7134339072
BOARD_SUPER_PARTITION_GROUPS := main
BOARD_MAIN_SIZE := 7132241920
BOARD_MAIN_PARTITION_LIST := system vendor product

# Filesystems
TARGET_USERIMAGES_USE_EXT4 := true
TARGET_USERIMAGES_USE_F2FS := true
BOARD_CACHEIMAGE_FILE_SYSTEM_TYPE := ext4

# Recovery
# Use runtime super relabeling in recovery init.
TARGET_RECOVERY_FSTAB := $(DEVICE_PATH)/recovery/recovery.fstab
TARGET_RECOVERY_PIXEL_FORMAT := BGRA_8888
BOARD_INCLUDE_RECOVERY_DTBO := true
BOARD_PREBUILT_RECOVERY_DTBOIMAGE := $(DEVICE_PATH)/prebuilt/recovery_dtbo.img

# Both products use the built kernel/DTB and a generated recovery ramdisk.
# Keep boot's stock --ramdisk argument out of the recovery invocation.
# The build core supplies --dtb from INSTALLED_DTBIMAGE_TARGET.
BOARD_RECOVERY_MKBOOTIMG_ARGS := --header_version $(BOARD_BOOT_HEADER_VERSION)
BOARD_RECOVERY_MKBOOTIMG_ARGS += --kernel_offset $(BOARD_KERNEL_OFFSET) --ramdisk_offset $(BOARD_RAMDISK_OFFSET)
BOARD_RECOVERY_MKBOOTIMG_ARGS += --tags_offset $(BOARD_TAGS_OFFSET) --dtb_offset $(BOARD_DTB_OFFSET)
BOARD_RECOVERY_MKBOOTIMG_ARGS += --os_version 12.0.0 --os_patch_level 2024-03

# Verified Boot
# Standalone recovery is unsigned; ROM enables AVB packaging below.
BOARD_AVB_ENABLE := false

# ROM-specific settings
ifeq ($(TARGET_PRODUCT),lineage_S17Promini)
include $(DEVICE_PATH)/BoardConfigRom.mk
endif
