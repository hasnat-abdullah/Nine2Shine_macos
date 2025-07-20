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

// MARK: - MenuBar Icon View

struct MenuBarIconView: View {
    @AppStorage("entryHour") private var entryHour: Int = -1
    @AppStorage("entryMinute") private var entryMinute: Int = -1
    @AppStorage("entryDate") private var entryDate: Double = -1

    @AppStorage("officeDuration") private var officeDuration: Double = 9.0
    @AppStorage("safeExitDuration") private var safeExitDuration: Double = 8.5

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: timeStatus.icon)
                .renderingMode(.template)
                .foregroundColor(timeStatus.color)
            Text(timeStatus.timeText)
                .foregroundColor(timeStatus.color)
        }
    }

    private var hasEntryTime: Bool {
        entryHour >= 0 && entryMinute >= 0 && entryDate > 0
    }

    private var entryTime: Date {
        Date(timeIntervalSince1970: entryDate)
    }

    private var timeStatus: (icon: String, timeText: String, color: Color) {
        guard hasEntryTime else {
            return ("exclamationmark.triangle", "Set Time", .orange)
        }
        

        let now = Date()
        let workedSeconds = now.timeIntervalSince(entryTime)

        if workedSeconds < 0 {
            return ("questionmark.circle", "Future Time", .gray)
        }

        let remainingSeconds = max(0, officeDuration * 3600 - workedSeconds)
        let (remainingHours, remainingMinutes) = secondsToHM(Int(remainingSeconds))

        if remainingSeconds <= 0 {
            return ("checkmark.circle.fill", "Time's Up!", .green)
        } else if workedSeconds < safeExitDuration * 3600 {
            return ("hourglass.bottomhalf.filled", "\(remainingHours)h \(remainingMinutes)m", .orange)
        } else {
            return ("checkmark.circle", "\(remainingHours)h \(remainingMinutes)m", .yellow)
        }
    }

    private func secondsToHM(_ totalSeconds: Int) -> (Int, Int) {
        (totalSeconds / 3600, (totalSeconds % 3600) / 60)
    }
}

// MARK: - MenuBar View

struct MenuBarView: View {
    @AppStorage("entryHour") private var entryHour: Int = -1
    @AppStorage("entryMinute") private var entryMinute: Int = -1
    @AppStorage("entryDate") private var entryDate: Double = -1

    @AppStorage("officeDuration") private var officeDuration: Double = 9.0
    @AppStorage("safeExitDuration") private var safeExitDuration: Double = 8.5

    @State private var selectedTime = Date()
    @State private var showTimePicker = false
    @State private var showSettings = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button(action: handleEntryTime) {
                Label(entryTimeLabel, systemImage: hasEntryTime ? "clock.fill" : "plus.circle")
            }
            .buttonStyle(MacMenuBarButtonStyle())
            .popover(isPresented: $showTimePicker) {
                TimePickerView(selectedTime: $selectedTime, onSave: saveEntryTime)
            }

            if hasEntryTime {
                Button(action: {}) {
                    Label("Safe Exit Time: \(format(safeExitTime))", systemImage: "checkmark.circle")
                }.buttonStyle(MacMenuBarButtonStyle())

                Button(action: {}) {
                    Label("End Time: \(format(endTime))", systemImage: "flag.checkered")
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
        .onAppear(perform: resetIfNotToday)
    }

    private var hasEntryTime: Bool {
        entryHour >= 0 && entryMinute >= 0 && entryDate > 0
    }

    private var entryTime: Date {
        Date(timeIntervalSince1970: entryDate)
    }

    private var endTime: Date {
        entryTime.addingTimeInterval(officeDuration * 3600)
    }

    private var safeExitTime: Date {
        entryTime.addingTimeInterval(safeExitDuration * 3600)
    }

    private func handleEntryTime() {
        selectedTime = hasEntryTime ? entryTime : Date()
        showTimePicker.toggle()
    }

    private func saveEntryTime() {
        let comps = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        entryHour = comps.hour ?? -1
        entryMinute = comps.minute ?? -1
        entryDate = selectedTime.timeIntervalSince1970
        showTimePicker = false
    }

    private var entryTimeLabel: String {
        hasEntryTime ? "Entry: \(format(entryTime))" : "Set Entry Time"
    }

    private func resetIfNotToday() {
        if hasEntryTime && !Calendar.current.isDateInToday(entryTime) {
            entryHour = -1
            entryMinute = -1
            entryDate = -1
        }
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Settings View

struct SettingsPopoverView: View {
    @AppStorage("officeDuration") private var officeDuration: Double = 9.0
    @AppStorage("safeExitDuration") private var safeExitDuration: Double = 8.5
    @AppStorage("lateEntryHour") private var lateEntryHour: Int = 10
//    @AppStorage("weekendDays") private var weekendDaysString: String = "Saturday,Sunday"

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.title2).bold()
            Divider()

            Group {
//                Text("Weekend Days (comma separated):")
//                TextField("e.g. Saturday,Sunday", text: $weekendDaysString)
//                    .textFieldStyle(RoundedBorderTextFieldStyle())

                Text("Office Duration (hrs):")
                Stepper("\(officeDuration, specifier: "%.1f") hrs", value: $officeDuration, in: 4...12, step: 0.5)

                Text("Safe Exit Time (hrs):")
                Stepper("\(safeExitDuration, specifier: "%.1f") hrs", value: $safeExitDuration, in: 4...12, step: 0.25)

                Text("Late Entry After (hour):")
                Stepper("\(lateEntryHour):00", value: $lateEntryHour, in: 0...23)
            }

            Divider()

            HStack(spacing: 4) {
                Text("About").font(.headline)

                Image(systemName: "info.circle") // No styling here!
                    .help("Dev: Hasnat Abdullah\nSupport: hasnat.abdullah@cefalo.com")
            }

            Text("© Nine2Shine v1.0.0").font(.footnote)
        }
        .padding()
        .frame(width: 300)
    }
}

// MARK: - Time Picker View

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

// MARK: - macOS Menu Button Style

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
