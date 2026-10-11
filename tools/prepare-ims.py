#!/usr/bin/env python3
"""Bundle the stock IMS app's missing MTK classes for the AOSP boot classpath.

Usage: prepare-ims.py /path/to/extracted/system/system
Inputs are pinned to the S17 Android 12 firmware. The generated unsigned APK
is signed with the ROM platform key by BUILD_PREBUILT (android.uid.phone).
"""
import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile

DEVICE = Path(__file__).resolve().parents[1]
ANDROID = DEVICE.parents[2]
VENDOR = ANDROID / "vendor/lvmi/S17Promini/ims"


def prepare(stock):
    manifest = json.loads((DEVICE / "ims/stock-inputs.json").read_text())
    java = ANDROID / "prebuilts/jdk/jdk11/linux-x86/bin/java"
    smali = ANDROID / "prebuilts/extract-tools/common/smali"
    for name, expected in manifest["inputs"].items():
        actual = hashlib.sha256((stock / name).read_bytes()).hexdigest()
        if actual != expected:
            raise ValueError(f"Unexpected stock IMS input: {name} ({actual})")
    with tempfile.TemporaryDirectory(prefix="s17-ims-") as temp:
        work = Path(temp)
        decoded = {}
        for name in manifest["inputs"]:
            output = work / Path(name).stem
            subprocess.run([str(java), "-jar", str(smali / "baksmali.jar"),
                            "d", str(stock / name), "-o", str(output)], check=True)
            decoded[Path(name).stem] = output
        app = decoded["ImsService"]
        bundled = []
        for descriptor in manifest["bundled_classes"]:
            relative = descriptor[1:-1] + ".smali"
            target = app / relative
            sources = [d / relative for key, d in decoded.items()
                       if key != "ImsService" and (d / relative).is_file()]
            if target.exists() or len(sources) != 1:
                raise ValueError(f"Ambiguous IMS dependency: {descriptor}")
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(sources[0], target)
            bundled.append(descriptor)

        # Stock advertises ViLTE and eagerly loads its separate native video
        # stack. This bring-up provides voice/SMS IMS only; gate video until
        # vtservice and its system JNI dependencies have been ported.
        util = app / "com/mediatek/ims/internal/ImsVTProviderUtil.smali"
        body, count = re.subn(
            r"(?ms)^\.method public static isVideoCallOnByPlatform\(\)Z\n.*?^\.end method",
            ".method public static isVideoCallOnByPlatform()Z\n"
            "    .registers 1\n    const/4 v0, 0x0\n    return v0\n.end method",
            util.read_text())
        if count != 1:
            raise ValueError("Stock IMS video capability gate changed")
        util.write_text(body)
        # The call-session constructor and video ringtone path independently
        # check the persisted vendor property, which is 1 in stock. Even audio
        # calls then create/bind a VTProvider and call its unloaded JNI. Route
        # both checks through the same gate used by native video initialization.
        session = app / "com/mediatek/ims/ImsCallSessionProxy.smali"
        video_check = (
            r'(?m)^    const-string (?P<reg>v\d+), "persist.vendor.vilte_support"\n\n'
            r'    invoke-static \{(?P=reg)\}, Landroid/os/SystemProperties;->get\(Ljava/lang/String;\)Ljava/lang/String;\n\n'
            r'    move-result-object (?P=reg)\n\n'
            r'    const-string (?P<one>v\d+), "1"\n\n'
            r'    invoke-virtual \{(?P=reg), (?P=one)\}, Ljava/lang/String;->equals\(Ljava/lang/Object;\)Z\n\n'
            r'    move-result (?P=reg)')
        body, count = re.subn(
            video_check,
            lambda match: "    invoke-static {}, Lcom/mediatek/ims/internal/ImsVTProviderUtil;->isVideoCallOnByPlatform()Z\n\n"
                          + "    move-result " + match["reg"],
            session.read_text())
        if count != 2:
            raise ValueError("Stock IMS call-session video gates changed")
        session.write_text(body)
        dex = work / "classes.dex"
        subprocess.run([str(java), "-jar", str(smali / "smali.jar"),
                        "a", str(app), "-o", str(dex)], check=True)
        apk = work / "ImsService.apk"
        original = stock / "priv-app/ImsService/ImsService.apk"
        with zipfile.ZipFile(original) as source, zipfile.ZipFile(apk, "w") as dest:
            for item in source.infolist():
                if item.filename == "classes.dex" or item.filename.upper().startswith("META-INF/"):
                    continue
                dest.writestr(item, source.read(item.filename))
            info = zipfile.ZipInfo("classes.dex", (2009, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_STORED
            dest.writestr(info, dex.read_bytes())
        VENDOR.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(apk, VENDOR / apk.name)
        report = {"inputs": manifest["inputs"], "bundled_classes": bundled,
                  "video_enabled": False,
                  "video_gate_patches": ["ImsVTProviderUtil.isVideoCallOnByPlatform",
                                         "ImsCallSessionProxy.<init>",
                                         "ImsCallSessionProxy.updateOutgoingVideoRingtone"],
                  "apk_sha256": hashlib.sha256(apk.read_bytes()).hexdigest()}
        (VENDOR / "provenance.json").write_text(json.dumps(report, indent=2) + "\n")
        print(f"Prepared {VENDOR / apk.name}: {len(bundled)} private MTK dependency classes")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stock_system", type=Path)
    prepare(parser.parse_args().stock_system.resolve())
