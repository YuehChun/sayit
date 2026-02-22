import Cocoa
import Carbon

final class GlobalShortcutManager: @unchecked Sendable {
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private let onKeyAction: @Sendable (Bool) -> Void
    private let lock = NSLock()
    private var _isFnDown = false
    private var _isRecording = false
    private var _isStopped = false

    private var isFnDown: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isFnDown }
        set { lock.lock(); defer { lock.unlock() }; _isFnDown = newValue }
    }

    private var isRecording: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isRecording }
        set { lock.lock(); defer { lock.unlock() }; _isRecording = newValue }
    }

    private var isStopped: Bool {
        get { lock.lock(); defer { lock.unlock() }; return _isStopped }
        set { lock.lock(); defer { lock.unlock() }; _isStopped = newValue }
    }

    nonisolated(unsafe) private static var shared: GlobalShortcutManager?

    init(onFnKey: @escaping @Sendable (Bool) -> Void) {
        self.onKeyAction = onFnKey
        GlobalShortcutManager.shared = self
    }

    func start() {
        registerCarbonHotKey()

        // Prompt user to grant Accessibility if not already trusted
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)
        NSLog("[Sayit] AXIsProcessTrusted = %@", trusted ? "YES" : "NO")

        if tryEventTap(option: .defaultTap, label: "defaultTap") { return }
        if tryEventTap(option: .listenOnly, label: "listenOnly") { return }

        NSLog("[Sayit] Fn key unavailable. Use Option+R to toggle recording.")
        NSLog("[Sayit] To enable Fn key: System Settings → Accessibility → add Sayit")
    }

    // MARK: - CGEvent tap for Fn key

    private func tryEventTap(option: CGEventTapOptions, label: String) -> Bool {
        let eventMask: CGEventMask = (1 << CGEventType.flagsChanged.rawValue)

        // Use passRetained to prevent dangling pointer in callback
        let retainedSelf = Unmanaged.passRetained(self)

        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo = userInfo else { return Unmanaged.passRetained(event) }
            let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userInfo).takeUnretainedValue()

            // Don't process events if manager is stopped
            if manager.isStopped {
                return Unmanaged.passRetained(event)
            }

            if type == .tapDisabledByUserInput || type == .tapDisabledByTimeout {
                if let tap = manager.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passRetained(event)
            }

            manager.handleFnFlags(event)
            return Unmanaged.passRetained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: option,
            eventsOfInterest: eventMask,
            callback: callback,
            userInfo: retainedSelf.toOpaque()
        ) else {
            // Balance the retain since tap wasn't created
            retainedSelf.release()
            NSLog("[Sayit] CGEvent tap (%@) failed to create", label)
            return false
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        NSLog("[Sayit] Fn key enabled via CGEvent tap (%@)", label)
        return true
    }

    private func handleFnFlags(_ event: CGEvent) {
        let flags = event.flags
        let fnPressed = flags.contains(.maskSecondaryFn)

        lock.lock()
        let wasDown = _isFnDown
        if fnPressed && !wasDown {
            _isFnDown = true
            _isRecording = true
            lock.unlock()
            NSLog("[Sayit] Fn DOWN → start recording")
            onKeyAction(true)
        } else if !fnPressed && wasDown {
            _isFnDown = false
            _isRecording = false
            lock.unlock()
            NSLog("[Sayit] Fn UP → stop recording")
            onKeyAction(false)
        } else {
            lock.unlock()
        }
    }

    // MARK: - Carbon hotkey: Option+R toggle

    private func registerCarbonHotKey() {
        var eventType = EventTypeSpec(
            eventClass: UInt32(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handler: EventHandlerUPP = { _, _, _ -> OSStatus in
            GlobalShortcutManager.shared?.handleCarbonHotKey()
            return noErr
        }
        var handlerRef: EventHandlerRef?
        InstallEventHandler(GetApplicationEventTarget(), handler, 1, &eventType, nil, &handlerRef)
        self.eventHandlerRef = handlerRef

        let hotKeyID = EventHotKeyID(signature: FourCharCode(0x54594C53), id: 1)
        var ref: EventHotKeyRef?
        RegisterEventHotKey(UInt32(kVK_ANSI_R), UInt32(optionKey), hotKeyID, GetApplicationEventTarget(), 0, &ref)
        self.hotKeyRef = ref
        NSLog("[Sayit] Option+R toggle registered")
    }

    private func handleCarbonHotKey() {
        lock.lock()
        _isRecording.toggle()
        let recording = _isRecording
        lock.unlock()
        NSLog("[Sayit] Option+R → recording: %@", recording ? "START" : "STOP")
        onKeyAction(recording)
    }

    // MARK: - Cleanup

    func stop() {
        isStopped = true

        // 1. Remove from run loop FIRST (stops callback delivery)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }

        // 2. Disable event tap
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }

        // 3. Unregister Carbon hotkey
        if let ref = hotKeyRef { UnregisterEventHotKey(ref) }
        if let ref = eventHandlerRef { RemoveEventHandler(ref) }

        // 4. Release the retained self from CGEvent tap
        if eventTap != nil {
            // Balance the passRetained from tryEventTap
            Unmanaged.passUnretained(self).release()
        }

        runLoopSource = nil
        eventTap = nil
        hotKeyRef = nil
        eventHandlerRef = nil

        GlobalShortcutManager.shared = nil
    }

    deinit { stop() }
}
