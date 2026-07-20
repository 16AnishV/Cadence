import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var coord: AppCoordinator
    @State private var days: [Day] = []
    @State private var selected: Day?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("History")
                .font(.title2.bold())
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.top, 16)
                .padding(.bottom, 8)

            Divider()

            HSplitView {
                List(days, id: \.date, selection: $selected) { day in
                    HistoryRow(day: day)
                        .tag(day)
                        .contentShape(Rectangle())
                        .onTapGesture { selected = day }
                }
                .frame(minWidth: 220, idealWidth: 260)

                if let selected = selected {
                    DayDetailView(day: selected)
                        .environmentObject(coord)
                        .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    VStack {
                        Text("Select a day")
                            .foregroundStyle(.secondary)
                    }
                    .frame(minWidth: 260, maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            days = coord.history()
            if selected == nil { selected = days.first }
        }
    }
}

struct HistoryRow: View {
    @EnvironmentObject var coord: AppCoordinator
    let day: Day
    var body: some View {
        HStack {
            Text(day.date)
                .font(.system(.body, design: .monospaced))
            Spacer()
            statusBadge
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch day.state {
        case .reckoned:
            let p = coord.repo.progress(for: day.date)
            Text("✓ \(p.done)/\(p.total)").font(.caption).foregroundStyle(.green)
        case .autoMissed:
            Text("💀 missed").font(.caption).foregroundStyle(.red)
        case .locked, .allDone, .reckoningOpen:
            Text("⏳ open").font(.caption).foregroundStyle(.orange)
        case .noPlan:
            Text("— no plan").font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct DayDetailView: View {
    @EnvironmentObject var coord: AppCoordinator
    let day: Day
    @State private var tasks: [DailyTask] = []

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(day.date)
                .font(.title3.bold())

            HStack(spacing: 12) {
                summary
            }

            Divider()

            if tasks.isEmpty {
                Text("No tasks recorded.")
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(tasks, id: \.id) { t in
                            taskRow(t)
                        }
                    }
                }
            }
            Spacer()
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            tasks = coord.tasks(for: day.date)
        }
        .onChange(of: day.date) { _, newDate in
            tasks = coord.tasks(for: newDate)
        }
    }

    @ViewBuilder
    private var summary: some View {
        let done = tasks.filter { $0.status == .done }.count
        let total = tasks.count
        Text("\(done)/\(total) completed").font(.subheadline)
        Text(day.state.rawValue.replacingOccurrences(of: "_", with: " ").lowercased())
            .font(.caption)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func taskRow(_ t: DailyTask) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 8) {
                switch t.status {
                case .done:
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                case .skipped:
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                case .pending:
                    Image(systemName: "circle.dashed").foregroundStyle(.secondary)
                }
                Text(t.title)
                Spacer()
            }
            if t.status == .skipped, let reason = t.skipReason, !reason.isEmpty {
                Text("\"\(reason)\"")
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(.leading, 22)
            }
        }
    }
}
