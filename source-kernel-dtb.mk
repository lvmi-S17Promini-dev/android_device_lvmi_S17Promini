# Wrap the source board DTB for both boot and recovery in the stock table format.
$(INSTALLED_DTBIMAGE_TARGET): $(TARGET_PREBUILT_INT_KERNEL) $(DEVICE_PATH)/prebuilt/dtb.img $(DEVICE_PATH)/tools/make-source-kernel-dtb.py
	python3 $(DEVICE_PATH)/tools/make-source-kernel-dtb.py \
		--template $(DEVICE_PATH)/prebuilt/dtb.img \
		--dtb $(KERNEL_OUT)/arch/arm64/boot/dts/mediatek/S17Promini.dtb \
		--output $@
