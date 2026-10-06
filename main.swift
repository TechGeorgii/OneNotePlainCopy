// OneNote Plain Copy: Cmd+C in OneNote copies the selection and leaves only its
// plain-text version on the clipboard (OneNote also puts a PNG there, which most
// apps prefer when pasting). Copies without text, such as pictures, are left as is.
import AppKit
import Carbon.HIToolbox

let oneNoteBundleID = "com.microsoft.onenote.mac"

func log(_ message: String) {
    FileHandle.standardError.write("\(Date()) \(message)\n".data(using: .utf8)!)
}

func axValue(_ element: AXUIElement, _ attribute: String) -> AnyObject? {
    var value: AnyObject?
    return AXUIElementCopyAttributeValue(element, attribute as CFString, &value) == .success ? value : nil
}

func axChildren(_ element: AXUIElement) -> [AXUIElement] {
    axValue(element, kAXChildrenAttribute) as? [AXUIElement] ?? []
}

final class PlainCopy {
    static let shared = PlainCopy()
    private var hotKey: EventHotKeyRef?

    func start() {
        AXUIElementSetMessagingTimeout(AXUIElementCreateSystemWide(), 1)

        var spec = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, _ in
            PlainCopy.shared.copyAsPlainText()
            return noErr
        }, 1, &spec, nil, nil)

        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
        ) { note in
            let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            PlainCopy.shared.setHotKeyEnabled(app?.bundleIdentifier == oneNoteBundleID)
        }
        setHotKeyEnabled(NSWorkspace.shared.frontmostApplication?.bundleIdentifier == oneNoteBundleID)
    }

    // Cmd+C is taken over only while OneNote is frontmost; every other app keeps its own copy.
    private func setHotKeyEnabled(_ enabled: Bool) {
        if enabled, hotKey == nil {
            let id = EventHotKeyID(signature: OSType(0x4F4E_5043) /* 'ONPC' */, id: 1)
            let status = RegisterEventHotKey(UInt32(kVK_ANSI_C), UInt32(cmdKey), id,
                                             GetApplicationEventTarget(), 0, &hotKey)
            if status != noErr { log("RegisterEventHotKey failed: \(status)") }
        } else if !enabled, let ref = hotKey {
            UnregisterEventHotKey(ref)
            hotKey = nil
        }
    }

    // Presses OneNote's own Edit → Copy (not a synthetic ⌘C, which would re-trigger this hotkey).
    private func copyAsPlainText() {
        guard AXIsProcessTrusted() else {
            log("No Accessibility permission: System Settings → Privacy & Security → Accessibility")
            NSSound.beep()
            return
        }
        guard let oneNote = NSWorkspace.shared.frontmostApplication,
              oneNote.bundleIdentifier == oneNoteBundleID else { return }
        guard let item = copyMenuItem(of: oneNote.processIdentifier) else {
            log("No ⌘C menu item found in OneNote's menu bar")
            NSSound.beep()
            return
        }

        let pasteboard = NSPasteboard.general
        let before = pasteboard.changeCount
        let result = AXUIElementPerformAction(item, kAXPressAction as CFString)
        guard result == .success else {
            log("Pressing Copy failed: \(result.rawValue)")
            NSSound.beep()
            return
        }
        waitForText(pasteboard, changedFrom: before, until: Date().addingTimeInterval(1.5))
    }

    // OneNote's own Edit → Copy, found by its ⌘C shortcut so it works in any UI language.
    private func copyMenuItem(of pid: pid_t) -> AXUIElement? {
        guard let menuBar = axValue(AXUIElementCreateApplication(pid), kAXMenuBarAttribute) else { return nil }
        for menuBarItem in axChildren(menuBar as! AXUIElement) {
            for menu in axChildren(menuBarItem) {
                for item in axChildren(menu) where (axValue(item, kAXMenuItemCmdCharAttribute) as? String)?.uppercased() == "C" {
                    if axValue(item, kAXMenuItemCmdModifiersAttribute) as? Int == 0 { // ⌘ alone
                        return item
                    }
                }
            }
        }
        return nil
    }

    // OneNote writes the clipboard asynchronously; poll until its plain text shows up.
    private func waitForText(_ pasteboard: NSPasteboard, changedFrom before: Int, until deadline: Date) {
        if pasteboard.changeCount != before, let types = pasteboard.types, !types.isEmpty {
            guard types.contains(.string) else { return } // a picture or other non-text copy: keep it
            if let text = pasteboard.string(forType: .string) {
                // OneNote appends a line break to every copy.
                let plain = text.replacingOccurrences(of: "[\r\n]+$", with: "", options: .regularExpression)
                pasteboard.clearContents()
                pasteboard.setString(plain, forType: .string)
                return
            }
        }
        if Date() < deadline {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
                self.waitForText(pasteboard, changedFrom: before, until: deadline)
            }
        } else if pasteboard.changeCount != before {
            log("OneNote copied, but its plain text never arrived")
            NSSound.beep()
        }
        // No clipboard change at all means nothing was selected, same as OneNote's own ⌘C.
    }
}

let app = NSApplication.shared
app.setActivationPolicy(.accessory)
if !AXIsProcessTrustedWithOptions(["AXTrustedCheckOptionPrompt": true] as CFDictionary) {
    log("Waiting for Accessibility permission")
}
PlainCopy.shared.start()
app.run()
