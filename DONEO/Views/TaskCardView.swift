import SwiftUI

struct TaskCardView: View {
    let task: DONEOTask
    var unreadCount: Int = 0

    var body: some View {
        HStack(spacing: 12) {
            // Task content
            VStack(alignment: .leading, spacing: 4) {
                Text(task.title)
                    .font(.system(size: 16))
                    .foregroundStyle(task.status == .done ? .secondary : .primary)
                    .strikethrough(task.status == .done)
                    .lineLimit(2)

                // Meta info row - simplified
                HStack(spacing: 8) {
                    // Due date - simplified styling
                    if let dueDate = task.dueDate {
                        Text(formatDueDate(dueDate))
                            .font(.system(size: 12))
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                    }

                    // Subtask count
                    if !task.subtasks.isEmpty {
                        if task.dueDate != nil {
                            Text("·")
                                .foregroundStyle(.tertiary)
                        }
                        Text("\(task.subtasks.filter { $0.isDone }.count)/\(task.subtasks.count)")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Unread count badge
            if unreadCount > 0 {
                Text("\(unreadCount)")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Theme.primary)
                    .clipShape(Capsule())
            }

            // Chevron for navigation
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if task.isOverdue {
            if calendar.isDateInYesterday(date) {
                return "Ayer"
            } else {
                return "Vencida"
            }
        } else if calendar.isDateInToday(date) {
            return "Hoy"
        } else if calendar.isDateInTomorrow(date) {
            return "Manana"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

#Preview {
    List {
        TaskCardView(
            task: DONEOTask(
                title: "Order materials for kitchen renovation project",
                status: .pending,
                dueDate: Date(),
                subtasks: [
                    Subtask(title: "Get quotes", isDone: true),
                    Subtask(title: "Order lumber", isDone: false)
                ]
            ),
            unreadCount: 3
        )
        TaskCardView(
            task: DONEOTask(
                title: "Complete bathroom tiling",
                status: .pending,
                dueDate: Calendar.current.date(byAdding: .day, value: -1, to: Date())
            ),
            unreadCount: 1
        )
        TaskCardView(
            task: DONEOTask(
                title: "Task with subtasks only",
                status: .pending,
                subtasks: [
                    Subtask(title: "Step 1", isDone: true),
                    Subtask(title: "Step 2", isDone: true),
                    Subtask(title: "Step 3", isDone: false)
                ]
            )
        )
        TaskCardView(
            task: DONEOTask(
                title: "Completed task",
                status: .done
            )
        )
    }
    .listStyle(.plain)
}
