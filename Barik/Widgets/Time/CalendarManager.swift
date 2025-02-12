import Combine
import EventKit
import Foundation

class CalendarManager: ObservableObject {
    @Published var nextEvent: EKEvent?
    @Published var todaysEvents: [EKEvent] = []
    @Published var tomorrowsEvents: [EKEvent] = []
    private let eventStore = EKEventStore()
    private var cancellable: AnyCancellable?
    
    init() {
        requestAccess()
        startMonitoring()
    }
    
    deinit {
        cancellable?.cancel()
    }
    
    private func startMonitoring() {
        cancellable = Timer.publish(every: 5.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchTodaysEvents()
                self?.fetchTomorrowsEvents()
                self?.fetchNextEvent()
            }
        fetchTodaysEvents()
        fetchTomorrowsEvents()
        fetchNextEvent()
    }
    
    private func requestAccess() {
        eventStore.requestFullAccessToEvents { [weak self] granted, error in
            if granted && error == nil {
                self?.fetchTodaysEvents()
                self?.fetchTomorrowsEvents()
                self?.fetchNextEvent()
            } else {
                print("Calendar access not granted: \(String(describing: error))")
            }
        }
    }
    
    func fetchNextEvent() {
        let calendars = eventStore.calendars(for: .event)
        let now = Date()
        let calendar = Calendar.current
        
        guard let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) else {
            print("Failed to get end of day.")
            return
        }
        
        let predicate = eventStore.predicateForEvents(withStart: now, end: endOfDay, calendars: calendars)
        let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        
        let regularEvents = events.filter { !$0.isAllDay }
        let next = regularEvents.isEmpty ? events.first : regularEvents.first
        
        DispatchQueue.main.async {
            self.nextEvent = next
        }
    }
    
    func fetchTodaysEvents() {
        let calendars = eventStore.calendars(for: .event)
        let now = Date()
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: now)
        guard let endOfDay = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: now) else {
            print("Failed to get end of day.")
            return
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfDay, end: endOfDay, calendars: calendars)
        let events = eventStore.events(matching: predicate)
            .filter { $0.endDate >= now }
            .sorted { $0.startDate < $1.startDate }
        
        DispatchQueue.main.async {
            self.todaysEvents = events
        }
    }
    
    func fetchTomorrowsEvents() {
        let calendars = eventStore.calendars(for: .event)
        let now = Date()
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              let endOfTomorrow = calendar.date(bySettingHour: 23, minute: 59, second: 59, of: startOfTomorrow)
        else {
            print("Failed to get tomorrow's date range.")
            return
        }
        
        let predicate = eventStore.predicateForEvents(withStart: startOfTomorrow, end: endOfTomorrow, calendars: calendars)
        let events = eventStore.events(matching: predicate).sorted { $0.startDate < $1.startDate }
        
        DispatchQueue.main.async {
            self.tomorrowsEvents = events
        }
    }
}
