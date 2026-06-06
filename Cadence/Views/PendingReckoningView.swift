import SwiftUI

struct PendingReckoningView: View {
    @EnvironmentObject var coord: AppCoordinator
    @State private var retroactiveDoneIds = Set<Int64>()
    @State private var skipReasons: [Int64: String] = [:]

    private var day: Day? { coord.pendingReckoningDay }

    private var allResolved: Bool {
        guard let day = day else { return false }
        let unresolved = coord.pendingReckoningTasks.filter {
            $0.status == .pending && !retroactiveDoneIds.contains($0.id ?? -1)
        }
        for t in unresolved {
            let id = t.id ?? -1
            let reason = skipReasons[id]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if reason.isEmpty {
                return false
            }
        }
        _ = day
        return true
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("Yesterday's reckoning")
                    .font(.title2.bold())
                Spacer()
                Text("🔥 \(coord.streak)")
                    .font(.headline)
            }
            Text("You didn't reckon \(day?.date ?? "yesterday"). Finish it before today's planner opens.")
                .font(.caption)
                .foregroundStyle(.secondary)

            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(coord.pendingReckoningTasks, id: \.id) { task in
                        taskRow(task)
                    }
                }
            }
            .frame(maxHeight: 240)

            HStack {
                Spacer()
                Button(action: submit) {
                    Text("Submit")
                        .fontWeight(.semibold)
                        .frame(minWidth: 100)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!allResolved)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func taskRow(_ task: DailyTask) -> some View {
        let id = task.id ?? -1
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top) {
                if task.status == .done {
                    Text("✓").foregroundStyle(.green)
                    Text(task.title).strikethrough()
                } else if retroactiveDoneIds.contains(id) {
                    Image(systemName: "checkmark.square.fill")
                        .foregroundStyle(.green)
                        .onTapGesture {
                            retroactiveDoneIds.remove(id)
                        }
                    Text(task.title).strikethrough()
                } else {
                    Image(systemName: "square")
                        .onTapGesture {
                            retroactiveDoneIds.insert(id)
                            skipReasons[id] = nil
                        }
                    Text(task.title)
                }
            }
            if task.status != .done && !retroactiveDoneIds.contains(id) {
                TextField("Why didn't this happen?", text: Binding(
                    get: { skipReasons[id] ?? "" },
                    set: { skipReasons[id] = $0 }
                ))
                .textFieldStyle(.roundedBorder)
                .padding(.leading, 22)
            }
        }
    }

    private func submit() {
        guard let day = day else { return }
        // For tasks already done, no action. Pending tasks: either retro-done or skipped with reason.
        let pendingNotRetro = coord.pendingReckoningTasks.filter {
            $0.status == .pending && !retroactiveDoneIds.contains($0.id ?? -1)
        }
        var finalReasons: [Int64: String] = [:]
        for t in pendingNotRetro {
            if let id = t.id, let r = skipReasons[id] {
                finalReasons[id] = r.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        coord.submitReckoning(date: day.date, retroactiveDoneIds: retroactiveDoneIds, skipReasons: finalReasons)
        retroactiveDoneIds.removeAll()
        skipReasons.removeAll()
    }
}
