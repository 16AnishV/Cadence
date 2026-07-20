import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var coord: AppCoordinator
    @State private var time: Date = Self.defaultTime()
    @State private var launchAtLogin: Bool = true

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Settings")
                .font(.title2.bold())

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text("Default reckoning time")
                    DatePicker("", selection: $time, displayedComponents: .hourAndMinute)
                        .labelsHidden()
                    Spacer()
                    Button("Apply") {
                        coord.setReckoningTime(Self.hhmm(from: time))
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
        }
        .padding(20)
        .frame(width: 480, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear {
            time = Self.parse(hhmm: coord.repo.reckoningTimeDefault) ?? Self.defaultTime()
            launchAtLogin = (coord.repo.getState("launch_at_login") ?? "true") == "true"
        }
    }

    private static func hhmm(from date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }

    private static func parse(hhmm: String) -> Date? {
        let parts = hhmm.split(separator: ":")
        guard parts.count == 2, let h = Int(parts[0]), let m = Int(parts[1]) else { return nil }
        return Calendar.current.date(bySettingHour: h, minute: m, second: 0, of: Date())
    }

    private static func defaultTime() -> Date {
        Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: Date()) ?? Date()
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
