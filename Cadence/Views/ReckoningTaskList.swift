import SwiftUI

/// Shared task-resolution UI used by both the popover-sized `PendingReckoningView`
/// (yesterday's late reckoning) and the full-screen `ReckoningView` (today's
/// reckoning). Each row is one of three states:
///   - already done at task time (read-only checkmark)
///   - retroactively-done (user toggled it on during reckoning)
///   - pending with a required "why didn't this happen?" reason field
///
/// Callers own the two pieces of state (`retroactiveDoneIds`, `skipReasons`) so
/// they can drive Submit-button enablement via `allReckoningTasksResolved`.
struct ReckoningTaskList: View {
    let tasks: [DailyTask]
    @Binding var retroactiveDoneIds: Set<Int64>
    @Binding var skipReasons: [Int64: String]

    /// Visual scale: popover-sized vs. full-screen. Drives row font and reason
    /// field shape (single-line vs. multi-line).
    enum Style {
        case compact   // PendingReckoningView (popover)
        case prominent // ReckoningView (full-screen)
    }
    let style: Style

    var body: some View {
        VStack(alignment: .leading, spacing: style == .prominent ? 14 : 10) {
            ForEach(tasks, id: \.id) { task in
                row(task)
            }
        }
    }

    @ViewBuilder
    private func row(_ task: DailyTask) -> some View {
        let id = task.id ?? -1
        let isRetro = retroactiveDoneIds.contains(id)
        let rowFont: Font = style == .prominent ? .title3 : .body
        let reasonIndent: CGFloat = style == .prominent ? 32 : 22

        VStack(alignment: .leading, spacing: style == .prominent ? 6 : 4) {
            HStack(alignment: .top, spacing: style == .prominent ? 10 : 8) {
                checkboxAndTitle(task: task, id: id, isRetro: isRetro, font: rowFont)
                Spacer(minLength: 0)
            }
            if task.status != .done && !isRetro {
                reasonField(id: id, indent: reasonIndent)
            }
        }
    }

    @ViewBuilder
    private func checkboxAndTitle(task: DailyTask, id: Int64, isRetro: Bool, font: Font) -> some View {
        if task.status == .done {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
                .font(font)
            Text(task.title).strikethrough().font(font)
        } else if isRetro {
            Button(action: { retroactiveDoneIds.remove(id) }) {
                Image(systemName: "checkmark.square.fill")
                    .foregroundStyle(.green)
                    .font(font)
            }.buttonStyle(.plain)
            Text(task.title).strikethrough().font(font)
        } else {
            Button(action: {
                retroactiveDoneIds.insert(id)
                skipReasons[id] = nil
            }) {
                Image(systemName: "square").font(font)
            }.buttonStyle(.plain)
            Text(task.title).font(font)
        }
    }

    @ViewBuilder
    private func reasonField(id: Int64, indent: CGFloat) -> some View {
        let binding = Binding(
            get: { skipReasons[id] ?? "" },
            set: { skipReasons[id] = $0 }
        )
        Group {
            if style == .prominent {
                TextField("Why didn't this happen?", text: binding, axis: .vertical)
                    .lineLimit(2...4)
            } else {
                TextField("Why didn't this happen?", text: binding)
            }
        }
        .textFieldStyle(.roundedBorder)
        .padding(.leading, indent)
    }
}

/// Shared Submit-button predicate. True iff every pending-and-not-retroactively-
/// done task has a non-empty trimmed reason.
func allReckoningTasksResolved(
    tasks: [DailyTask],
    retroactiveDoneIds: Set<Int64>,
    skipReasons: [Int64: String]
) -> Bool {
    for task in tasks {
        let id = task.id ?? -1
        guard task.status == .pending, !retroactiveDoneIds.contains(id) else { continue }
        let reason = skipReasons[id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if reason.isEmpty { return false }
    }
    return true
}
