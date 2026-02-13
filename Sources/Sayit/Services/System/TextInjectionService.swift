import Cocoa

@MainActor
final class TextInjectionService {
    func inject(text: String) async {
        let pasteboard = NSPasteboard.general

        // Backup current pasteboard
        let backup = pasteboard.string(forType: .string)
        let backupItems = pasteboard.pasteboardItems?.compactMap { item -> [NSPasteboard.PasteboardType: Data]? in
            var dict = [NSPasteboard.PasteboardType: Data]()
            for type in item.types {
                if let data = item.data(forType: type) {
                    dict[type] = data
                }
            }
            return dict.isEmpty ? nil : dict
        }

        // Set our text
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        // Small delay to ensure pasteboard is ready
        try? await Task.sleep(for: .milliseconds(50))

        // Simulate ⌘V
        simulatePaste()

        // Wait for paste to complete, then restore
        try? await Task.sleep(for: .milliseconds(200))

        // Restore original pasteboard
        pasteboard.clearContents()
        if let backupItems = backupItems, !backupItems.isEmpty {
            for itemDict in backupItems {
                let item = NSPasteboardItem()
                for (type, data) in itemDict {
                    item.setData(data, forType: type)
                }
                pasteboard.writeObjects([item])
            }
        } else if let backup = backup {
            pasteboard.setString(backup, forType: .string)
        }
    }

    private func simulatePaste() {
        let keyDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true) // 'v'
        let keyUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false)

        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cgAnnotatedSessionEventTap)
        keyUp?.post(tap: .cgAnnotatedSessionEventTap)
    }
}
