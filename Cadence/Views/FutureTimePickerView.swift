import SwiftUI

/// Picks a HH:MM time strictly between "now" and midnight, at per-minute
/// granularity. Hours before the current hour are hidden; when the selected hour
/// equals the current hour, only minute choices after the current minute are shown.
///
/// If time passes between the picker rendering and the user clicking Confirm and
/// the resulting time is in the past, the picker still emits the chosen value —
/// callers are expected to detect "in the past" and trigger reckoning immediately.
struct FutureTimePickerView: View {
    let title: String
    let confirmLabel: String
    let onPick: (String) -> Void

    /// Recomputed every time the view appears, so reopening the picker reflects
    /// the latest "now."
    @State private var nowHour: Int = Calendar.current.component(.hour, from: Date())
    @State private var nowMinute: Int = Calendar.current.component(.minute, from: Date())
    @State private var hour: Int = 0
    @State private var minute: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            HStack(spacing: 6) {
                Picker("", selection: $hour) {
                    ForEach(availableHours(), id: \.self) { h in
                        Text(String(format: "%02d", h)).tag(h)
                    }
                }
                .frame(width: 70)
                .onChange(of: hour) { _, newHour in
                    let valid = availableMinutes(forHour: newHour)
                    if !valid.contains(minute) {
                        minute = valid.first ?? 0
                    }
                }
                Text(":")
                Picker("", selection: $minute) {
                    ForEach(availableMinutes(forHour: hour), id: \.self) { m in
                        Text(String(format: "%02d", m)).tag(m)
                    }
                }
                .frame(width: 70)
            }
            Text("Between now and midnight.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(confirmLabel) {
                    let hhmm = String(format: "%02d:%02d", hour, minute)
                    onPick(hhmm)
                }
                .buttonStyle(.borderedProminent)
                .disabled(availableHours().isEmpty)
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            let now = Date()
            nowHour = Calendar.current.component(.hour, from: now)
            nowMinute = Calendar.current.component(.minute, from: now)
            // Default selection: ~30 min from now, capped before midnight. No
            // rounding — the picker is per-minute, so any value is valid.
            let target = now.addingTimeInterval(30 * 60)
            hour = min(Calendar.current.component(.hour, from: target), 23)
            minute = Calendar.current.component(.minute, from: target)
            // Clamp to valid window. If we landed in an hour with no remaining
            // minutes, bump forward.
            let validHours = availableHours()
            if let firstHour = validHours.first {
                if !validHours.contains(hour) {
                    hour = firstHour
                }
                let validMins = availableMinutes(forHour: hour)
                if !validMins.contains(minute) {
                    minute = validMins.first ?? 0
                }
            }
        }
    }

    /// All hours from current hour through 23 — but exclude the current hour if
    /// no remaining minutes fit before the next hour boundary.
    private func availableHours() -> [Int] {
        var hours = Array(nowHour...23)
        if let first = hours.first, availableMinutes(forHour: first).isEmpty {
            hours.removeFirst()
        }
        return hours
    }

    /// Per-minute choices (00–59) filtered so the resulting time is strictly
    /// after `now`.
    private func availableMinutes(forHour h: Int) -> [Int] {
        if h > nowHour {
            return Array(0..<60)
        }
        if h == nowHour {
            return Array((nowMinute + 1)..<60)
        }
        return []
    }
}
