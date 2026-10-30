import AppKit
import EventKit

struct CalendarItem: Identifiable, Equatable {
    let id: String
    let title: String
    let start: Date
    let end: Date
    let allDay: Bool
    let color: NSColor
}

final class CalendarModel: ObservableObject {
    enum Access { case unknown, granted, denied }

    @Published private(set) var access: Access = .unknown
    @Published private(set) var items: [CalendarItem] = []
    private let store = EKEventStore()

    init() {
        access = Self.status()
        NotificationCenter.default.addObserver(forName: .EKEventStoreChanged, object: store, queue: .main) { [weak self] _ in
            self?.refresh()
        }
        refresh()
    }

    private static func status() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .fullAccess: return .granted
        case .notDetermined: return .unknown
        default: return .denied
        }
    }

    func requestAccess() {
        NSApp.activate(ignoringOtherApps: true)
        store.requestFullAccessToEvents { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self else { return }
                self.access = Self.status()
                self.refresh()
            }
        }
    }

    func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") {
            NSWorkspace.shared.open(url)
        }
    }

    func refresh() {
        access = Self.status()
        guard access == .granted else { items = []; return }
        let now = Date()
        let cal = Calendar.current
        guard let limit = cal.date(byAdding: .day, value: 2, to: cal.startOfDay(for: now)) else { return }
        let predicate = store.predicateForEvents(withStart: now, end: limit, calendars: nil)
        func key(_ e: EKEvent) -> (Date, Int, Date) {
            (cal.startOfDay(for: max(e.startDate, now)), e.isAllDay ? 0 : 1, e.startDate)
        }
        var seen = Set<String>()
        items = store.events(matching: predicate)
            .filter { $0.endDate > now && $0.status != .canceled }
            .sorted { key($0) < key($1) }
            .filter { seen.insert("\($0.title ?? "")|\($0.startDate.timeIntervalSince1970)").inserted }
            .prefix(8)
            .map {
                CalendarItem(id: $0.calendarItemIdentifier + "\($0.startDate.timeIntervalSince1970)",
                             title: $0.title ?? "Sans titre", start: $0.startDate, end: $0.endDate,
                             allDay: $0.isAllDay, color: $0.calendar.color)
            }
    }
}
