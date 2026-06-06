import AppKit
import SwiftUI

final class ReckoningWindowController: NSWindowController {
    private let coordinator: AppCoordinator
    private let onDismiss: () -> Void

    init(coordinator: AppCoordinator, onDismiss: @escaping () -> Void) {
        self.coordinator = coordinator
        self.onDismiss = onDismiss

        let screen = NSScreen.main ?? NSScreen.screens.first!
        let rect = screen.frame

        let window = ReckoningWindow(
            contentRect: rect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.level = .modalPanel
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isOpaque = false
        window.backgroundColor = NSColor.black.withAlphaComponent(0.85)
        window.isMovable = false
        window.hasShadow = false
        window.ignoresMouseEvents = false

        super.init(window: window)

        let view = ReckoningView(
            day: coordinator.today,
            tasks: coordinator.todayTasks,
            onSubmit: { [weak self] retro, reasons in
                guard let self = self else { return }
                self.coordinator.submitReckoning(date: self.coordinator.today.date, retroactiveDoneIds: retro, skipReasons: reasons)
                self.onDismiss()
            }
        )
        let host = NSHostingController(rootView: view.environmentObject(coordinator))
        host.view.frame = rect
        window.contentView = host.view
    }

    required init?(coder: NSCoder) {
        fatalError()
    }

    override func showWindow(_ sender: Any?) {
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}

/// NSWindow subclass that intercepts Cmd-Q and Cmd-W to prevent dismissal.
final class ReckoningWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        // Block Cmd-W and Cmd-Q on this window
        if event.modifierFlags.contains(.command),
           let chars = event.charactersIgnoringModifiers?.lowercased(),
           chars == "w" || chars == "q" {
            NSSound.beep()
            return true
        }
        return super.performKeyEquivalent(with: event)
    }
}

struct ReckoningView: View {
    let day: Day
    let tasks: [DailyTask]
    let onSubmit: (Set<Int64>, [Int64: String]) -> Void

    @State private var retroactiveDoneIds = Set<Int64>()
    @State private var skipReasons: [Int64: String] = [:]

    private var allResolved: Bool {
        let unresolved = tasks.filter {
            $0.status == .pending && !retroactiveDoneIds.contains($0.id ?? -1)
        }
        for t in unresolved {
            let id = t.id ?? -1
            let reason = skipReasons[id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if reason.isEmpty { return false }
        }
        return true
    }

    var body: some View {
        ZStack {
            Color.clear
            VStack(spacing: 0) {
                Spacer()
                container {
                    VStack(alignment: .leading, spacing: 18) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Today's reckoning")
                                .font(.system(size: 28, weight: .bold))
                            Text("Mark anything you actually finished. For everything else, tell yourself why.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(configuredAtCaption())
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.top, 2)
                        }

                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                ForEach(tasks, id: \.id) { task in
                                    row(task)
                                }
                            }
                        }
                        .frame(maxHeight: 360)

                        HStack {
                            Spacer()
                            Button(action: { onSubmit(retroactiveDoneIds, finalReasons()) }) {
                                Text("Submit")
                                    .fontWeight(.semibold)
                                    .frame(minWidth: 140)
                                    .padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(!allResolved)
                        }
                    }
                    .padding(28)
                }
                .frame(maxWidth: 620)
                Spacer()
            }
        }
    }

    @ViewBuilder
    private func container<C: View>(@ViewBuilder _ content: () -> C) -> some View {
        content()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(.separator, lineWidth: 1)
            )
            .shadow(radius: 30)
    }

    @ViewBuilder
    private func row(_ task: DailyTask) -> some View {
        let id = task.id ?? -1
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 10) {
                if task.status == .done {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                        .font(.title3)
                    Text(task.title).strikethrough().font(.title3)
                } else if retroactiveDoneIds.contains(id) {
                    Button(action: { retroactiveDoneIds.remove(id) }) {
                        Image(systemName: "checkmark.square.fill")
                            .foregroundStyle(.green)
                            .font(.title3)
                    }.buttonStyle(.plain)
                    Text(task.title).strikethrough().font(.title3)
                } else {
                    Button(action: {
                        retroactiveDoneIds.insert(id)
                        skipReasons[id] = nil
                    }) {
                        Image(systemName: "square")
                            .font(.title3)
                    }.buttonStyle(.plain)
                    Text(task.title).font(.title3)
                }
                Spacer()
            }
            if task.status != .done && !retroactiveDoneIds.contains(id) {
                TextField("Why didn't this happen?", text: Binding(
                    get: { skipReasons[id] ?? "" },
                    set: { skipReasons[id] = $0 }
                ), axis: .vertical)
                .textFieldStyle(.roundedBorder)
                .lineLimit(2...4)
                .padding(.leading, 32)
            }
        }
    }

    /// Caption shown at the top of the reckoning window: when the plan was locked
    /// (i.e. when reckoning was first configured) and what reckoning time was set.
    /// If the user later delayed reckoning, `day.reckoningTime` reflects the latest
    /// value while `day.lockedAt` still points to the original lock.
    private func configuredAtCaption() -> String {
        let timePart = "Reckoning set for \(day.reckoningTime)"
        guard let lockedAt = day.lockedAt else {
            return timePart + "."
        }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return "Plan locked \(formatter.string(from: lockedAt)). " + timePart + "."
    }

    private func finalReasons() -> [Int64: String] {
        var result: [Int64: String] = [:]
        for t in tasks {
            guard let id = t.id else { continue }
            if t.status == .pending && !retroactiveDoneIds.contains(id) {
                result[id] = (skipReasons[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return result
    }
}
