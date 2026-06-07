import SwiftUI

struct PopoverRoot: View {
    @EnvironmentObject var coord: AppCoordinator

    var body: some View {
        Group {
            if coord.pendingReckoningDay != nil {
                PendingReckoningView()
            } else {
                switch coord.today.state {
                case .noPlan:
                    PlannerView()
                case .locked:
                    TaskView()
                case .allDone:
                    AllDoneView()
                case .reckoningOpen:
                    AllDoneView() // The full-screen window is the primary surface; popover is a fallback hint.
                case .reckoned:
                    ReckonedView()
                case .autoMissed:
                    AutoMissedView()
                }
            }
        }
        .frame(width: 360)
        .padding(20)
    }
}

// MARK: - Reckoned/AutoMissed end-of-day surfaces

struct ReckonedView: View {
    @EnvironmentObject var coord: AppCoordinator
    @State private var showingNewSessionPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Day reckoned")
                .font(.title2.bold())
            Text("🔥 Streak: \(coord.streak)")
                .font(.headline)
            Text("New day, new chance. Plan tomorrow.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Start a bonus session") {
                showingNewSessionPicker = true
            }
            .buttonStyle(.link)
            .font(.caption)
            .popover(isPresented: $showingNewSessionPicker) {
                FutureTimePickerView(title: "Reckoning at", confirmLabel: "Start") { reckoningTime in
                    coord.startNewSession(reckoningTime: reckoningTime)
                    showingNewSessionPicker = false
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct AutoMissedView: View {
    @EnvironmentObject var coord: AppCoordinator
    @State private var showingNewSessionPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Day missed")
                .font(.title2.bold())
            Text("💀 Streak reset to 0.")
                .font(.headline)
                .foregroundStyle(.red)
            Text("New day, new chance. Plan tomorrow.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Button("Salvage today with a bonus session") {
                showingNewSessionPicker = true
            }
            .buttonStyle(.link)
            .font(.caption)
            .popover(isPresented: $showingNewSessionPicker) {
                FutureTimePickerView(title: "Reckoning at", confirmLabel: "Start") { reckoningTime in
                    coord.startNewSession(reckoningTime: reckoningTime)
                    showingNewSessionPicker = false
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
