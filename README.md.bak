# OnePlus Anti-Rollback Detector
A local ARB (Anti-Rollback) detection tool for OnePlus devices, running in Termux with root access.


中文版请复制此链接并打开酷安
https://www.coolapk.com/feed/70230118?s=OTU2NDhhNjAyMDY2ODdkZzY5OGNkMTAzega1602

## Notice
> [!WARNING]
> This script cannot help detect hidden ARB (Anti-Rollback) mechanisms. Therefore, please exercise extra caution even if your device's ARB Index shows 0x0.

> [!CAUTION]
> Until a way to bypass or break the ARB mechanism is available in the community, you must never attempt to downgrade on your device, as this will result in a hard brick.

---

Make sure your device has a root manager.

## Download Termux
Please ensure that Termux is installed on your device.
- [F-Droid | v0.118.3 | 108MiB](https://f-droid.org/repo/com.termux_1002.apk)
- [GitHub | v0.118.3 | 33.5MiB](https://github.com/termux/termux-app/releases/download/v0.118.3/termux-app_v0.118.3+github-debug_arm64-v8a.apk)


## Download arbscan
Please make sure the `arbscan` binary is placed in either `/storage/emulated/0` or `/sdcard`.
- [GitHub | arbscan | v0.1.0 | 176KiB](https://github.com/syedinsaf/arbscan/releases/download/v0.1.0/arbscan-0.1.0-android-arm64.zip)


## Alternative (All-in-One)
Alternatively, if you don’t want to download files back and forth, you can use this link.
- [Combined link | Google Drive | Total 33.9MiB](https://drive.google.com/drive/folders/1XhQvxfbFU6ohXUdfJEm7znOJ7dok3JqA?usp=sharing)

---

## How to use
Grant root access to Termux.  
Copy the code below into Termux. (It will request storage permission, which is normal.)

```bash
#!/bin/bash
# ============================================================
# OnePlus Anti-Rollback Detector
# Local ARB Status Check for OnePlus Devices
# Requirements: Termux + Root
# ============================================================

# Step 1: Request storage permission for Termux (triggers system permission prompt)
termux-setup-storage

# Verify storage access is granted
if [ ! -d "$HOME/storage" ]; then
    echo "Error: Storage folder not found. Please grant storage permission first."
    exit 1
fi

# Step 2: Check root access (silent check to avoid redundant output)
if ! su -c "echo ''" 2>/dev/null; then
    echo "Error: Root access denied. This script requires root privileges."
    exit 1
fi

# Step 3: Get current A/B slot suffix (e.g., _a or _b)
current_slot=$(su -c getprop ro.boot.slot_suffix 2>/dev/null)

# Step 4: Dump xbl_config partition from device (requires root)
su -c "dd if=/dev/block/bootdevice/by-name/xbl_config${current_slot} of=/sdcard/xbl_config${current_slot}.img"
# Move dumped image to Termux home directory
mv storage/shared/xbl_config${current_slot}.img ~/

# Step 5: Update Termux packages (non-interactive)
pkg update -y && pkg upgrade -y

# Step 6: Prepare arbscan tool
mv storage/shared/arbscan ~/
chmod 700 ~/arbscan  # Grant execution permission

# Step 7: Run ARB detection (auto-confirm with 'N' to skip extra prompts)
echo "=== OnePlus ARB Detection Result ==="
echo N | ./arbscan xbl_config${current_slot}.img
echo "===================================="

# Step 8: Clean up environment (restore permissions + remove temp files)
chmod 644 ~/arbscan
mv arbscan storage/shared
rm -f xbl_config${current_slot}.img
echo "Script completed successfully. All temporary files have been cleaned up."
ls
```
> The script's formatting may change significantly after being copied to the phone. Please scroll up slightly to view the complete results.

> The final ls may or may not execute; you can ignore it. It is only used to ensure the previous command runs properly.

---

## Result
### OEM Metadata
```
  Major Version : 3
  Minor Version : 0
  ARB Index     : 0
```
### Anti-Rollback is NOT activated✅😄
---
### OEM Metadata
```
  Major Version : 3
  Minor Version : 0
  ARB Index     : 1
```
### Anti-Rollback activated❌💀
