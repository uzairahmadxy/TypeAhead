//
//  KeyboardMonitor.swift
//  TypeAhead
//

import AppKit
import CoreGraphics

class KeyboardMonitor {
    let wordBuffer: WordBuffer
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    init(wordBuffer: WordBuffer) {
        self.wordBuffer = wordBuffer
    }

    func start() {
        guard eventTap == nil else { return }

        let eventMask = CGEventMask(1 << CGEventType.keyDown.rawValue)

        // Pass an unretained pointer to self via userInfo.
        // KeyboardMonitor is kept alive by AppMonitor for the app's lifetime.
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: eventMask,
            callback: { (proxy, type, event, userInfo) -> Unmanaged<CGEvent>? in
                guard type == .keyDown, let ptr = userInfo else { return nil }

                let monitor = Unmanaged<KeyboardMonitor>.fromOpaque(ptr).takeUnretainedValue()

                if let nsEvent = NSEvent(cgEvent: event),
                   let chars = nsEvent.characters, !chars.isEmpty {
                    // Dispatch to main actor since WordBuffer and logging live there
                    DispatchQueue.main.async {
                        for char in chars {
                            monitor.wordBuffer.process(character: char)
                        }
                    }
                }
                return nil
            },
            userInfo: selfPtr
        ) else {
            print("[TypeAhead] ⚠️ Failed to create event tap.")
            print("[TypeAhead]    Go to System Settings → Privacy & Security → Accessibility")
            print("[TypeAhead]    and grant TypeAhead permission, then restart the app.")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        print("[TypeAhead] ✅ Keyboard monitoring started.")
    }

    func stop() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
            runLoopSource = nil
        }
        eventTap = nil
        print("[TypeAhead] Keyboard monitoring stopped.")
    }
}
