import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var coord: AppCoordinator
    @State private var hour: Int = 18
    @State private var minute: Int = 0
    @State private var launchAtLogin: Bool = true
    @State private var showResetConfirm = false

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 8) {
                Text("Default reckoning time").font(.headline)
                HStack(spacing: 6) {
                    Picker("", selection: $hour) {
                        ForEach(0..<24, id: \.self) { h in
                            Text(String(format: "%02d", h)).tag(h)
                        }
                    }
                    .frame(width: 70)
                    Text(":")
                    Picker("", selection: $minute) {
                        ForEach(0..<60, id: \.self) { m in
                            Text(String(format: "%02d", m)).tag(m)
                        }
                    }
                    .frame(width: 70)
                    Spacer()
                    Button("Apply") {
                        let hhmm = String(format: "%02d:%02d", hour, minute)
                        coord.setReckoningTime(hhmm)
                    }
                }
                Text("Applies to today (if not yet reckoned) and all future days.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        toggleLaunchAtLogin(newValue)
                    }
                Text("Required for reliable reckoning. Cadence has no background daemon — if it isn't running, timers won't fire.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Button(role: .destructive) {
                    showResetConfirm = true
                } label: {
                    Text("Reset streak to 0")
                }
                .confirmationDialog(
                    "Reset streak?",
                    isPresented: $showResetConfirm,
                    titleVisibility: .visible
                ) {
                    Button("Reset", role: .destructive) {
                        coord.repo.setCurrentStreak(0)
                        coord.refreshState()
                    }
                    Button("Cancel", role: .cancel) {}
                } message: {
                    Text("Sets your current streak to 0. History is unchanged.")
                }
            }

        }
        .padding(20)
        .frame(width: 480, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            let hhmm = coord.repo.reckoningTimeDefault
            let parts = hhmm.split(separator: ":")
            if parts.count == 2 {
                hour = Int(parts[0]) ?? 18
                minute = Int(parts[1]) ?? 0
            }
            launchAtLogin = (coord.repo.getState("launch_at_login") ?? "true") == "true"
        }
    }

    private func toggleLaunchAtLogin(_ enable: Bool) {
        coord.repo.setState("launch_at_login", enable ? "true" : "false")
        do {
            if enable {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            NSLog("Cadence launch-at-login error: \(error)")
        }
    }
}
