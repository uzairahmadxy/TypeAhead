//
//  CursorTracker.swift
//  TypeAhead
//

import AppKit

struct CursorTracker {

    /// Returns the cursor rect in screen coordinates with top-left origin
    /// (the coordinate system AXUIElement uses). Falls back to mouse position.
    func getCursorRect() -> CGRect {
        return axCursorRect() ?? mouseFallbackRect()
    }

    private func axCursorRect() -> CGRect? {
        guard let app = NSWorkspace.shared.frontmostApplication else { return nil }

        let axApp = AXUIElementCreateApplication(app.processIdentifier)

        var focusedRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axApp, kAXFocusedUIElementAttribute as CFString, &focusedRef) == .success,
              let focusedRef else { return nil }
        let axElement = focusedRef as! AXUIElement

        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef else { return nil }

        var boundsRef: CFTypeRef?
        guard AXUIElementCopyParameterizedAttributeValue(
            axElement,
            kAXBoundsForRangeParameterizedAttribute as CFString,
            rangeRef,
            &boundsRef
        ) == .success,
              let boundsRef else { return nil }
        let axBounds = boundsRef as! AXValue

        var rect = CGRect.zero
        AXValueGetValue(axBounds, .cgRect, &rect)
        return rect == .zero ? nil : rect
    }

    /// NSEvent.mouseLocation uses bottom-left origin; convert to top-left for consistency.
    private func mouseFallbackRect() -> CGRect {
        let mouse = NSEvent.mouseLocation
        let screenH = NSScreen.main?.frame.height ?? 0
        return CGRect(x: mouse.x, y: screenH - mouse.y, width: 2, height: 18)
    }
}
