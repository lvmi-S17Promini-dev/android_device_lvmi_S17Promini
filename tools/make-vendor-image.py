#!/usr/bin/env python3
"""Repack stock ext4 vendor, preserving inode metadata and removing listed files."""
import argparse
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import tempfile

DEVICE = Path(__file__).resolve().parents[1]
ANDROID = DEVICE.parents[2]
HOST = ANDROID / "out/host/linux-x86/bin"
PARTITION_SIZE = 1427996672


def run(*args):
    env = os.environ.copy()
    env["PATH"] = str(HOST) + os.pathsep + env.get("PATH", "")
    result = subprocess.run(list(map(str, args)), capture_output=True, text=True, env=env)
    if result.returncode:
        raise RuntimeError(f"{args[0]} failed ({result.returncode}):\n{result.stdout}\n{result.stderr}")
    return result.stdout


def entries(name):
    paths = set()
    for line in (DEVICE / name).read_text().splitlines():
        if not line or line.startswith("#"):
            continue
        path = PurePosixPath(line)
        if not line.startswith("vendor/") or ".." in path.parts or any(c.isspace() for c in line):
            raise ValueError(f"Unsupported blob path: {line}")
        if line in paths:
            raise ValueError(f"Duplicate blob path: {line}")
        paths.add(line)
    return paths


def inventory(image):
    result = {}
    stack = ["/"]
    while stack:
        directory = stack.pop()
        for line in run("debugfs", "-R", f"ls -p {directory}", image).splitlines():
            parts = line.split("/")
            if len(parts) < 7 or not parts[1].isdigit() or int(parts[1]) == 0:
                continue
            if parts[5] in (".", ".."):
                continue
            path = str(PurePosixPath(directory) / parts[5])
            mode = int(parts[2], 8)
            if mode & 0o170000 == 0o040000:
                stack.append(path)
            else:
                result["vendor" + path] = (mode, int(parts[3]), int(parts[4]), parts[6])
    return result


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("stock_vendor", type=Path)
    parser.add_argument("--output", type=Path,
                        default=ANDROID / "vendor/lvmi/S17Promini/proprietary/vendor.img")
    args = parser.parse_args()
    source, output = args.stock_vendor.resolve(), args.output.resolve()
    if source == output or not source.is_file() or source.stat().st_size != PARTITION_SIZE:
        raise ValueError("Use the original raw LP vendor.img, with a separate output path")
    keep = entries("proprietary-files.txt")
    removed = entries("proprietary-files-removed.txt")
    if keep & removed:
        raise ValueError("Keep and removal lists overlap")
    before = inventory(source)
    regular = {p for p, meta in before.items() if meta[0] & 0o170000 == 0o100000}
    if regular != keep | removed:
        raise ValueError(f"Stock/list mismatch: extra={regular - keep - removed}, missing={keep | removed - regular}")
    if any(before[p][0] & 0o170000 != 0o100000 for p in removed):
        raise ValueError("Only regular-file deletions are supported")
    output.parent.mkdir(parents=True, exist_ok=True)
    print(f"Removing {len(removed)} files; retaining {len(keep)} blobs and stock symlinks", flush=True)
    with tempfile.TemporaryDirectory(prefix="s17-vendor-", dir=output.parent) as temp:
        temp = Path(temp)
        raw, sparse = temp / "vendor.img", temp / "vendor.sparse.img"
        run("cp", "--reflink=auto", "--sparse=always", source, raw)
        run(HOST / "avbtool", "erase_footer", "--image", raw)
        directories = set()
        for path in removed:
            parts = PurePosixPath(path).parts[1:]
            app_root = 2 if parts[0] == "app" else 3 if parts[:2] == ("operator", "app") else None
            if app_root:
                for count in range(app_root, len(parts)):
                    directories.add("/" + "/".join(parts[:count]))
        commands = [f"rm {p.removeprefix('vendor')}" for p in sorted(removed)]
        commands += [f"rmdir {d}" for d in sorted(directories, key=lambda d: (-d.count('/'), d))]
        batch = temp / "remove.debugfs"
        batch.write_text("\n".join(commands) + "\n")
        run("debugfs", "-w", "-f", batch, raw)
        # Validate before resize; do not silently repair a damaged source.
        run("e2fsck", "-fn", raw)
        run("resize2fs", "-M", raw)
        run("e2fsck", "-fn", raw)
        after = inventory(raw)
        expected = {p: meta for p, meta in before.items() if p not in removed}
        if after != expected:
            raise RuntimeError("Retained paths, modes, owners or sizes changed")
        samples = ["/bin/hw/android.hardware.audio.service.mediatek",
                   "/etc/selinux/vendor_sepolicy.cil", "/lib64/libpq_prot.so"]
        for path in samples:
            if run("debugfs", "-R", f"ea_list {path}", source) != run("debugfs", "-R", f"ea_list {path}", raw):
                raise RuntimeError(f"Extended attributes changed: {path}")
        fs_size = raw.stat().st_size
        run(HOST / "avbtool", "add_hashtree_footer", "--image", raw,
            "--partition_name", "vendor", "--partition_size", PARTITION_SIZE,
            "--algorithm", "NONE", "--hash_algorithm", "sha256", "--do_not_use_ab")
        run(HOST / "avbtool", "verify_image", "--image", raw)
        run(HOST / "img2simg", raw, sparse)
        checksum = hashlib.sha256()
        with sparse.open("rb") as image:
            for chunk in iter(lambda: image.read(4 * 1024 * 1024), b""):
                checksum.update(chunk)
        report = {"stock_vendor": str(source), "output": str(output),
                  "removed_files": len(removed), "retained_files": len(keep),
                  "symlinks": sum(meta[0] & 0o170000 == 0o120000 for meta in after.values()),
                  "filesystem_size": fs_size, "expanded_image_size": PARTITION_SIZE,
                  "sparse_image_size": sparse.stat().st_size, "sha256": checksum.hexdigest(),
                  "checks": ["retained inode metadata", "sample extended attributes",
                             "ext4 e2fsck", "AVB hashtree verification"]}
        sparse.replace(output)
        output.with_suffix(".json").write_text(json.dumps(report, indent=2) + "\n")
        print(json.dumps(report, indent=2))


if __name__ == "__main__":
    main()
