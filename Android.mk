LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_PRODUCT),lineage_S17Promini)
s17_ims_permission_check := $(call intermediates-dir-for,APPS,S17ImsService)/permissions-checked.stamp
$(s17_ims_permission_check): vendor/lvmi/S17Promini/ims/ImsService.apk \
    $(LOCAL_PATH)/tools/check-ims-permissions.py \
    $(LOCAL_PATH)/ims/privapp-permissions-s17-ims.xml \
    frameworks/base/core/res/AndroidManifest.xml $(HOST_OUT_EXECUTABLES)/aapt2
	python3 device/lvmi/S17Promini/tools/check-ims-permissions.py \
	    --aapt2 $(HOST_OUT_EXECUTABLES)/aapt2 \
	    --apk vendor/lvmi/S17Promini/ims/ImsService.apk \
	    --manifest frameworks/base/core/res/AndroidManifest.xml \
	    --allowlist device/lvmi/S17Promini/ims/privapp-permissions-s17-ims.xml
	mkdir -p $(dir $@)
	touch $@

include $(CLEAR_VARS)
LOCAL_MODULE := S17ImsService
LOCAL_MODULE_CLASS := APPS
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_SUFFIX := $(COMMON_ANDROID_PACKAGE_SUFFIX)
LOCAL_PREBUILT_MODULE_FILE := vendor/lvmi/S17Promini/ims/ImsService.apk
LOCAL_CERTIFICATE := platform
LOCAL_PRIVILEGED_MODULE := true
LOCAL_DEX_PREOPT := false
LOCAL_ADDITIONAL_DEPENDENCIES := $(s17_ims_permission_check)
# Stock optional operator/WFO libraries are not needed by this voice IMS app.
LOCAL_ENFORCE_USES_LIBRARIES := false
include $(BUILD_PREBUILT)

# Device init owns the boot flow. Keep GSI compatibility libraries without
# installing the GSI-only version import or unconditional nodef reboot guard.
include $(CLEAR_VARS)
LOCAL_MODULE := init.s17promini-rom.rc
LOCAL_MODULE_CLASS := ETC
LOCAL_LICENSE_KINDS := legacy_restricted
LOCAL_LICENSE_CONDITIONS := restricted
LOCAL_SRC_FILES := rootdir/init.s17promini-rom.rc
LOCAL_MODULE_RELATIVE_PATH := init
LOCAL_OVERRIDES_MODULES := init.gsi.rc init.vndk-nodef.rc
include $(BUILD_PREBUILT)

ifneq ($(filter userdebug eng,$(TARGET_BUILD_VARIANT)),)
# Package the source-built recovery daemon for use before adbd's APEX is
# activated. Depend on build outputs rather than checking in another binary.
include $(CLEAR_VARS)
LOCAL_MODULE := s17-charger-adbd
LOCAL_MODULE_CLASS := EXECUTABLES
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_TARGET_ARCH := arm64
LOCAL_PREBUILT_MODULE_FILE := $(call intermediates-dir-for,EXECUTABLES,adbd.recovery)/adbd
LOCAL_STRIP_MODULE := false
LOCAL_SHARED_LIBRARIES := libadbd_fs liblog libselinux libbase s17-charger-adb-protos libadbd_auth libcrypto libc++
LOCAL_REQUIRED_MODULES := adbd.recovery
include $(BUILD_PREBUILT)

# libadb_protos is normally private to com.android.adbd, but the recovery
# daemon needs its source-built recovery variant outside that APEX.
include $(CLEAR_VARS)
LOCAL_MODULE := s17-charger-adb-protos
LOCAL_MODULE_CLASS := SHARED_LIBRARIES
LOCAL_MODULE_SUFFIX := .so
LOCAL_MODULE_STEM := libadb_protos
LOCAL_MODULE_TAGS := optional
LOCAL_MODULE_TARGET_ARCH := arm64
LOCAL_PREBUILT_MODULE_FILE := $(call intermediates-dir-for,SHARED_LIBRARIES,libadb_protos.recovery)/libadb_protos.recovery.so
LOCAL_STRIP_MODULE := false
LOCAL_SHARED_LIBRARIES := libprotobuf-cpp-lite
LOCAL_REQUIRED_MODULES := libadb_protos.recovery
include $(BUILD_PREBUILT)
endif
endif
