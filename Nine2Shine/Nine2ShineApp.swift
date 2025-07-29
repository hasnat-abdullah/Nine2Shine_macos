// MARK: - Reminder Types & Manager

import SwiftUI
import UserNotifications
import ServiceManagement

@main
struct Nine2ShineApp: App {
    @StateObject private var reminderManager = ReminderManager()
    @StateObject private var locationManager = LocationManager()
    @StateObject private var timeManager = CurrentTimeManager()
    
    @State private var currentTime = Date()
        
    let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()
    
    init() {
            registerAtLogin()
        }
    
    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(reminderManager)
                .environmentObject(timeManager)
        } label: {
            MenuBarIconView()
                .environmentObject(timeManager)
        }
        .menuBarExtraStyle(.window)
    }
    
    private func registerAtLogin() {
            do {
                try SMAppService.mainApp.register()
                print("✅ Nine2Shine registered to launch at login.")
            } catch {
                print("❌ Failed to register login item:", error)
            }
        }
}


class CurrentTimeManager: ObservableObject {
    @Published var now: Date = Date()

    private var timer: Timer?

    init() {
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { _ in
            self.now = Date()
        }
    }

    deinit {
        timer?.invalidate()
    }
}

enum ReminderType: String, Codable, CaseIterable, Identifiable {
    case atTime = "At Specific Date & Time"
    case afterInterval = "After Interval"
    case afterEntry = "After Entry"
    case beforeEnd = "Before End"

    var id: String { rawValue }
}

struct Reminder: Identifiable, Codable, Equatable {
    var id: UUID = UUID()
    var title: String
    var type: ReminderType
    var value: TimeInterval
    var date: Date?
    var repeatOnWeekdays: Bool = false
    var respectWorkHours: Bool = true
}

class ReminderManager: ObservableObject {
    @Published var reminders: [Reminder] = [] {
        didSet { saveReminders() }
    }

    init() {
        loadReminders()
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("[Notification] Error: \(error)")
            }
        }
    }

    func addOrUpdate(reminder: Reminder) {
        if let idx = reminders.firstIndex(where: { $0.id == reminder.id }) {
            reminders[idx] = reminder
        } else {
            reminders.append(reminder)
        }
        scheduleNotification(for: reminder)
    }

    func remove(id: UUID) {
        reminders.removeAll { $0.id == id }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id.uuidString])
    }

    private func saveReminders() {
        if let data = try? JSONEncoder().encode(reminders) {
            UserDefaults.standard.set(data, forKey: "reminders")
        }
    }

    private func loadReminders() {
        if let data = UserDefaults.standard.data(forKey: "reminders"),
           let decoded = try? JSONDecoder().decode([Reminder].self, from: data) {
            reminders = decoded
        }
    }

    private func getEntryTime() -> Date? {
        let date = UserDefaults.standard.double(forKey: "entryDate")
        return date > 0 ? Date(timeIntervalSince1970: date) : nil
    }

    private var officeDuration: Double {
        UserDefaults.standard.double(forKey: "officeDuration")
    }

    private func scheduleNotification(for reminder: Reminder) {
        let content = UNMutableNotificationContent()
        content.title = "Nine2Shine Reminder"
        content.body = reminder.title
        content.sound = .default

        var trigger: UNNotificationTrigger?

        switch reminder.type {
        case .atTime:
            guard let date = reminder.date else { return }
            var components = Calendar.current.dateComponents([.hour, .minute], from: date)
            if reminder.repeatOnWeekdays {
                components.weekday = Calendar.current.component(.weekday, from: date)
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            } else {
                components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            }

        case .afterInterval:
            let fireDate = Date().addingTimeInterval(reminder.value)
            if reminder.respectWorkHours, let entry = getEntryTime() {
                let end = entry.addingTimeInterval(officeDuration * 3600)
                guard fireDate <= end else { return }
            }
            let components = Calendar.current.dateComponents([.hour, .minute, .second], from: fireDate)
            trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        case .afterEntry:
            if let entry = getEntryTime() {
                let fireDate = entry.addingTimeInterval(reminder.value)
                let components = Calendar.current.dateComponents([.hour, .minute, .second], from: fireDate)
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            }

        case .beforeEnd:
            if let entry = getEntryTime() {
                let end = entry.addingTimeInterval(officeDuration * 3600)
                let fireDate = end.addingTimeInterval(-reminder.value)
                let components = Calendar.current.dateComponents([.hour, .minute, .second], from: fireDate)
                trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            }
        }

        guard let t = trigger else { return }
        let request = UNNotificationRequest(identifier: reminder.id.uuidString, content: content, trigger: t)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notification] Scheduling error: \(error)")
            }
        }
    }
    
    func scheduleAutoExitNotifications(entryTime: Date, safeExit: Double, end: Double) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: ["safeExitNotice", "endTimeNotice"]
        )

        let endTime = entryTime.addingTimeInterval(end * 3600)
        let safeExitTime = endTime.addingTimeInterval(-safeExit * 3600)

        scheduleNotification(title: "Safe Exit Reached ✅",
                             body: "You can safely leave now!",
                             id: "safeExitNotice",
                             fireDate: safeExitTime)

        scheduleNotification(title: "Work Time Over ⏰",
                             body: "You’ve completed your scheduled work hours.",
                             id: "endTimeNotice",
                             fireDate: endTime)
    }

    private func scheduleNotification(title: String, body: String, id: String, fireDate: Date) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)

        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                print("[Notification] Scheduling error for \(id): \(error)")
            }
        }
    }
}

// MARK: - Reminder Editor View

struct ReminderEditorView: View {
    var editingReminder: Reminder

    @EnvironmentObject var reminderManager: ReminderManager
    @Environment(\.dismiss) private var dismiss

    @State private var title: String = ""
    @State private var type: ReminderType = .atTime
    @State private var valueHours: Int = 0
    @State private var valueMinutes: Int = 0
    @State private var time: Date = Date()
    @State private var repeatOnWeekdays: Bool = false
    @State private var respectWorkHours: Bool = true

    var body: some View {
        VStack(spacing: 12) {
            Text(editingReminderExists ? "Edit Reminder" : "Add Reminder")
                .font(.headline)

            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)

            Picker("Type", selection: $type) {
                ForEach(ReminderType.allCases) { t in
                    Text(t.rawValue).tag(t)
                }
            }
            .pickerStyle(.menu)

            if type == .atTime {
                DatePicker("Date & Time", selection: $time)
                    .labelsHidden()
                Toggle("Repeat every workday", isOn: $repeatOnWeekdays)
            } else {
                Stepper(durationString(hours: valueHours, minutes: valueMinutes)) {
                    incrementDuration(&valueHours, &valueMinutes)
                } onDecrement: {
                    decrementDuration(&valueHours, &valueMinutes)
                }

                Toggle("Respect work hours", isOn: $respectWorkHours)
            }

            Divider()

            HStack {
                if editingReminderExists {
                    Button(action: {
                        withAnimation {
                            reminderManager.remove(id: editingReminder.id)
                        }
                        dismiss()
                    }) {
                        Label("Delete", systemImage: "trash")
                    }
                    .foregroundColor(.red)
                }

                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                Button("Save") {
                    let intervalValue = Double(valueHours * 3600 + valueMinutes * 60)
                    let newReminder = Reminder(
                        id: editingReminder.id,
                        title: title,
                        type: type,
                        value: type == .atTime ? 0 : intervalValue,
                        date: type == .atTime ? time : nil,
                        repeatOnWeekdays: repeatOnWeekdays,
                        respectWorkHours: respectWorkHours
                    )
                    withAnimation {
                        reminderManager.addOrUpdate(reminder: newReminder)
                    }
                    dismiss()
                }
                .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            title = editingReminder.title
            type = editingReminder.type
            time = editingReminder.date ?? Date()
            repeatOnWeekdays = editingReminder.repeatOnWeekdays
            respectWorkHours = editingReminder.respectWorkHours

            let interval = editingReminder.value
            valueHours = Int(interval) / 3600
            valueMinutes = (Int(interval) % 3600) / 60
        }
    }

    private var editingReminderExists: Bool {
        reminderManager.reminders.contains(where: { $0.id == editingReminder.id })
    }

    private func durationString(hours: Int, minutes: Int) -> String {
        String(format: "%02d:%02d", hours, minutes)
    }

    func incrementDuration(_ hours: inout Int, _ minutes: inout Int) {
        if minutes < 55 {
            minutes += 5
        } else {
            hours += 1
            minutes = 0
        }
        
        if hours > 12 {
            hours = 12
            minutes = 0
        }
    }

    func decrementDuration(_ hours: inout Int, _ minutes: inout Int) {
        if minutes >= 5 {
            minutes -= 5
        } else if hours > 0 {
            hours -= 1
            minutes = 55
        } else {
            // Already at 0h 0m, do nothing
            minutes = 0
            hours = 0
        }
    }
}

// MARK: - Display Mode Enum

enum DisplayMode: String, CaseIterable, Identifiable {
    case remaining = "Remaining Time"
    case safeExit = "Safe Exit"
    case end = "End Time"

    var id: String { rawValue }
}

// MARK: - MenuBar Icon View

struct MenuBarIconView: View {
    @EnvironmentObject var timeManager: CurrentTimeManager
    @AppStorage("entryHour") private var entryHour: Int = -1
    @AppStorage("entryMinute") private var entryMinute: Int = -1
    @AppStorage("entryDate") private var entryDate: Double = -1

    @AppStorage("officeDuration") private var officeDuration: Double = 9.0
    @AppStorage("safeExitOffset") private var safeExitOffset: Double = 8.5
    @AppStorage("displayMode") private var displayMode: String = DisplayMode.remaining.rawValue

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
        let now = timeManager.now
        guard hasEntryTime else {
            return ("exclamationmark.triangle", "Set Time", .orange)
        }

        let workedSeconds = now.timeIntervalSince(entryTime)

        if workedSeconds < 0 {
            return ("questionmark.circle", "Future Time", .gray)
        }

        let remainingSeconds = max(0, officeDuration * 3600 - workedSeconds)
        let safeExitSeconds = max(0, safeExitOffset * 3600 - workedSeconds)
        let (rh, rm) = secondsToHM(Int(remainingSeconds))
        let (_, _) = secondsToHM(Int(safeExitSeconds))

        switch DisplayMode(rawValue: displayMode) ?? .remaining {
        case .remaining:
            return remainingSeconds <= 0 ?
                ("checkmark.circle.fill", "Time's Up!", .green) :
                (workedSeconds < safeExitOffset * 3600 ?
                    ("hourglass.bottomhalf.filled", "\(rh)h \(rm)m", .orange) :
                    ("checkmark.circle", "\(rh)h \(rm)m", .yellow))
        case .safeExit:
            let safeExitTime = entryTime.addingTimeInterval(safeExitOffset * 3600)
            return ("arrow.right.circle", format(safeExitTime), .blue)
        case .end:
            let endTime = entryTime.addingTimeInterval(officeDuration * 3600)
            return ("flag.checkered", format(endTime), .purple)
        }
    }

    private func secondsToHM(_ totalSeconds: Int) -> (Int, Int) {
        (totalSeconds / 3600, (totalSeconds % 3600) / 60)
    }

    private func format(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - MenuBar View


struct MenuBarView: View {
    @AppStorage("entryHour") private var entryHour: Int = -1
    @AppStorage("entryMinute") private var entryMinute: Int = -1
    @AppStorage("entryDate") private var entryDate: Double = -1
    @AppStorage("officeDuration") private var officeDuration: Double = 9.0
    @AppStorage("safeExitOffset") private var safeExitOffset: Double = 8.5
    @AppStorage("displayMode") private var displayMode: String = DisplayMode.remaining.rawValue

    @State private var selectedTime = Date()
    @State private var showTimePicker = false
    @State private var showSettings = false
    @State private var editingReminder: Reminder?
    
    @EnvironmentObject var reminderManager: ReminderManager

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {

            // Entry Time
            MenuItemRow(
                title: entryTimeLabel,
                systemImage: hasEntryTime ? "clock.fill" : "plus.circle",
                action: handleEntryTime
            )
            .popover(isPresented: $showTimePicker) {
                TimePickerView(selectedTime: $selectedTime, onSave: saveEntryTime)
            }

            // Safe Exit / End Time / Remaining time
            if hasEntryTime {
                let now = Date()
                let workedSeconds = now.timeIntervalSince(entryTime)
                let remainingSeconds = max(0, officeDuration * 3600 - workedSeconds)
                let (rh, rm) = secondsToHM(Int(remainingSeconds))
                let safeExitStr = format(safeExitTime)
                let endTimeStr = format(endTime)
                let remainingStr = remainingSeconds <= 0 ? "Time's Up!" : "\(rh)h \(rm)m"

                if displayMode != DisplayMode.remaining.rawValue {
                    MenuInfoRow(title: "Remaining: \(remainingStr)", systemImage: "hourglass.bottomhalf.filled")
                }
                if displayMode != DisplayMode.safeExit.rawValue {
                    MenuInfoRow(title: "Safe Exit: \(safeExitStr)", systemImage: "checkmark.circle")
                }
                if displayMode != DisplayMode.end.rawValue {
                    MenuInfoRow(title: "End Time: \(endTimeStr)", systemImage: "flag.checkered")
                }
            }

            Divider()

            // Reminders Header
            HStack(spacing: 6) {
                Text("Reminders")
                    .font(.subheadline)
                
                Button(action: {
                    editingReminder = Reminder(title: "", type: .atTime, value: 0)
                }) {
                    Image(systemName: "plus.circle")
                        .font(.subheadline)
                }
                .buttonStyle(.plain)
                .popover(item: $editingReminder) { reminder in
                    ReminderEditorView(editingReminder: reminder)
                        .environmentObject(reminderManager)
                }
                .focusable(false)
                Spacer()
            }
            .padding(.top, 4)

            // Reminders List
            ForEach(reminderManager.reminders) { reminder in
                ReminderButton(reminder: reminder)
            }

            Divider()

            // Settings
            MenuItemRow(title: "Settings", systemImage: "gear") {
                showSettings.toggle()
            }
            .popover(isPresented: $showSettings) {
                SettingsPopoverView()
            }

            Divider()

            // Quit
            MenuItemRow(title: "Quit", systemImage: "power") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(8)
        .onAppear(perform: resetIfNotToday)
        .animation(.default, value: reminderManager.reminders)
    }

    // MARK: - Time Helpers

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
        endTime.addingTimeInterval(-safeExitOffset * 3600)
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

        // 🔔 Schedule Safe Exit and End Time Notifications
        let entry = Date(timeIntervalSince1970: entryDate)
        reminderManager.scheduleAutoExitNotifications(
            entryTime: entry,
            safeExit: safeExitOffset,
            end: officeDuration
        )
    }

    private var entryTimeLabel: String {
        hasEntryTime ? "Entry: \(format(entryTime))" : "Set Entry Time"
    }

    private func resetIfNotToday() {
        if hasEntryTime && !Calendar.current.isDateInToday(entryTime) {
            DispatchQueue.main.async {
                entryHour = -1
                entryMinute = -1
                entryDate = -1
                
                // ✅ Clear Safe Exit and End Time notifications when date changes
                UNUserNotificationCenter.current().removePendingNotificationRequests(
                    withIdentifiers: ["safeExitNotice", "endTimeNotice"]
                )
            }
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


struct ReminderButton: View {
    @EnvironmentObject var reminderManager: ReminderManager
    let reminder: Reminder

    @State private var showEditor = false
    @State private var isHovered = false

    var body: some View {
        Button(action: {
            showEditor = true
        }) {
            HStack {
                // Left icon and title
                Image(systemName: "bell")
                    .frame(width: 18)
                Text(reminder.title)

                Spacer()

                // Right side: icon + time in muted style
                if let icon = iconForType(reminder),
                   let detail = formattedDetail(for: reminder) {
                    HStack(spacing: 4) {
                        Image(systemName: icon)
                        Text(detail)
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 8)
            .background(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
            .cornerRadius(6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .popover(isPresented: $showEditor) {
            ReminderEditorView(editingReminder: reminder)
                .environmentObject(reminderManager)
        }
        .focusable(false)
    }

    private func iconForType(_ reminder: Reminder) -> String? {
        switch reminder.type {
        case .atTime:
            return reminder.repeatOnWeekdays ? "clock.arrow.trianglehead.2.counterclockwise.rotate.90" : "calendar.circle"
        case .afterInterval:
            return reminder.respectWorkHours ? "repeat.circle" : "repeat.circle"
        case .afterEntry:
            return "arrow.forward.circle"
        case .beforeEnd:
            return "arrow.backward.circle"
        }
    }

    private func formattedDetail(for reminder: Reminder) -> String? {
        switch reminder.type {
        case .atTime:
            guard let date = reminder.date else { return nil }
            let formatter = DateFormatter()
            if reminder.repeatOnWeekdays {
                formatter.dateFormat = "h:mm a"  // only time
            } else {
                formatter.dateFormat = "MMM d, h:mm a"  // full date and time
            }
            return formatter.string(from: date)
        case .afterInterval, .afterEntry, .beforeEnd:
            let hours = Int(reminder.value) / 3600
            let minutes = (Int(reminder.value) % 3600) / 60
            return String(format: "%02dh %02dm", hours, minutes)
        }
    }
}
// MARK: - Settings View

struct SettingsPopoverView: View {
    @State private var officeHours = 9
    @State private var officeMinutes = 0

    @State private var safeExitOffsetHours = 0
    @State private var safeExitOffsetMinutes = 30
    

    @AppStorage("officeDuration") private var officeDuration: Double = 9.0
    @AppStorage("safeExitOffset") private var safeExitOffset: Double = 0.5 // 30 minutes before end
    
    @AppStorage("displayMode") private var displayMode: String = DisplayMode.remaining.rawValue
    
    @AppStorage("useLocationForTime") private var useLocationForTime: Bool = false
    
    @AppStorage("workdays") private var workdaysData: Data = try! JSONEncoder().encode([2, 3, 4, 5, 6]) // Mon–Fri
    @State private var selectedWorkdays: Set<Int> = []
    
    @State private var showAboutPopover = false
    
    func durationString(hours: Int, minutes: Int) -> String {
        String(format: "%02d:%02d", hours, minutes)
    }
    
    func incrementDuration(_ hours: inout Int, _ minutes: inout Int) {
        if minutes < 55 {
            minutes += 5
        } else {
            hours += 1
            minutes = 0
        }
        
        if hours > 12 {
            hours = 12
            minutes = 0
        }
    }

    func decrementDuration(_ hours: inout Int, _ minutes: inout Int) {
        if minutes >= 5 {
            minutes -= 5
        } else if hours > 0 {
            hours -= 1
            minutes = 55
        } else {
            // Already at 0h 0m, do nothing
            minutes = 0
            hours = 0
        }
    }

    func syncOfficeDuration() {
        officeDuration = Double(officeHours) + Double(officeMinutes) / 60.0
    }

    func syncSafeExitOffset() {
        safeExitOffset = Double(safeExitOffsetHours) + Double(safeExitOffsetMinutes) / 60.0
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Settings").font(.title2).bold()
            Divider()

            Group {
                WeekdayPickerView(selected: $selectedWorkdays)
                Text("Office Duration:")
                Stepper(durationString(hours: officeHours, minutes: officeMinutes)) {
                    incrementDuration(&officeHours, &officeMinutes)
                } onDecrement: {
                    decrementDuration(&officeHours, &officeMinutes)
                }
                .onChange(of: officeHours) { syncOfficeDuration() }
                .onChange(of: officeMinutes) { syncOfficeDuration() }
                .onChange(of: safeExitOffsetHours) { syncSafeExitOffset() }
                .onChange(of: safeExitOffsetMinutes) { syncSafeExitOffset() }
                
                Text("Safe Exit Offset (before End):")
                Stepper(durationString(hours: safeExitOffsetHours, minutes: safeExitOffsetMinutes)) {
                    incrementDuration(&safeExitOffsetHours, &safeExitOffsetMinutes)
                } onDecrement: {
                    decrementDuration(&safeExitOffsetHours, &safeExitOffsetMinutes)
                }
                .onChange(of: safeExitOffsetHours) { syncSafeExitOffset() }
                .onChange(of: safeExitOffsetMinutes) { syncSafeExitOffset() }
                
                Divider()
                Toggle("Auto Set Entry by Location", isOn: $useLocationForTime)
                Divider()

                Picker("Show in Menu Bar", selection: $displayMode) {
                    ForEach(DisplayMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.menu)
            }

            Divider()

            HStack(spacing: 4) {
                Text("© Nine2Shine v1.0.0")
                    .font(.footnote)

                Image(systemName: "info.circle")
                    .onTapGesture {
                        showAboutPopover.toggle()
                    }
                    .popover(isPresented: $showAboutPopover) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Developer:")
                                .font(.headline)
                            Text("Hasnat Abdullah")

                            Divider()

                            Text("Support:")
                                .font(.headline)
                            Text("hasnat.abdullah@cefalo.com")
                                .textSelection(.enabled)
                        }
                        .padding()
                        .frame(width: 250)
                    }
                    .foregroundColor(.secondary) // Optional: gives a subtle look like SF Symbols in macOS
            }
        }
        .padding()
        .frame(width: 300)
        .onAppear {
            officeHours = Int(officeDuration)
            officeMinutes = Int((officeDuration - Double(officeHours)) * 60)
            safeExitOffsetHours = Int(safeExitOffset)
            safeExitOffsetMinutes = Int((safeExitOffset - Double(safeExitOffsetHours)) * 60)
            
            if let decoded = try? JSONDecoder().decode([Int].self, from: workdaysData) {
                    selectedWorkdays = Set(decoded)
                }
        }
        .onChange(of: selectedWorkdays) {
            if let encoded = try? JSONEncoder().encode(Array(selectedWorkdays.sorted())) {
                workdaysData = encoded
            }
        }
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

struct WeekdayPickerView: View {
    @Binding var selected: Set<Int>  // 1 = Sunday, 7 = Saturday

    private let weekdaySymbols = Calendar.current.weekdaySymbols

    var body: some View {
        Menu {
            ForEach(1...7, id: \.self) { day in
                let name = weekdaySymbols[day - 1]
                Button(action: {
                    if selected.contains(day) {
                        selected.remove(day)
                    } else {
                        selected.insert(day)
                    }
                }) {
                    Label(name, systemImage: selected.contains(day) ? "checkmark" : "")
                }
            }
        } label: {
            Label("Workdays", systemImage: "calendar.badge.clock")
        }
    }
}
