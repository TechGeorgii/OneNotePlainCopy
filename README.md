# OneNotePlainCopy

OneNote for Mac puts an image of the selection on the clipboard next to the text, so many apps paste a picture instead of text. This small background app makes **Cmd+C in OneNote copy plain text only**. It triggers OneNote's own Edit → Copy command and keeps just the text. Other apps are not affected, and copying pictures works as before.

## Install

Requires macOS and the Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/TechGeorgii/OneNotePlainCopy.git
cd OneNotePlainCopy
./install.sh
```

Then allow **OneNotePlainCopy** in **System Settings → Privacy & Security → Accessibility**. It starts automatically at login.

Uninstall with `./install.sh --uninstall`. Logs are in `~/Library/Logs/OneNotePlainCopy.log`.
