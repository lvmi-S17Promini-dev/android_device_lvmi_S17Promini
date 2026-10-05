#!/system/bin/sh
# Runtime /dev labeling only. No partition writes.
exec >> /tmp/s17-super-label.log 2>&1
printf '\n--- super relabel: '
cat /proc/uptime
id
setprop vendor.recovery.super_label.status waiting

s17_attempt=0
while [ "$(getprop ro.cold_boot_done)" != true ] || [ ! -b /dev/block/mmcblk0p32 ]; do
    s17_attempt=$((s17_attempt + 1))
    if [ "$s17_attempt" -ge 100 ]; then
        echo "Timed out waiting for coldboot and the super node"
        getprop ro.cold_boot_done
        ls -lZ /dev/block/mmcblk0p32
        setprop vendor.recovery.super_label.status failed
        exit 1
    fi
    sleep 0.1
done

ls -lZ /dev/block/mmcblk0p32
chcon u:object_r:super_block_device:s0 /dev/block/mmcblk0p32
s17_result=$?
echo "chcon exit: $s17_result"
ls -lZ /dev/block/mmcblk0p32
if [ "$s17_result" -ne 0 ]; then
    setprop vendor.recovery.super_label.status failed
    exit "$s17_result"
fi
setprop vendor.recovery.super_label.status ready
