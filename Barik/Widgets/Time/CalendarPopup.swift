import SwiftUI
import EventKit

struct CalendarPopup: View {
    let daysOfWeek = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
    @StateObject var calendarManager = CalendarManager()
    
    var body: some View {
        VStack(spacing: 0) {
            Text(currentMonthYear)
                .font(.title2)
                .padding(.bottom, 25)
            
            HStack {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .frame(width: 30)
                        .foregroundColor(day == "Sat" || day == "Sun" ? .gray : .white)
                }
            }
            .padding(.bottom, 10)
            VStack(spacing: 10) {
                ForEach(weeks.indices, id: \.self) { weekIndex in
                    HStack(spacing: 8) {
                        ForEach(weeks[weekIndex].indices, id: \.self) { dayIndex in
                            if let day = weeks[weekIndex][dayIndex] {
                                ZStack {
                                    if isToday(day: day) {
                                        Circle()
                                            .fill(.white)
                                            .frame(width: 30, height: 30)
                                    }
                                    Text("\(day)")
                                        .foregroundColor(
                                            isToday(day: day) ? .black :
                                                (dayIndex == 5 || dayIndex == 6 ? .gray : .white)
                                        )
                                        .frame(width: 30, height: 30)
                                }
                            } else {
                                Text("")
                                    .frame(width: 30, height: 30)
                            }
                        }
                    }
                }
            }
            eventSection(title: "TODAY", events: calendarManager.todaysEvents)
            eventSection(title: "TOMORROW", events: calendarManager.tomorrowsEvents)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 30)
        .fontWeight(.semibold)
        .foregroundStyle(.white)
    }
    
    var currentMonthYear: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "LLLL yyyy"
        return formatter.string(from: Date())
    }
    
    var calendarDays: [Int?] {
        let calendar = Calendar.current
        let date = Date()
        guard let range = calendar.range(of: .day, in: .month, for: date),
              let firstOfMonth = calendar.date(from: calendar.dateComponents([.year, .month], from: date))
        else {
            return []
        }
        let firstWeekday = calendar.component(.weekday, from: firstOfMonth)
        let blanks = (firstWeekday - 2 + 7) % 7
        var days: [Int?] = Array(repeating: nil, count: blanks)
        days.append(contentsOf: range.map { $0 })
        return days
    }
    
    var weeks: [[Int?]] {
        var days = calendarDays
        let remainder = days.count % 7
        if remainder != 0 {
            days.append(contentsOf: Array(repeating: nil, count: 7 - remainder))
        }
        return stride(from: 0, to: days.count, by: 7).map {
            Array(days[$0..<min($0+7, days.count)])
        }
    }
    
    func isToday(day: Int) -> Bool {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: Date())
        if let dateFromDay = calendar.date(from: DateComponents(year: components.year, month: components.month, day: day)) {
            return calendar.isDateInToday(dateFromDay)
        }
        return false
    }
    
    @ViewBuilder
    private func eventSection(title: String, events: [EKEvent]) -> some View {
        if !events.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                ForEach(events, id: \.eventIdentifier) { event in
                    EventRow(event: event)
                }
            }
            .padding(.top, 20)
            .frame(width: 255)
        }
    }
}

struct EventRow: View {
    let event: EKEvent
    
    var body: some View {
        HStack(spacing: 4) {
            Rectangle()
                .fill(Color(event.calendar.cgColor))
                .frame(width: 3, height: 30)
                .clipShape(Capsule())
            VStack(alignment: .leading) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)
                Text(event.startDate, style: .time)
                    .font(.caption)
                    .fontWeight(.regular)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(5)
        .padding(.trailing, 5)
        .foregroundStyle(Color(event.calendar.cgColor))
        .background(Color(event.calendar.cgColor).opacity(0.2))
        .cornerRadius(6)
        .frame(maxWidth: .infinity)
    }
}

struct CalendarPopup_Previews: PreviewProvider {
    static var previews: some View {
        CalendarPopup()
            .background(.black)
            .previewLayout(.sizeThatFits)
    }
}
