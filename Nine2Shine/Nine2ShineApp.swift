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
    @AppStorage("safeExitDuration") private var safeExitDuration: Double = 8.5
    @AppStorage("officeDuration") private var officeDuration: Double = 9.0

    var body: some View {
        HStack(spacing: 4) {
                    Image(systemName: timeStatus.icon)
                        .renderingMode(.template) // ✅ Force template rendering
                        .foregroundColor(timeStatus.color)
                    Text(timeStatus.timeText)
                        .foregroundColor(timeStatus.color) // Optional: match color
                }
    }

    private var hasEntryTime: Bool {
        entryHour >= 0 && entryMinute >= 0
    }

    private var entryTime: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = entryHour
        components.minute = entryMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    private var timeStatus: (icon: String, timeText: String, color: Color) {
        guard hasEntryTime else {
            return ("exclamationmark.triangle", "Set Time", .orange)
        }

        let now = Date()
        let entry = entryTime
        let workedSeconds = now.timeIntervalSince(entry)
        
        if workedSeconds < 0 {
            // If user selects a future time accidentally
            return ("questionmark.circle", "Future Time", .gray)
        }

        let remainingSeconds = max(0, officeDuration * 3600 - workedSeconds)
        let (workedHours, workedMinutes) = secondsToHM(Int(workedSeconds))
        let (remainingHours, remainingMinutes) = secondsToHM(Int(remainingSeconds))

        if remainingSeconds <= 0 {
            return ("checkmark.circle.fill", "Time's Up!", .green)
        } else if workedSeconds < safeExitDuration * 3600 {
            return ("hourglass.bottomhalf.filled", "\(remainingHours)h \(remainingMinutes)m", .orange)
        } else if workedSeconds < officeDuration * 3600 {
            return ("checkmark.circle.fill", "\(remainingHours)h \(remainingMinutes)m", .yellow)
        } else {
            return ("checkmark.circle.fill", "Time's Up!", .green)
        }
    }

    private func secondsToHM(_ totalSeconds: Int) -> (Int, Int) {
        (totalSeconds / 3600, (totalSeconds % 3600) / 60)
    }
}

// MARK: - MenuBar Main View
struct MenuBarView: View {
    @AppStorage("entryHour") private var entryHour: Int = -1
    @AppStorage("entryMinute") private var entryMinute: Int = -1
    @AppStorage("officeDuration") private var officeDuration: Double = 9.0
    @AppStorage("safeExitDuration") private var safeExitDuration: Double = 8.5
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

            if hasEntryTime {
                Button(action: {}) {
                    Label("End Time: \(format(endTime))", systemImage: "flag.checkered")
                }.buttonStyle(MacMenuBarButtonStyle())

                Button(action: {}) {
                    Label("Safe Exit Time: \(format(safeExitTime))", systemImage: "checkmark.circle")
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

    // MARK: Entry Time Logic
    private var hasEntryTime: Bool {
        entryHour >= 0 && entryMinute >= 0
    }

    private var entryTime: Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = entryHour
        components.minute = entryMinute
        return Calendar.current.date(from: components) ?? Date()
    }

    private func handleEntryTime() {
        selectedTime = hasEntryTime ? entryTime : Date()
        showTimePicker.toggle()
    }

    private func saveEntryTime() {
        let components = Calendar.current.dateComponents([.hour, .minute], from: selectedTime)
        entryHour = components.hour ?? -1
        entryMinute = components.minute ?? -1
        showTimePicker = false
    }

    private var entryTimeLabel: String {
        hasEntryTime ? "Entry: \(format(entryTime))" : "Set Entry Time"
    }

    private var endTime: Date {
        entryTime.addingTimeInterval(officeDuration * 3600)
    }

    private var safeExitTime: Date {
        entryTime.addingTimeInterval(safeExitDuration * 3600)
    }


    private func resetIfNotToday() {
        guard hasEntryTime else { return }
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = entryHour
        components.minute = entryMinute

        if let fullEntry = Calendar.current.date(from: components),
           !Calendar.current.isDateInToday(fullEntry) {
            entryHour = -1
            entryMinute = -1
        }
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
struct SettingsPopoverView: View {
    @AppStorage("weekendDays") private var weekendDays: String = "Saturday,Sunday"
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

                Text("Office Duration (hrs):")
                Stepper("\(officeDuration, specifier: "%.1f") hrs", value: $officeDuration, in: 4...12, step: 0.5)

                Text("Safe Exit Time (hrs):")
                Stepper("\(safeExitDuration, specifier: "%.1f") hrs", value: $safeExitDuration, in: 4...12, step: 0.25)

                Text("Late Entry After (hour):")
                Stepper("\(lateEntryHour):00", value: $lateEntryHour, in: 0...23)
            }

            Divider()
            Text("About").font(.headline)
            Text("© 2025 Hasnat Abdullah.")
            Text("Nine2Shine v1.0.0 • Support: hasnat.abdullah@cefalo.com")
                 
                .font(.footnote)

            Spacer()
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
