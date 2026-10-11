# The stock vendor already supplies the matching modem/VoLTE native services.
# Java dependencies are bundled privately in the app by tools/prepare-ims.py.
PRODUCT_PACKAGES += S17ImsService

PRODUCT_COPY_FILES += \
    device/lvmi/S17Promini/ims/privapp-permissions-s17-ims.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/permissions/privapp-permissions-s17-ims.xml \
    device/lvmi/S17Promini/ims/default-permissions-s17-ims.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/default-permissions/default-permissions-s17-ims.xml \
    device/lvmi/S17Promini/ims/s17-ims.xml:$(TARGET_COPY_OUT_SYSTEM)/etc/sysconfig/s17-ims.xml
