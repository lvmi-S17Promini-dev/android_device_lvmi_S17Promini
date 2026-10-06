# Device tree for lvmi S17Promini

LineageOS 19.1 device tree for the lvmi S17 Pro mini (MT6765 / Helio P35).
The ROM, source-built recovery, vendor image and standard non-A/B OTA build are working.

## Device specifications

| Component | Specification |
| --- | --- |
| SoC | MediaTek MT6765V / Helio P35 |
| RAM / storage | 4 GB / 64 GB |
| Display | 384 × 854, density 180 |
| Stock Android | Android 12, API 31 |
| Kernel | 4.19.191, stock prebuilt |
| Partition scheme | Non-A/B dynamic partitions, independent recovery |

## Implementation

- Stock kernel, DTB and recovery DTBO are prebuilt; kernel source is unavailable.
- Normal boot retains the tested stock first-stage ramdisk. Recovery is built from current sources.
- Proprietary files are extracted into `vendor/lvmi/S17Promini/proprietary/vendor/`.
  The current vendor image builder preserves stock ownership, permissions, SELinux labels and symlinks.
- Unneeded bundled applications and stock recovery restoration components are excluded.
- `product` and `system_ext` are merged into `system`; `odm` remains inside vendor.
  Standard full OTA creates the `system` and `vendor` logical partitions in the `main` group.
- `/metadata` uses `md_udc`; `/misc` uses `para`.
- Debug builds enable early USB ADB without authorization. AVB metadata is packaged with verification disabled.

## Prepare vendor files

Place this tree at `device/lvmi/S17Promini` in a synced LineageOS 19.1 source tree.
Extract from the **original raw logical vendor image** unpacked from stock super:

```bash
cd ~/android3/lineage
./device/lvmi/S17Promini/extract-files.sh /path/to/stock/vendor.img
```

Extraction generates the vendor project and its image build rules. It also runs
`setup-makefiles.sh`, which checks/applies the accompanying `build/make` patch for
prebuilt vendor metadata in target-files. Linux `e2fsprogs` tools are required;
`debugfs` defaults to `/usr/sbin/debugfs` and can be overridden with `S17_DEBUGFS`.

If the expanded vendor files already exist, regenerate configuration without re-extracting:

```bash
./device/lvmi/S17Promini/setup-makefiles.sh
```

Re-extraction replaces the expanded vendor files; keep local blob modifications before doing so.

## Build

### ROM and full OTA

```bash
source build/envsetup.sh
lunch lineage_S17Promini-userdebug
m -j8 bacon
```

Output: `out/target/product/S17Promini/lineage-19.1-*-UNOFFICIAL-S17Promini.zip`.
Standard target-files are generated under the product's `obj/PACKAGING/target_files_intermediates/` directory.
The OTA updates system, vendor, boot, recovery and vbmeta; data formatting is not automatic.

### Independent recovery

```bash
lunch lineage_S17Promini_recovery-userdebug
m -j8 recoveryimage
```

Output: `out/target/product/S17Promini/recovery.img`.

## Validation and limitations

Device boot, recovery, ADB, fastbootd, standard OTA installation, data-preserving upgrades
and clean installation have been verified. Reported working functions include RIL, Wi-Fi,
Bluetooth, camera, audio, microphone, charging, key wake-up and Doze.

Recovery touch is deferred; use the physical keys. Recovery decryption of encrypted data
has not been validated. Vendor still uses a custom filesystem build rule and stock policy;
conversion to conventional prebuilt modules is deferred. Incremental OTA and automatic update
service integration are outside the current scope.

## Configuration and documentation

- `BoardConfig.mk`: shared board configuration; `BoardConfigRom.mk`: ROM-specific settings.
- `common.mk` / `device.mk`: shared product and device settings.
- `lineage_S17Promini.mk` / `lineage_S17Promini_recovery.mk`: separate build targets.
- [Porting records](docs/README.md), [standard build details](docs/37-standard-build-targets.md)
  and [source-built recovery](docs/38-generated-recovery.md).
- [Maturation roadmap](docs/ROADMAP.md): future work on the fixed LineageOS 19.1 version.
