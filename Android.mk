LOCAL_PATH := $(call my-dir)

ifeq ($(TARGET_PRODUCT),lineage_S17Promini)
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
