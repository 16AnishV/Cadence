import SwiftUI

struct PlannerView: View {
    @EnvironmentObject var coord: AppCoordinator
    @State private var titles: [String] = ["", "", "", "", ""]
    @State private var showingSnoozePicker = false

    private var hasAtLeastOne: Bool {
        titles.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today's plan")
                .font(.title2.bold())

            Text(prettyDate())
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(0..<5, id: \.self) { i in
                    HStack {
                        Text("\(i + 1).")
                            .frame(width: 18, alignment: .leading)
                            .foregroundStyle(.secondary)
                        TextField(i == 0 ? "First task (required)" : "Optional", text: $titles[i])
                            .textFieldStyle(.roundedBorder)
                    }
                }
            }

            HStack {
                if coord.canSnoozePlanner() {
                    Button("Skip planning for now") {
                        showingSnoozePicker = true
                    }
                    .buttonStyle(.link)
                    .popover(isPresented: $showingSnoozePicker) {
                        SnoozePickerView { minutes in
                            coord.snoozePlanner(minutes: minutes)
                            showingSnoozePicker = false
                            // Close popover so it can re-open at snooze time
                            if let delegate = NSApp.delegate as? AppDelegate {
                                delegate.refreshMenuBarLabel()
                            }
                            NSApp.windows.forEach { w in
                                if w.contentViewController is NSHostingController<PopoverRoot> {
                                    w.close()
                                }
                            }
                        }
                    }
                }
                Spacer()
                Button(action: lockTapped) {
                    Text("Lock & Start")
                        .fontWeight(.semibold)
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasAtLeastOne)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func prettyDate() -> String {
        let f = DateFormatter()
        f.dateStyle = .full
        return f.string(from: Date())
    }

    private func lockTapped() {
        coord.lockPlan(titles: titles)
    }
}

struct SnoozePickerView: View {
    @State private var minutes: Int = 30
    let onPick: (Int) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Remind me in…")
                .font(.headline)
            Picker("", selection: $minutes) {
                Text("30 min").tag(30)
                Text("60 min").tag(60)
                Text("90 min").tag(90)
                Text("120 min").tag(120)
            }
            .pickerStyle(.segmented)
            HStack {
                Spacer()
                Button("Snooze") { onPick(minutes) }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(16)
        .frame(width: 280)
    }
}
