# S17 Android 12 voice IMS

`S17ImsService` installs `com.mediatek.ims` as a platform-signed privileged app.
The stock APK uses `android.uid.phone`, so it must share the ROM platform
certificate with TeleService; retaining its stock certificate would prevent
installation into that shared UID.

Generate the vendor prebuilt from the extracted **stock** system directory:

```bash
python3 device/lvmi/S17Promini/tools/prepare-ims.py /path/to/extracted/system/system
```

Alternatively pass that directory as the second argument to `extract-files.sh`
after the raw vendor image. Keep `vendor/lvmi/S17Promini/ims/ImsService.apk` and
`provenance.json` in the vendor repository. Input SHA256 values and the 40 bundled
classes are pinned in `stock-inputs.json`; the preparation script rejects a
different firmware. The generated APK contains the original app classes plus
37 referenced classes from mediatek-ims-base and three operator factory loader
classes from mediatek-common. Those classes are private to IMS; there are no
stock framework replacements or additions to the platform boot classpath.

The stock manifest already declares the Android 12 MMTEL ImsService. Device
overlays select it and advertise VoLTE; the carrier overlay enables VoLTE for
the test SIM's China Unicom MCC/MNC 46001. Other carriers keep their existing
CarrierConfig. The ROM explicitly includes the AOSP CarrierConfig app: without
it, its XML overlay is not packaged, the framework falls back to VoLTE-disabled
defaults, and ImsManager turns IMS off. CarrierConfig also installs its own
required privileged permission whitelist. Provisioning checks are not forcibly
bypassed.

Video IMS is gated off in the APK because the stock eagerly initialized JNI
video stack is not part of this voice bring-up. The call-session constructor
and video ringtone path use the same gate, so audio calls do not create/bind
a video provider based on stock persist.vendor.vilte_support=1. Framework ViLTE/VoWiFi flags
remain off. SMS IMS uses the original app implementation. Registration, calls,
SMS and LTE incoming behavior still require device testing; a successful ROM
build does not validate the modem or operator interaction.

The initial allowlist omitted PACKET_KEEPALIVE_OFFLOAD and caused system_server
to abort during the privileged permission check. It is now included. Packaging
S17ImsService runs tools/check-ims-permissions.py against the APK and the
platform permission definitions to reject missing privileged entries before
producing another image. The corrected allowlist covers all five platform
privileged permissions requested by this APK.

After installation, check `pm path com.mediatek.ims`, `dumpsys phone` for an
active ImsResolver controller, and radio/all logcat for ImsApp/MtkDynamicImsService
startup. Then check actual IMS registration and a call that stays on LTE.
