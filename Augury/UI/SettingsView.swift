import SwiftUI

/// Personal ritual controls. Preferences are local to the device; reminders
/// are local notifications and request system permission only when enabled.
struct SettingsView: View {
    @EnvironmentObject private var purchase: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @AppStorage("preferredDeck") private var preferredDeckRaw = ReadingDeckPreference.fullDeck.rawValue
    @AppStorage("ritualRemindersEnabled") private var remindersEnabled = false
    @AppStorage("ritualReminderFrequency") private var frequencyRaw = RitualReminderFrequency.daily.rawValue
    @AppStorage("ritualReminderMinutes") private var reminderMinutes = 20 * 60
    @AppStorage("ritualReminderWeekday") private var reminderWeekday = 1

    @State private var authorization: RitualReminderAuthorization = .notDetermined
    @State private var showingPaywall = false
    @State private var reminderError = false

    private var preferredDeck: Binding<ReadingDeckPreference> {
        Binding(
            get: { ReadingDeckPreference(rawValue: preferredDeckRaw) ?? .fullDeck },
            set: { preferredDeckRaw = $0.rawValue }
        )
    }

    private var frequency: Binding<RitualReminderFrequency> {
        Binding(
            get: { RitualReminderFrequency(rawValue: frequencyRaw) ?? .daily },
            set: { frequencyRaw = $0.rawValue }
        )
    }

    private var reminderTime: Binding<Date> {
        Binding(
            get: {
                Calendar.current.date(bySettingHour: reminderMinutes / 60,
                                         minute: reminderMinutes % 60,
                                         second: 0,
                                         of: Date()) ?? Date()
            },
            set: { date in
                let parts = Calendar.current.dateComponents([.hour, .minute], from: date)
                reminderMinutes = (parts.hour ?? 20) * 60 + (parts.minute ?? 0)
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("New readings") {
                    if purchase.entitlement.isFull {
                        Picker("Deck", selection: preferredDeck) {
                            ForEach(ReadingDeckPreference.allCases, id: \.self) { option in
                                Text(option.title).tag(option)
                            }
                        }
                    } else {
                        lockedDeckRow
                    }
                    Text("This changes only future deals. Saved readings never change.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }

                Section("Ritual reminder") {
                    Toggle("Ritual reminder", isOn: $remindersEnabled)

                    if remindersEnabled {
                        Picker("Frequency", selection: frequency) {
                            ForEach(RitualReminderFrequency.allCases, id: \.self) { option in
                                Text(option.title).tag(option)
                            }
                        }
                        DatePicker("Ritual time", selection: reminderTime, displayedComponents: .hourAndMinute)

                        if frequency.wrappedValue == .weekly {
                            Picker("Day", selection: $reminderWeekday) {
                                ForEach(1...7, id: \.self) { weekday in
                                    Text(Self.weekdayName(weekday)).tag(weekday)
                                }
                            }
                        }
                    }
                    Text("A local reminder opens Augury; it never draws a card or includes journal details.")
                        .font(.footnote)
                        .foregroundStyle(Color.secondary)
                }

                if remindersEnabled && authorization == .denied {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notifications are turned off for Augury.")
                            Link("Open Notification Settings", destination: URL(string: UIApplication.openSettingsURLString)!)
                        }
                    }
                }

                if reminderError {
                    Section {
                        Text("The reminder could not be scheduled. Try again in a moment.")
                            .foregroundStyle(.red)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.black)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(ReadingTable.uprightInk)
                }
            }
        }
        .preferredColorScheme(.dark)
        .task {
            authorization = await RitualReminderScheduler.authorization()
            if remindersEnabled, authorization == .granted { await scheduleReminder() }
        }
        .onChange(of: remindersEnabled) { _, enabled in
            Task { await setRemindersEnabled(enabled) }
        }
        .onChange(of: frequencyRaw) { _, _ in rescheduleIfNeeded() }
        .onChange(of: reminderMinutes) { _, _ in rescheduleIfNeeded() }
        .onChange(of: reminderWeekday) { _, _ in rescheduleIfNeeded() }
        .fullScreenCover(isPresented: $showingPaywall) {
            Paywall(purchase: purchase) { showingPaywall = false }
        }
    }

    private func setRemindersEnabled(_ enabled: Bool) async {
        reminderError = false
        guard enabled else {
            RitualReminderScheduler.cancel()
            return
        }

        authorization = await RitualReminderScheduler.authorization()
        if authorization == .notDetermined {
            let granted = await RitualReminderScheduler.requestAuthorization()
            authorization = await RitualReminderScheduler.authorization()
            guard granted, authorization == .granted else {
                remindersEnabled = false
                return
            }
        }
        guard authorization == .granted else {
            remindersEnabled = false
            return
        }
        await scheduleReminder()
    }

    private func rescheduleIfNeeded() {
        guard remindersEnabled, authorization == .granted else { return }
        Task { await scheduleReminder() }
    }

    private func scheduleReminder() async {
        do {
            try await RitualReminderScheduler.schedule(
                frequency: frequency.wrappedValue,
                minutesAfterMidnight: reminderMinutes,
                weekday: reminderWeekday
            )
            reminderError = false
        } catch {
            reminderError = true
        }
    }

    private static func weekdayName(_ weekday: Int) -> String {
        Calendar.current.weekdaySymbols[weekday - 1]
    }

    private var lockedDeckRow: some View {
        Button(action: { showingPaywall = true }) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Deck for new readings")
                Text("Unlock to choose Major Arcana only or the full 78-card deck.")
                    .font(.caption)
                    .foregroundStyle(Color.secondary)
            }
        }
    }
}
