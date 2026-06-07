import SwiftUI

/// Picks a HH:MM time strictly between "now" and midnight, at per-minute
/// granularity, via the native graphical DatePicker.
///
/// If time passes between the picker rendering and the user clicking Confirm and
/// the resulting time is in the past, the picker still emits the chosen value —
/// callers are expected to detect "in the past" and trigger reckoning immediately.
struct FutureTimePickerView: View {
    let title: String
    let confirmLabel: String
    let onPick: (String) -> Void

    /// Recomputed when the view appears so reopening reflects the latest "now."
    @State private var now: Date = Date()
    @State private var selection: Date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            DatePicker(
                "",
                selection: $selection,
                in: pickerRange,
                displayedComponents: .hourAndMinute
            )
            .labelsHidden()
            Text("Between now and midnight.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button(confirmLabel) {
                    onPick(Self.hhmm(from: selection))
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isSelectionInRange)
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            let n = Date()
            now = n
            // Default selection: ~30 min from now, capped before midnight.
            let cal = Calendar.current
            let endOfDay = Self.endOfDay(for: n, calendar: cal)
            let target = n.addingTimeInterval(30 * 60)
            selection = min(target, endOfDay.addingTimeInterval(-60))
        }
    }

    private var pickerRange: ClosedRange<Date> {
        let endOfDay = Self.endOfDay(for: now, calendar: .current)
        let upper = max(now, endOfDay)
        return now...upper
    }

    private var isSelectionInRange: Bool {
        let range = pickerRange
        return selection >= range.lowerBound && selection <= range.upperBound
    }

    private static func hhmm(from date: Date) -> String {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: date)
        return String(format: "%02d:%02d", comps.hour ?? 0, comps.minute ?? 0)
    }

    /// Last instant of the calendar day containing `date` — i.e., 23:59:59.
    private static func endOfDay(for date: Date, calendar: Calendar) -> Date {
        let startOfDay = calendar.startOfDay(for: date)
        return calendar.date(byAdding: DateComponents(day: 1, second: -1), to: startOfDay) ?? date
    }
}
