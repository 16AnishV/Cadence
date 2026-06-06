import SwiftUI

struct PendingReckoningView: View {
    @EnvironmentObject var coord: AppCoordinator
    @State private var retroactiveDoneIds = Set<Int64>()
    @State private var skipReasons: [Int64: String] = [:]

    private var day: Day? { coord.pendingReckoningDay }

    private var allResolved: Bool {
        guard day != nil else { return false }
        return allReckoningTasksResolved(
            tasks: coord.pendingReckoningTasks,
            retroactiveDoneIds: retroactiveDoneIds,
            skipReasons: skipReasons
        )
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
                ReckoningTaskList(
                    tasks: coord.pendingReckoningTasks,
                    retroactiveDoneIds: $retroactiveDoneIds,
                    skipReasons: $skipReasons,
                    style: .compact
                )
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
