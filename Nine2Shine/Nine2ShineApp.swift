import SwiftUI

@main
struct Nine2ShineApp: App {
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
        } label: {
            MenuBarIconView()
        }
        .menuBarExtraStyle(.window)
    }
}

// MARK: - MenuBar Icon Logic
struct MenuBarIconView: View {
    @AppStorage("entryTime") private var entryTimeStorage: Double = 0
    @AppStorage("safeExitTime") private var safeExitTimeStorage: Double = 0

    var body: some View {
        HStack {
            Image(systemName: timeStatus.icon)
                .foregroundColor(timeStatus.color)
            Text(timeStatus.timeText)
        }
    }

    private var timeStatus: (icon: String, timeText: String, color: Color) {
        guard entryTimeStorage > 0 else {
            return ("exclamationmark.triangle", "Set Entry Time", .orange)
        }

        let entryTime = Date(timeIntervalSince1970: entryTimeStorage)
        let workedSeconds = Date().timeIntervalSince(entryTime)
        let (hours, minutes) = secondsToHM(Int(workedSeconds))

        if workedSeconds < 8.5 * 3600 {
            return ("clock.badge.exclamationmark", "\(hours)h \(minutes)m", .orange)
        } else if workedSeconds < 9 * 3600 {
            return ("checkmark.circle.fill", "\(hours)h \(minutes)m", .yellow)
        } else {
            return ("checkmark.circle.fill", "\(hours)h \(minutes)m", .green)
        }
    }

    private func secondsToHM(_ totalSeconds: Int) -> (Int, Int) {
        (totalSeconds / 3600, (totalSeconds % 3600) / 60)
    }
}

// MARK: - Main Menu View
struct MenuBarView: View {
    @AppStorage("entryTime") private var entryTimeStorage: Double = 0
    @AppStorage("safeExitTime") private var safeExitTimeStorage: Double = 0
    @State private var showTimePicker = false
    @State private var showSettings = false
    @State private var selectedTime = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: handleEntryTime) {
                Label(entryTimeLabel, systemImage: "clock")
            }
            .buttonStyle(MacMenuBarButtonStyle())
            .popover(isPresented: $showTimePicker) {
                TimePickerView(selectedTime: $selectedTime, onSave: saveEntryTime)
            }

            if entryTimeStorage > 0 {
                Button(action: {}) {
                    Label("End Time: \(format(endTime))", systemImage: "flag.checkered")
                }.buttonStyle(MacMenuBarButtonStyle())

                Button(action: {}) {
                    Label("Safe Exit Time: \(format(safeExitTime))", systemImage: "checkmark.circle")
                }.buttonStyle(MacMenuBarButtonStyle())

                Button(action: {}) {
                    Label("Remaining: \(remainingTime)", systemImage: "hourglass.bottomhalf.filled")
                }.buttonStyle(MacMenuBarButtonStyle())
            }

            Divider()

            Button(action: { showSettings.toggle() }) {
                Label("Settings", systemImage: "gear")
            }
            .buttonStyle(MacMenuBarButtonStyle())
            .popover(isPresented: $showSettings) {
                SettingsPopoverView()
            }

            Divider()

            Button(action: { NSApplication.shared.terminate(nil) }) {
                Label("Quit", systemImage: "power")
            }
            .buttonStyle(MacMenuBarButtonStyle())
        }
        .padding(8)
    }

    private func handleEntryTime() {
        selectedTime = entryTimeStorage > 0 ? Date(timeIntervalSince1970: entryTimeStorage) : Date()
        showTimePicker.toggle()
    }

    private func saveEntryTime() {
        entryTimeStorage = selectedTime.timeIntervalSince1970
        safeExitTimeStorage = entryTimeStorage + (8.5 * 3600)
        showTimePicker = false
    }

    private var entryTimeLabel: String {
        entryTimeStorage > 0 ? "Entry: \(format(Date(timeIntervalSince1970: entryTimeStorage)))" : "Set Entry Time"
    }

    private var endTime: Date {
        Calendar.current.date(byAdding: .hour, value: 9, to: Date(timeIntervalSince1970: entryTimeStorage)) ?? Date()
    }

    private var safeExitTime: Date {
        Date(timeIntervalSince1970: safeExitTimeStorage)
    }

    private var remainingTime: String {
        let remaining = endTime.timeIntervalSince(Date())
        if remaining <= 0 {
            return "Time’s up!"
        }
        let (h, m) = secondsToHM(Int(remaining))
        return "\(h)h \(m)m"
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func secondsToHM(_ totalSeconds: Int) -> (Int, Int) {
        (totalSeconds / 3600, (totalSeconds % 3600) / 60)
    }
}

// MARK: - Settings View
struct SettingsView: View {
    @AppStorage("weekendDays") private var weekendDays: String = "Saturday,Sunday"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.title2).bold()
            Divider()

            Text("Weekend Days (comma separated):")
            TextField("e.g. Saturday,Sunday", text: $weekendDays)
                .textFieldStyle(RoundedBorderTextFieldStyle())

            Spacer()
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Time Picker
struct TimePickerView: View {
    @Binding var selectedTime: Date
    var onSave: () -> Void

    var body: some View {
        VStack {
            DatePicker("Select Entry Time", selection: $selectedTime, displayedComponents: .hourAndMinute)
                .datePickerStyle(GraphicalDatePickerStyle())
                .labelsHidden()
                .padding()
            Button("Save", action: onSave)
                .keyboardShortcut(.defaultAction)
                .padding()
        }
        .frame(width: 300)
    }
}

// MARK: - Button Style
struct MacMenuBarButtonStyle: ButtonStyle {
    @State private var isHovered: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(configuration.isPressed ? Color.primary.opacity(0.1) : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
            .cornerRadius(4)
            .contentShape(Rectangle())
            .onHover { isHovered = $0 }
    }
}

struct SettingsPopoverView: View {
    @AppStorage("weekendDays") private var weekendDays: String = "Saturday,Sunday"
    @AppStorage("officeStartHour") private var officeStartHour: Int = 9
    @AppStorage("officeDuration") private var officeDuration: Double = 9.0
    @AppStorage("safeExitDuration") private var safeExitDuration: Double = 8.5
    @AppStorage("lateEntryHour") private var lateEntryHour: Int = 10
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.title2).bold()
            Divider()

            Group {
                Text("Weekend Days (comma separated):")
                TextField("e.g. Saturday,Sunday", text: $weekendDays)
                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Text("Office Start Hour:")
                Stepper("\(officeStartHour):00", value: $officeStartHour, in: 0...23)

                Text("Office Duration (hrs):")
                Stepper("\(officeDuration, specifier: "%.1f") hrs", value: $officeDuration, in: 6...12, step: 0.5)

                Text("Safe Exit Time (hrs):")
                Stepper("\(safeExitDuration, specifier: "%.1f") hrs", value: $safeExitDuration, in: 6...12, step: 0.5)

                Text("Late Entry After (hour):")
                Stepper("\(lateEntryHour):00", value: $lateEntryHour, in: 0...23)
            }

            Divider()
            Text("About").font(.headline)
            Text("Nine2Shine helps you manage office entry and exit tracking from your macOS menu bar.").font(.footnote)

            Spacer()
        }
        .padding()
        .frame(width: 300)
    }
}
