import SwiftUI
import UniformTypeIdentifiers

/// Lightweight drag payload carrying a task's id for drag-to-reorder.
struct DraggableTaskID: Codable, Transferable {
    let id: Int64
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .cadenceTask)
    }
}

extension UTType {
    static let cadenceTask = UTType(exportedAs: "com.cadence.task")
}

struct TaskView: View {
    @EnvironmentObject var coord: AppCoordinator
    @State private var showingDelayPicker = false

    private var topPending: DailyTask? {
        coord.todayTasks.first { $0.status == .pending }
    }

    /// Move the dragged task so it lands at the target task's slot, then persist.
    private func moveTask(draggedId: Int64, onto targetId: Int64) {
        guard draggedId != targetId else { return }
        var ids = coord.todayTasks.map { $0.id }.compactMap { $0 }
        guard let from = ids.firstIndex(of: draggedId),
              let to = ids.firstIndex(of: targetId) else { return }
        ids.remove(at: from)
        ids.insert(draggedId, at: to)
        coord.reorderTasks(orderedIds: ids)
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
                    TaskRow(
                        task: task,
                        isCurrent: task.id == topPending?.id,
                        onDone: { coord.markDone(taskId: task.id) },
                        onDropTask: { draggedId in
                            if let targetId = task.id { moveTask(draggedId: draggedId, onto: targetId) }
                        }
                    )
                }
            }

            AddTaskField()

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
                    FutureTimePickerView(title: "Reckoning at", confirmLabel: "Set") { newTime in
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

/// Inline "add a task" affordance shown during an active session (in both `TaskView`
/// and `AllDoneView`). Appends to the running session via `coord.addTask`; there's no
/// 5-task cap here — that limit only applies to the initial planner lock.
private struct AddTaskField: View {
    @EnvironmentObject var coord: AppCoordinator
    @State private var newTitle = ""

    private var trimmed: String {
        newTitle.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField("Add a task", text: $newTitle)
                .textFieldStyle(.roundedBorder)
                .onSubmit(add)
            Button(action: add) {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderless)
            .disabled(trimmed.isEmpty)
        }
    }

    private func add() {
        guard !trimmed.isEmpty else { return }
        coord.addTask(title: trimmed)
        newTitle = ""
    }
}

private struct TaskRow: View {
    let task: DailyTask
    let isCurrent: Bool
    let onDone: () -> Void
    let onDropTask: (Int64) -> Void

    @State private var isTargeted = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.tertiary)
                .font(.callout)

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
        .overlay(alignment: .top) {
            if isTargeted {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.accentColor)
                    .frame(height: 2)
            }
        }
        .contentShape(Rectangle())
        .draggable(DraggableTaskID(id: task.id ?? -1))
        .dropDestination(for: DraggableTaskID.self) { payload, _ in
            guard let dragged = payload.first else { return false }
            onDropTask(dragged.id)
            return true
        } isTargeted: { isTargeted = $0 }
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
            AddTaskField()
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

