import SwiftUI

enum DueDateOption: Equatable {
    case none
    case today
    case tomorrow
    case thisWeek
    case custom(Date)

    var date: Date? {
        let calendar = Calendar.current
        switch self {
        case .none:
            return nil
        case .today:
            return calendar.startOfDay(for: Date())
        case .tomorrow:
            return calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: Date()))
        case .thisWeek:
            // Next Friday or end of week
            let today = Date()
            let weekday = calendar.component(.weekday, from: today)
            let daysUntilFriday = (6 - weekday + 7) % 7
            return calendar.date(byAdding: .day, value: daysUntilFriday == 0 ? 7 : daysUntilFriday, to: calendar.startOfDay(for: today))
        case .custom(let date):
            return date
        }
    }

    var label: String {
        switch self {
        case .none:
            return "Sin fecha limite"
        case .today:
            return "Hoy"
        case .tomorrow:
            return "Manana"
        case .thisWeek:
            return "Este viernes"
        case .custom(let date):
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    static func from(date: Date?) -> DueDateOption {
        guard let date = date else { return .none }
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return .today
        } else if calendar.isDateInTomorrow(date) {
            return .tomorrow
        } else {
            return .custom(date)
        }
    }
}

struct DueDatePicker: View {
    @Binding var selectedDate: Date?
    @Environment(\.dismiss) private var dismiss
    @State private var showDatePicker = false
    @State private var customDate = Date()

    var body: some View {
        NavigationStack {
            List {
                Section {
                    optionRow(.none)
                    optionRow(.today)
                    optionRow(.tomorrow)
                    optionRow(.thisWeek)

                    Button {
                        showDatePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            Text("Elegir una fecha...")
                            Spacer()
                            if case .custom = DueDateOption.from(date: selectedDate) {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.blue)
                            }
                        }
                    }
                    .foregroundColor(.primary)
                }
            }
            .navigationTitle("Fecha Limite")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showDatePicker) {
                customDatePicker
            }
        }
    }

    private func optionRow(_ option: DueDateOption) -> some View {
        Button {
            selectedDate = option.date
            dismiss()
        } label: {
            HStack {
                Image(systemName: iconFor(option))
                    .foregroundColor(colorFor(option))
                    .frame(width: 24)
                Text(option.label)
                Spacer()
                if DueDateOption.from(date: selectedDate) == option {
                    Image(systemName: "checkmark")
                        .foregroundColor(.blue)
                }
            }
        }
        .foregroundColor(.primary)
    }

    private func iconFor(_ option: DueDateOption) -> String {
        switch option {
        case .none: return "calendar.badge.minus"
        case .today: return "sun.max.fill"
        case .tomorrow: return "sunrise.fill"
        case .thisWeek: return "calendar.badge.clock"
        case .custom: return "calendar"
        }
    }

    private func colorFor(_ option: DueDateOption) -> Color {
        switch option {
        case .none: return .secondary
        case .today: return .orange
        case .tomorrow: return .blue
        case .thisWeek: return .purple
        case .custom: return .blue
        }
    }

    private var customDatePicker: some View {
        NavigationStack {
            DatePicker(
                "Seleccionar Fecha",
                selection: $customDate,
                in: Date()...,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .padding()
            .navigationTitle("Elegir una Fecha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        showDatePicker = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        selectedDate = customDate
                        showDatePicker = false
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Due Date Display Helper

struct DueDateLabel: View {
    let date: Date?
    let isOverdue: Bool

    init(date: Date?, isOverdue: Bool = false) {
        self.date = date
        self.isOverdue = isOverdue
    }

    var body: some View {
        if let date = date {
            HStack(spacing: 4) {
                Image(systemName: isOverdue ? "exclamationmark.circle.fill" : "calendar")
                    .font(.system(size: 11))
                Text(formattedDate(date))
                    .font(.system(size: 13))
            }
            .foregroundColor(isOverdue ? .red : dateColor(date))
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hoy"
        } else if calendar.isDateInTomorrow(date) {
            return "Manana"
        } else if calendar.isDateInYesterday(date) {
            return "Ayer"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }

    private func dateColor(_ date: Date) -> Color {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return .orange
        } else if calendar.isDateInTomorrow(date) {
            return .blue
        } else {
            return .secondary
        }
    }
}

#Preview {
    DueDatePicker(selectedDate: .constant(nil))
}
