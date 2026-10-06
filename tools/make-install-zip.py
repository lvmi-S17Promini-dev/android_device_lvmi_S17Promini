#!/usr/bin/env python3
"""Build a signed full non-A/B install zip for the existing stock LP layout."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import zipfile

DEVICE = Path(__file__).resolve().parents[1]
ANDROID = DEVICE.parents[2]
HOST = ANDROID / "out/host/linux-x86/bin"
sys.path.insert(0, str(ANDROID / "build/make/tools/releasetools"))
import common
import sparse_img
import blockimgdiff


def sha256(path):
    result = hashlib.sha256()
    with path.open("rb") as stream:
        for chunk in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            result.update(chunk)
    return result.hexdigest()


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--product-out", type=Path, default=ANDROID / "out/target/product/S17Promini")
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    out = args.product_out.resolve()
    output = args.output.resolve()
    inputs = {name: out / (name + ".img") for name in ("system", "vendor", "boot", "vbmeta")}
    inputs["recovery"] = DEVICE / "prebuilt/recovery.img"
    updater = out / "obj/EXECUTABLES/updater_intermediates/updater"
    for path in [*inputs.values(), updater]:
        if not path.is_file():
            raise FileNotFoundError(path)
    env = os.environ.copy()
    env["PATH"] = str(HOST) + os.pathsep + env.get("PATH", "")
    os.environ.update(env)
    common.OPTIONS.cache_size = 452984832
    output.parent.mkdir(parents=True, exist_ok=True)
    try:
        with tempfile.TemporaryDirectory(prefix="s17-ota-", dir=output.parent) as temp:
            temp = Path(temp)
            unsigned = temp / "unsigned.zip"
            signed = temp / "signed.zip"
            sizes = {}
            script = [
                'ui_print("LineageOS 19.1 - S17Promini full install");',
                'assert(getprop("ro.product.device") == "S17Promini" || getprop("ro.product.vendor.device") == "S17Promini");',
                'ifelse(is_mounted("/system_root"), unmount("/system_root"), "");',
                'ifelse(is_mounted("/system"), unmount("/system"), "");',
                'ifelse(is_mounted("/vendor"), unmount("/vendor"), "");',
                'assert(update_dynamic_partitions(package_extract_file("dynamic_partitions_op_list")));',
            ]
            with zipfile.ZipFile(unsigned, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=1,
                                 allowZip64=True) as package:
                package.write(updater, "META-INF/com/google/android/update-binary")
                for name in ("system", "vendor"):
                    image = sparse_img.SparseImage(str(inputs[name]), None)
                    sizes[name] = image.total_blocks * image.blocksize
                    prefix = str(temp / name)
                    print(f"Generating {name} block transfers", flush=True)
                    blockimgdiff.BlockImageDiff(image, threads=4, version=4,
                                               disable_imgdiff=True).Compute(prefix)
                    for extension in ("transfer.list", "new.dat", "patch.dat"):
                        package.write(prefix + "." + extension, name + "." + extension)
                    script += [f'ui_print("Writing {name}");',
                        f'assert(block_image_update(map_partition("{name}"), package_extract_file("{name}.transfer.list"), "{name}.new.dat", "{name}.patch.dat"));',
                        f'assert(range_sha1(map_partition("{name}"), "{image.care_map.to_string()}") == "{image.TotalSha1()}");',
                        f'unmap_partition("{name}");']
                # Product is deliberately preserved; require the known main group and LP names.
                if sizes["system"] + sizes["vendor"] + 204660736 > 7132241920:
                    raise ValueError("Dynamic partition group budget exceeded")
                operations = "\n".join([
                    "resize system 0", "resize vendor 0", "resize_group main 7132241920",
                    f"resize system {sizes['system']}", f"resize vendor {sizes['vendor']}", ""])
                package.writestr("dynamic_partitions_op_list", operations)
                for name in ("recovery", "boot", "vbmeta"):
                    package.write(inputs[name], name + ".img")
                    script.append(f'assert(package_extract_file("{name}.img", "/dev/block/by-name/{name}"));')
                script.append('ui_print("Installation complete. Reboot system.");')
                package.writestr("META-INF/com/google/android/updater-script", "\n".join(script) + "\n")
                package.writestr("META-INF/com/android/metadata",
                    "ota-type=BLOCK\npre-device=S17Promini\nota-required-cache=0\n")
            key = ANDROID / "build/target/product/security/testkey"
            jni = ANDROID / "out/soong/.intermediates/external/conscrypt/libconscrypt_openjdk_jni/linux_glibc_x86_64_shared"
            if not (jni / "libconscrypt_openjdk_jni.so").is_file():
                raise FileNotFoundError(jni / "libconscrypt_openjdk_jni.so")
            subprocess.run([
                str(ANDROID / "prebuilts/jdk/jdk11/linux-x86/bin/java"),
                "-Djava.library.path=" + str(jni),
                "-jar", str(ANDROID / "out/host/linux-x86/framework/signapk.jar"), "-w",
                str(key) + ".x509.pem", str(key) + ".pk8", str(unsigned), str(signed),
            ], check=True, env=env)
            signed.replace(output)
            report = {"output": str(output), "sha256": sha256(output),
                      "size": output.stat().st_size, "dynamic_sizes": sizes,
                      "preserved": ["product", "userdata", "LK", "dtbo", "firmware partitions"],
                      "inputs": {name: {"path": str(path), "sha256": sha256(path)}
                                 for name, path in inputs.items()}}
            output.with_suffix(".json").write_text(json.dumps(report, indent=2) + "\n")
            print(json.dumps(report, indent=2))
    finally:
        common.Cleanup()


if __name__ == "__main__":
    main()
