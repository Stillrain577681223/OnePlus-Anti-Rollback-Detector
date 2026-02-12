# OnePlus Anti-Rollback Detector
A local ARB (Anti-Rollback) detection tool for OnePlus devices, running in MT Manager/Termux with root access.

中文版请复制此链接并打开酷安
https://www.coolapk.com/feed/70236029?s=NjM2YTE1MmMzYWJlY2FnNjk4ZDgwZTZ6a1602

## Notice
> [!WARNING]
> This script cannot help detect hidden ARB (Anti-Rollback) mechanisms. Therefore, please exercise extra caution even if your device's ARB Index shows 0x0.

> [!CAUTION]
> Until a way to bypass or break the ARB mechanism is available in the community, you must never attempt to downgrade on your device, as this will result in a hard brick.

---
## Download
Download the package from releases
- [Github | Anti-Rollback-Detector-ver1.3(Add-Eng-Version).zip | 340KiB](https://github.com/Stillrain577681223/OnePlus-Anti-Rollback-Detector/releases/download/v1.3/Anti-Rollback-Detector-ver1.3.Add-Eng-Version.zip)
or use Termux and run this command
`curl -sL "https://raw.githubusercontent.com/Stillrain577681223/OnePlus-Anti-Rollback-Detector/main/run-it-chn.sh" -o run-it-chn.sh && bash -i run-it-chn.sh`

and you can skip to **Expected Output**


After unzipping, you will get 3 files:
- `arbscan`
- `run-it-chn.sh` (Chinese version)
- `run-it-eng.sh` (English version, **recommended**)
---

## How to use
### 1. MT Manager (Recommended)​
- Unzip the package and locate the script (e.g., run-it-eng.sh).
- Press the script → PREFERENCES.
- Check: Execute in system environment.
- (Optional but recommended) Check: Execute with root privileges.
- Tap EXECUTE to run.

### 2. Termux​
- Unzip the package to /sdcard/Download (or your custom path):
- Full default path:
- `/sdcard/Download/Anti-Rollback-Detector-ver1.3(Add-Eng-Version)/Anti-Rollback-Detector-ver1.3(Add-Eng-Version)/`
- Paste and run the command (replace path if needed):
- `su -c /system/bin/sh /sdcard/Download/Anti-Rollback-Detector-ver1.3(Add-Eng-Version)/Anti-Rollback-Detector-ver1.3(Add-Eng-Version)/run-it-eng.sh`
- Custom path command:
- `su -c /system/bin/sh [Your full script path]`
---

### 3. Termux One-Liner (Easiest)
Just copy and paste one of these commands into Termux. It will automatically download the script and the necessary binary.

**English Version:**
```bash
curl -sL "https://raw.githubusercontent.com/Stillrain577681223/OnePlus-Anti-Rollback-Detector/main/run-it-eng.sh" | sh
```

**Chinese Version:**
```bash
curl -sL "https://raw.githubusercontent.com/Stillrain577681223/OnePlus-Anti-Rollback-Detector/main/run-it-chn.sh" | sh
```

## Expected Output​
### On running, the script will show:​
- Script/author/copyright information
- 7-second countdown (automatic start after countdown)
- Progress prompts:
```
Searching for arbscan, please wait...
    Found: [arbscan path]
    Extracting image, please wait...
    Image extracted successfully
    Image ready, starting detection...
    ——————————————————
    Device Build: [Your device build number]
    Current Slot: [e.g., a/b]
      ARB Index     : [e.g., 0/1]
    Anti-Rollback Enabled/Disabled
    Decision Guidance
```
Make your own judgment based on the ARB result and the above notices.

This project is licensed under the MIT License.
