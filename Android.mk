ifeq ($(TARGET_PRODUCT),lineage_S17Promini_system)
s17_install_zip := $(PRODUCT_OUT)/lineage-19.1-S17Promini.zip
$(s17_install_zip): $(PRODUCT_OUT)/system.img $(PRODUCT_OUT)/vendor.img \
    $(PRODUCT_OUT)/boot.img $(PRODUCT_OUT)/vbmeta.img \
    $(PRODUCT_OUT)/obj/EXECUTABLES/updater_intermediates/updater \
    device/lvmi/S17Promini/prebuilt/recovery.img \
    device/lvmi/S17Promini/tools/make-install-zip.py \
    $(HOST_OUT)/framework/signapk.jar \
    $(SOONG_OUT_DIR)/.intermediates/external/conscrypt/libconscrypt_openjdk_jni/linux_glibc_x86_64_shared/libconscrypt_openjdk_jni.so
	@echo "Packaging S17Promini full recovery install zip"
	prebuilts/build-tools/path/linux-x86/python3 device/lvmi/S17Promini/tools/make-install-zip.py --product-out $(PRODUCT_OUT) --output $@
.PHONY: s17-installzip
s17-installzip: $(s17_install_zip)
endif
