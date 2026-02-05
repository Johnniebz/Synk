import SwiftUI

struct ProjectCardView: View {
    let project: Project

    var body: some View {
        // Access currentUser to trigger re-render when user switches
        let _ = MockDataService.shared.currentUser
        HStack(spacing: 12) {
            // Project avatar
            ZStack {
                Circle()
                    .fill(Theme.primaryLight)
                    .frame(width: 55, height: 55)

                Text(projectInitials)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Theme.primary)
            }

            // Project info - WhatsApp layout
            VStack(alignment: .leading, spacing: 4) {
                // Top row: Name + Timestamp
                HStack {
                    Text(project.name)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Spacer()

                    if let lastActivity = project.lastActivity {
                        Text(formatLastActivity(lastActivity))
                            .font(.system(size: 14))
                            .foregroundStyle(project.unreadCount > 0 ? Theme.primary : .secondary)
                    }
                }

                // Bottom row: Preview + Badge
                HStack {
                    if let preview = project.lastActivityPreview {
                        Text(preview)
                            .font(.system(size: 15))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    if project.unreadCount > 0 {
                        Text("\(project.unreadCount)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .frame(minWidth: 20, minHeight: 20)
                            .background(Theme.primary)
                            .clipShape(Circle())
                    }
                }
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private var projectInitials: String {
        let words = project.name.split(separator: " ")
        if words.count >= 2 {
            return String(words[0].prefix(1) + words[1].prefix(1)).uppercased()
        }
        return String(project.name.prefix(2)).uppercased()
    }

    private func formatLastActivity(_ date: Date) -> String {
        let now = Date()
        let calendar = Calendar.current
        let components = calendar.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let days = components.day, days > 0 {
            if days == 1 {
                return "Ayer"
            } else if days < 7 {
                return "hace \(days) dias"
            } else {
                return date.formatted(.dateTime.month(.abbreviated).day())
            }
        } else if let hours = components.hour, hours > 0 {
            return "hace \(hours)h"
        } else if let minutes = components.minute, minutes > 0 {
            return "hace \(minutes)m"
        } else {
            return "Ahora mismo"
        }
    }
}

#Preview {
    List {
        ProjectCardView(project: Project(
            name: "Downtown Renovation",
            tasks: [
                DONEOTask(title: "Task 1", status: .pending),
                DONEOTask(title: "Task 2", status: .done)
            ]
        ))
        ProjectCardView(project: Project(
            name: "Smith Residence",
            tasks: []
        ))
        ProjectCardView(project: Project(
            name: "Office Building",
            tasks: [
                DONEOTask(title: "Overdue task", status: .pending, dueDate: Calendar.current.date(byAdding: .day, value: -2, to: Date()))
            ]
        ))
    }
    .listStyle(.plain)
}
