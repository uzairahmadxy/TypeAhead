//
//  AppMonitor.swift
//  TypeAhead
//

import Foundation

@MainActor
class AppMonitor: ObservableObject {
    @Published var isEnabled = false {
        didSet {
            if isEnabled {
                keyboardMonitor.start()
            } else {
                keyboardMonitor.stop()
            }
        }
    }

    private let snippets: [String: String] = [
        "@email": "uzair@gmail.com",
        "@addr":  "123 Fake St Montreal",
        "@name":  "Uzair Ahmad"
    ]

    private var wordBuffer: WordBuffer
    private var keyboardMonitor: KeyboardMonitor

    init() {
        let buffer = WordBuffer(snippets: [
            "@email": "uzair@gmail.com",
            "@addr":  "123 Fake St Montreal",
            "@name":  "Uzair Ahmad"
        ])
        self.wordBuffer = buffer
        self.keyboardMonitor = KeyboardMonitor(wordBuffer: buffer)
    }
}
