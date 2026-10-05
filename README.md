# lvmi S17Promini — LineageOS 19.1 recovery bring-up

Prebuilt stock kernel 4.19.191, independent recovery, non-A/B native dynamic partitions.
Phase 1 recovery device tree; full ROM is not validated.

```bash
cd ~/android3/lineage
source build/envsetup.sh
lunch lineage_S17Promini-userdebug
m -j8 recoveryimage
```

See docs for evidence, testing and unresolved issues.

Current source builds the r4 candidate: the device-verified recovery-384 baseline plus boot-time relabeling of the super node. r3 contexts are excluded and extra r2 UI assets are held in recovery/res-extra. The r4 ramdisk differs from the verified baseline only in init.recovery.mt6765.rc; runtime test is pending. See docs/15-super-label-confirmed.md.
