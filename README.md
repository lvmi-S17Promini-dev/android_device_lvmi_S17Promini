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

Current source builds the device-validated r5 recovery: the verified recovery-384 baseline plus a logged super-label helper after coldboot and before fastbootd. r3 contexts and extra r2 UI assets remain excluded. Device boot, root ADB and automatic super labeling for fastbootd are validated. Touch and data decryption remain unresolved. See docs/17-r5-super-service.md.
