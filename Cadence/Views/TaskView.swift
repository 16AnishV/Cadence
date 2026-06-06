import SwiftUI

struct TaskView: View {
    @EnvironmentObject var coord: AppCoordinator
    @State private var showingDelayPicker = false

    private var topPending: DailyTask? {
        coord.todayTasks.first { $0.status == .pending }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Today's plan")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("🔥 \(coord.streak)")
                    .font(.headline)
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(coord.todayTasks, id: \.id) { task in
                    TaskRow(task: task, isCurrent: task.id == topPending?.id) {
                        coord.markDone(taskId: task.id)
                    }
                }
            }

            HStack {
                progressDots()
                Spacer()
                Button(action: { showingDelayPicker = true }) {
                    Text("Reckoning at \(coord.today.reckoningTime)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showingDelayPicker) {
                    FutureTimePickerView(title: "Delay reckoning until…", confirmLabel: "Set") { newTime in
                        coord.delayReckoning(to: newTime)
                        showingDelayPicker = false
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onReceive(NotificationCenter.default.publisher(for: .cadenceOpenDelayPicker)) { _ in
            showingDelayPicker = true
        }
    }

    @ViewBuilder
    private func progressDots() -> some View {
        let total = coord.todayTasks.count
        let done = coord.todayTasks.filter { $0.status == .done }.count
        HStack(spacing: 4) {
            ForEach(0..<total, id: \.self) { i in
                Circle()
                    .fill(i < done ? Color.accentColor : Color.secondary.opacity(0.3))
                    .frame(width: 8, height: 8)
            }
        }
    }
}

private struct TaskRow: View {
    let task: DailyTask
    let isCurrent: Bool
    let onDone: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            if task.status == .done {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
                Text(task.title)
                    .strikethrough()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
            } else {
                Text(task.title)
                    .fontWeight(isCurrent ? .semibold : .regular)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 8)
                Button("Done", action: onDone)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .modifier(EnterShortcutIfCurrent(isCurrent: isCurrent))
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isCurrent ? Color.accentColor.opacity(0.10) : Color.clear)
        )
    }
}

private struct EnterShortcutIfCurrent: ViewModifier {
    let isCurrent: Bool
    func body(content: Content) -> some View {
        if isCurrent {
            content.keyboardShortcut(.return, modifiers: [])
        } else {
            content
        }
    }
}

struct AllDoneView: View {
    @EnvironmentObject var coord: AppCoordinator

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All done for today.")
                    .font(.title2.bold())
                Spacer()
                Text("🔥 \(coord.streak)")
                    .font(.headline)
            }
            Text("Reckoning at \(coord.today.reckoningTime).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Button(action: {
                coord.openReckoningNow()
            }) {
                Text("Run reckoning now")
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

