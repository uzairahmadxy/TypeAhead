//
//  TextInjector.swift
//  TypeAhead
//

import CoreGraphics

struct TextInjector {

    /// A magic value stamped on events we synthesize so KeyboardMonitor can
    /// skip them and avoid a re-entrancy loop.
    static let markerValue: Int64 = 0x54414865  // "TAHe"

    /// Deletes the typed trigger then fires a real key+modifier event — all in one
    /// synchronous batch so nothing else can interleave.
    func injectKeystroke(keyCode: CGKeyCode, modifiers: CGEventFlags, replacingPrefixOfLength prefixLength: Int) {
        let source = CGEventSource(stateID: .hidSystemState)
        for _ in 0..<prefixLength {
            postKey(0x33, keyDown: true,  source: source)
            postKey(0x33, keyDown: false, source: source)
        }
        // Post without the marker — the shortcut should reach the focused app
        // exactly as if the user pressed it themselves.
        guard let dn = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false) else { return }
        dn.flags = modifiers
        up.flags = modifiers
        dn.post(tap: .cgAnnotatedSessionEventTap)
        up.post(tap: .cgAnnotatedSessionEventTap)
    }

    func inject(expansion: String, replacingPrefixOfLength prefixLength: Int) {
        let source = CGEventSource(stateID: .hidSystemState)

        // Erase the typed prefix with Delete keypresses
        for _ in 0..<prefixLength {
            postKey(0x33, keyDown: true,  source: source)   // Delete down
            postKey(0x33, keyDown: false, source: source)   // Delete up
        }

        // Type the expansion character by character
        let utf16 = Array(expansion.utf16)
        var i = 0
        while i < utf16.count {
            // Handle surrogate pairs for characters outside BMP
            let chars: [UniChar]
            if (0xD800...0xDBFF).contains(utf16[i]) && i + 1 < utf16.count {
                chars = [utf16[i], utf16[i + 1]]
                i += 2
            } else {
                chars = [utf16[i]]
                i += 1
            }
            postUnicode(chars, keyDown: true,  source: source)
            postUnicode(chars, keyDown: false, source: source)
        }
    }

    // MARK: - Private helpers

    private func postKey(_ keyCode: CGKeyCode, keyDown: Bool, source: CGEventSource?) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: keyDown) else { return }
        event.setIntegerValueField(.eventSourceUserData, value: Self.markerValue)
        event.post(tap: .cgAnnotatedSessionEventTap)
    }

    private func postUnicode(_ chars: [UniChar], keyDown: Bool, source: CGEventSource?) {
        guard let event = CGEvent(keyboardEventSource: source, virtualKey: 0, keyDown: keyDown) else { return }
        event.keyboardSetUnicodeString(stringLength: chars.count, unicodeString: chars)
        event.setIntegerValueField(.eventSourceUserData, value: Self.markerValue)
        event.post(tap: .cgAnnotatedSessionEventTap)
    }
}
