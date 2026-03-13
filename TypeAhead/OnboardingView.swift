//
//  OnboardingView.swift
//  TypeAhead
//

import SwiftUI
import Combine

// MARK: - Container

struct OnboardingView: View {
    @Environment(\.dismissWindow) var dismissWindow

    @State private var step = 0
    @State private var accessibilityGranted = false
    @State private var inputMonitoringGranted = false
    @State private var bothGranted = false

    private let permTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
    private let totalSteps = 5

    var body: some View {
        VStack(spacing: 0) {
            // Step content
            ZStack {
                WelcomeStep()
                    .stepTransition(index: 0, current: step)
                PermissionsStep(
                    accessibilityGranted: accessibilityGranted,
                    inputMonitoringGranted: inputMonitoringGranted,
                    bothGranted: bothGranted
                )
                .stepTransition(index: 1, current: step)
                HowItWorksStep()
                    .stepTransition(index: 2, current: step)
                FeaturesStep()
                    .stepTransition(index: 3, current: step)
                AllSetStep()
                    .stepTransition(index: 4, current: step)
            }
            .frame(width: 480, height: 380)
            .animation(.easeInOut(duration: 0.22), value: step)
            .clipped()

            Divider()

            // Navigation bar
            HStack {
                Button("Back") { withAnimation { step -= 1 } }
                    .opacity(step > 0 ? 1 : 0)
                    .disabled(step == 0)

                Spacer()

                HStack(spacing: 7) {
                    ForEach(0..<totalSteps, id: \.self) { i in
                        Circle()
                            .frame(width: i == step ? 7 : 5, height: i == step ? 7 : 5)
                            .foregroundStyle(i == step ? Color.accentColor : Color.secondary.opacity(0.3))
                            .animation(.spring(response: 0.3), value: step)
                    }
                }

                Spacer()

                if step < totalSteps - 1 {
                    Button("Next") { withAnimation { step += 1 } }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Done") { dismissWindow(id: "onboarding") }
                        .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 16)
        }
        .frame(width: 480)
        .onReceive(permTimer) { _ in checkPermissions() }
        .onAppear { checkPermissions() }
    }

    private func checkPermissions() {
        accessibilityGranted = KeyboardMonitor.isAccessibilityGranted()
        inputMonitoringGranted = KeyboardMonitor.isInputMonitoringGranted()
        if accessibilityGranted && inputMonitoringGranted && !bothGranted {
            bothGranted = true
            // Auto-advance from the permissions step
            if step == 1 {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) {
                    withAnimation { step = 2 }
                }
            }
        }
    }
}

// MARK: - Slide transition helper

private extension View {
    func stepTransition(index: Int, current: Int) -> some View {
        self
            .opacity(index == current ? 1 : 0)
            .offset(x: index == current ? 0 : (index < current ? -30 : 30))
    }
}

// MARK: - Step 1: Welcome

private struct WelcomeStep: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(nsImage: NSImage(named: "AppIcon") ?? NSImage())
                .resizable()
                .frame(width: 72, height: 72)
                .padding(.bottom, 10)

            Text("TypeAhead")
                .font(.largeTitle.bold())
            Text("Your system-wide text expander")
                .font(.title3)
                .foregroundStyle(.secondary)
                .padding(.bottom, 28)

            VStack(alignment: .leading, spacing: 12) {
                featureRow("bolt.fill",    "Expand short triggers into full text — anywhere", .yellow)
                featureRow("terminal",     "Run shell commands and insert their output",       .orange)
                featureRow("curlybraces",  "Fill in placeholders interactively",               .cyan)
                featureRow("command",      "Trigger keyboard shortcuts by typing a word",      .purple)
            }
            .padding(.horizontal, 52)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureRow(_ icon: String, _ text: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.callout)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(text)
                .font(.callout)
        }
    }
}

// MARK: - Step 2: Permissions

private struct PermissionsStep: View {
    let accessibilityGranted: Bool
    let inputMonitoringGranted: Bool
    let bothGranted: Bool

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 8) {
                Image(systemName: "lock.shield")
                    .font(.system(size: 36))
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 4)
                Text("Two Permissions Required")
                    .font(.title2.bold())
                Text("TypeAhead needs these to monitor and expand your keystrokes system-wide.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            .padding(.top, 32)

            VStack(spacing: 12) {
                permissionRow(
                    title: "Accessibility",
                    detail: "Reads the cursor position to show the popup in the right place.",
                    granted: accessibilityGranted,
                    action: { KeyboardMonitor.requestAccessibilityPermission() },
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                )
                permissionRow(
                    title: "Input Monitoring",
                    detail: "Detects keypresses globally so triggers work in any app.",
                    granted: inputMonitoringGranted,
                    action: { CGRequestListenEventAccess() },
                    settingsURL: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent"
                )
            }
            .padding(.horizontal, 32)
            .padding(.top, 20)

            Group {
                if bothGranted {
                    Label("All set — continuing…", systemImage: "checkmark.seal.fill")
                        .foregroundStyle(.green)
                        .font(.callout.bold())
                } else {
                    Text("Grant both permissions above to continue.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.top, 14)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func permissionRow(
        title: String, detail: String, granted: Bool,
        action: (() -> Void)?, settingsURL: String
    ) -> some View {
        HStack(spacing: 14) {
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(granted ? .green : .red)
                .frame(width: 28)

            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                Text(detail).font(.caption).foregroundStyle(.secondary)
            }

            Spacer()

            if !granted {
                Button("Open Settings") {
                    action?()
                    if let url = URL(string: settingsURL) { NSWorkspace.shared.open(url) }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Step 3: How it works (animated demo)

private struct HowItWorksStep: View {
    @State private var stage = 0

    private let demoTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    private struct DemoStage {
        let text: String
        let showPopup: Bool
        let expanded: Bool
    }

    private let stages: [DemoStage] = [
        DemoStage(text: "Meeting at 9am, ",          showPopup: false, expanded: false),
        DemoStage(text: "Meeting at 9am, //",         showPopup: false, expanded: false),
        DemoStage(text: "Meeting at 9am, //omw",      showPopup: true,  expanded: false),
        DemoStage(text: "Meeting at 9am, On My Way!", showPopup: false, expanded: true),
    ]

    var body: some View {
        VStack(spacing: 16) {
            VStack(spacing: 6) {
                Text("Type a trigger, get an expansion")
                    .font(.title2.bold())
                Text("Type your trigger prefix (default: //) followed by a keyword.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)
            .padding(.top, 28)

            // Animated demo
            VStack(alignment: .leading, spacing: 0) {
                // Fake text field
                HStack(spacing: 0) {
                    Text(stages[stage].text)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(stages[stage].expanded ? Color.green : Color.primary)
                        .animation(.easeInOut(duration: 0.2), value: stage)
                    Rectangle()
                        .frame(width: 2, height: 16)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                }
                .padding(12)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.secondary.opacity(0.2), lineWidth: 1))

                // Popup mockup
                if stages[stage].showPopup {
                    HStack(spacing: 8) {
                        Text("omw")
                            .fontWeight(.semibold)
                            .foregroundStyle(.white)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.4))
                        Text("On My Way!")
                            .foregroundStyle(.white.opacity(0.75))
                        Spacer()
                        Text("⇥")
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 9)
                    .background(
                        Color(red: 0.13, green: 0.13, blue: 0.15),
                        in: RoundedRectangle(cornerRadius: 9)
                    )
                    .overlay(RoundedRectangle(cornerRadius: 9).strokeBorder(.white.opacity(0.12), lineWidth: 0.5))
                    .shadow(color: .black.opacity(0.35), radius: 8, y: 3)
                    .padding(.top, 5)
                    .transition(.opacity.combined(with: .scale(scale: 0.96, anchor: .topLeading)))
                }
            }
            .padding(.horizontal, 48)
            .animation(.easeInOut(duration: 0.25), value: stage)

            // Key hints
            HStack(spacing: 18) {
                keyHint("⇥ / ↩", "Accept")
                keyHint("↑  ↓",  "Navigate")
                keyHint("⎋",     "Dismiss")
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onReceive(demoTimer) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                stage = (stage + 1) % stages.count
            }
        }
    }

    private func keyHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 5) {
            Text(key)
                .font(.system(.caption, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(.quaternary, in: RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Step 4: Power features

private struct FeaturesStep: View {
    var body: some View {
        VStack(spacing: 14) {
            VStack(spacing: 6) {
                Text("More Than Plain Text")
                    .font(.title2.bold())
                Text("Three extra modes, toggled per snippet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 28)

            HStack(alignment: .top, spacing: 10) {
                featureCard(
                    icon: "terminal", color: .orange,
                    title: "Shell",
                    body: "The expansion is a shell command. Its stdout is inserted — great for dates, git info, anything scriptable.",
                    example: "$(date +%Y-%m-%d)"
                )
                featureCard(
                    icon: "curlybraces", color: .cyan,
                    title: "Placeholders",
                    body: "Add {tokens} to your text. TypeAhead asks for each value one by one before inserting.",
                    example: "Hi {Name}, re: {Topic}"
                )
                featureCard(
                    icon: "command", color: .purple,
                    title: "Keystroke",
                    body: "Assign a shortcut as the expansion. Typing the trigger fires it — even in apps where hotkeys conflict.",
                    example: "⌘⇧P  →  palette"
                )
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func featureCard(icon: String, color: Color, title: String, body: String, example: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(title)
                .font(.headline)
            Text(body)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Text(example)
                .font(.system(.caption2, design: .monospaced))
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: 5))
                .foregroundStyle(color)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Step 5: All set

private struct AllSetStep: View {
    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 52))
                .foregroundStyle(.green)
                .padding(.bottom, 12)

            Text("You're all set!")
                .font(.title2.bold())
            Text("TypeAhead is running in your menu bar.")
                .foregroundStyle(.secondary)
                .padding(.bottom, 26)

            VStack(alignment: .leading, spacing: 11) {
                tip("Type your trigger prefix anywhere to see matching snippets")
                tip("Press Tab or Return to expand · Escape to dismiss")
                tip("Click the menu bar icon to add and manage snippets")
                tip("Set a command shortcut to open the picker without typing")
            }
            .padding(.horizontal, 52)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func tip(_ text: String) -> some View {
        Label(text, systemImage: "lightbulb")
            .font(.callout)
            .foregroundStyle(.secondary)
    }
}
