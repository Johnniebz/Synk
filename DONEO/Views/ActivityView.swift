import SwiftUI
import Observation

// MARK: - Activity View Model

@Observable
final class ActivityViewModel {
    private var dataService = MockDataService.shared

    var currentUser: User {
        dataService.currentUser
    }

    // Get project by ID
    func getProject(id: UUID) -> Project? {
        dataService.projects.first { $0.id == id }
    }

    // Get task by ID from a project
    func getTask(projectId: UUID, taskId: UUID) -> DONEOTask? {
        getProject(id: projectId)?.tasks.first { $0.id == taskId }
    }

    // MARK: - Dashboard Item

    struct DashboardTaskItem: Identifiable {
        let id: UUID
        let task: DONEOTask
        let project: Project
        let projectName: String

        var subtaskProgress: (done: Int, total: Int)? {
            let total = task.subtasks.count
            guard total > 0 else { return nil }
            let done = task.subtasks.filter { $0.isDone }.count
            return (done, total)
        }
    }

    // MARK: - Due Today Tasks

    var dueTodayTasks: [DashboardTaskItem] {
        var items: [DashboardTaskItem] = []

        for project in dataService.projects {
            let tasks = project.tasks.filter { task in
                task.status == .pending &&
                task.assignees.contains(where: { $0.id == currentUser.id }) &&
                task.isAcknowledged(by: currentUser.id) &&
                task.isDueToday &&
                !task.isOverdue
            }

            for task in tasks {
                items.append(DashboardTaskItem(
                    id: task.id,
                    task: task,
                    project: project,
                    projectName: project.name
                ))
            }
        }

        return items.sorted { ($0.task.dueDate ?? .distantFuture) < ($1.task.dueDate ?? .distantFuture) }
    }

    // MARK: - Overdue Tasks

    var overdueTasks: [DashboardTaskItem] {
        var items: [DashboardTaskItem] = []

        for project in dataService.projects {
            let tasks = project.tasks.filter { task in
                task.status == .pending &&
                task.assignees.contains(where: { $0.id == currentUser.id }) &&
                task.isAcknowledged(by: currentUser.id) &&
                task.isOverdue
            }

            for task in tasks {
                items.append(DashboardTaskItem(
                    id: task.id,
                    task: task,
                    project: project,
                    projectName: project.name
                ))
            }
        }

        return items.sorted { ($0.task.dueDate ?? .distantFuture) < ($1.task.dueDate ?? .distantFuture) }
    }

    // MARK: - Upcoming Tasks (not due today, not overdue)

    var upcomingTasks: [DashboardTaskItem] {
        var items: [DashboardTaskItem] = []

        for project in dataService.projects {
            let tasks = project.tasks.filter { task in
                task.status == .pending &&
                task.assignees.contains(where: { $0.id == currentUser.id }) &&
                task.isAcknowledged(by: currentUser.id) &&
                !task.isDueToday &&
                !task.isOverdue
            }

            for task in tasks {
                items.append(DashboardTaskItem(
                    id: task.id,
                    task: task,
                    project: project,
                    projectName: project.name
                ))
            }
        }

        return items.sorted { ($0.task.dueDate ?? .distantFuture) < ($1.task.dueDate ?? .distantFuture) }
    }

    // MARK: - Recently Done (last 7 days)

    var recentlyDoneTasks: [DashboardTaskItem] {
        var items: [DashboardTaskItem] = []
        let weekAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()

        for project in dataService.projects {
            let tasks = project.tasks.filter { task in
                task.status == .done &&
                task.assignees.contains(where: { $0.id == currentUser.id }) &&
                task.lastActivity > weekAgo
            }

            for task in tasks {
                items.append(DashboardTaskItem(
                    id: task.id,
                    task: task,
                    project: project,
                    projectName: project.name
                ))
            }
        }

        return items.sorted { $0.task.lastActivity > $1.task.lastActivity }
    }

    // MARK: - Stats

    var totalActiveTasks: Int {
        dueTodayTasks.count + overdueTasks.count + upcomingTasks.count
    }

    var doneThisWeekCount: Int {
        recentlyDoneTasks.count
    }
}

// MARK: - Activity View (Personal Dashboard)

struct ActivityView: View {
    @State private var viewModel = ActivityViewModel()
    @State private var selectedTask: (task: DONEOTask, project: Project)?
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    // Stats header
                    statsHeader
                        .padding(.horizontal)
                        .padding(.top, 8)

                    // Overdue section
                    if !viewModel.overdueTasks.isEmpty {
                        taskSection(
                            title: "Atrasadas",
                            count: viewModel.overdueTasks.count,
                            tasks: viewModel.overdueTasks,
                            accentColor: .red
                        )
                    }

                    // Due Today section
                    if !viewModel.dueTodayTasks.isEmpty {
                        taskSection(
                            title: "Para Hoy",
                            count: viewModel.dueTodayTasks.count,
                            tasks: viewModel.dueTodayTasks,
                            accentColor: .orange
                        )
                    }

                    // Upcoming section
                    if !viewModel.upcomingTasks.isEmpty {
                        taskSection(
                            title: "Proximas",
                            count: viewModel.upcomingTasks.count,
                            tasks: viewModel.upcomingTasks,
                            accentColor: Theme.primary
                        )
                    }

                    // Empty state if no active tasks
                    if viewModel.totalActiveTasks == 0 {
                        emptyActiveState
                    }

                    // Recently Done section
                    if !viewModel.recentlyDoneTasks.isEmpty {
                        taskSection(
                            title: "Completadas Recientemente",
                            count: viewModel.recentlyDoneTasks.count,
                            tasks: viewModel.recentlyDoneTasks,
                            accentColor: .green,
                            isDoneSection: true
                        )
                    }

                    Spacer(minLength: 40)
                }
                .padding(.bottom, 20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Mis Tareas")
            .navigationDestination(for: UUID.self) { projectId in
                if let project = viewModel.getProject(id: projectId) {
                    ProjectChatView(project: project)
                }
            }
            .sheet(item: Binding(
                get: { selectedTask.map { SelectedTaskWrapper(task: $0.task, project: $0.project) } },
                set: { selectedTask = $0.map { ($0.task, $0.project) } }
            )) { wrapper in
                ActivityTaskInfoSheet(
                    task: wrapper.task,
                    project: wrapper.project,
                    onGoToProject: {
                        selectedTask = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            navigationPath.append(wrapper.project.id)
                        }
                    }
                )
            }
        }
    }

    // MARK: - Stats Header

    private var statsHeader: some View {
        HStack(spacing: 16) {
            // Active tasks stat
            StatCard(
                value: "\(viewModel.totalActiveTasks)",
                label: "Activas",
                icon: "checklist",
                color: Theme.primary
            )

            // Done this week stat
            StatCard(
                value: "\(viewModel.doneThisWeekCount)",
                label: "Esta semana",
                icon: "checkmark.circle.fill",
                color: .green
            )

            // Overdue stat (if any)
            if !viewModel.overdueTasks.isEmpty {
                StatCard(
                    value: "\(viewModel.overdueTasks.count)",
                    label: "Atrasadas",
                    icon: "exclamationmark.circle.fill",
                    color: .red
                )
            }
        }
    }

    // MARK: - Task Section

    private func taskSection(
        title: String,
        count: Int,
        tasks: [ActivityViewModel.DashboardTaskItem],
        accentColor: Color,
        isDoneSection: Bool = false
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Section header
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .bold))

                Text("(\(count))")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(accentColor)

                Spacer()
            }
            .padding(.horizontal)

            // Task cards
            VStack(spacing: 8) {
                ForEach(tasks) { item in
                    DashboardTaskRow(
                        item: item,
                        isDone: isDoneSection,
                        accentColor: accentColor
                    ) {
                        selectedTask = (item.task, item.project)
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Empty State

    private var emptyActiveState: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 48))
                .foregroundStyle(.green.opacity(0.6))

            Text("Todo al dia!")
                .font(.system(size: 20, weight: .semibold))

            Text("No tienes tareas activas ahora")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

// MARK: - Helper wrapper for sheet binding

struct SelectedTaskWrapper: Identifiable {
    let id = UUID()
    let task: DONEOTask
    let project: Project
}

// MARK: - Stat Card

struct StatCard: View {
    let value: String
    let label: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(color)
                Text(value)
                    .font(.system(size: 24, weight: .bold))
            }

            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color(uiColor: .secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Dashboard Task Row

struct DashboardTaskRow: View {
    let item: ActivityViewModel.DashboardTaskItem
    let isDone: Bool
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Status indicator
                Circle()
                    .fill(isDone ? .green : accentColor.opacity(0.2))
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 4) {
                    // Task title
                    Text(item.task.title)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(isDone ? .secondary : .primary)
                        .strikethrough(isDone)
                        .lineLimit(1)

                    // Info row
                    HStack(spacing: 8) {
                        // Project name
                        Text(item.projectName)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)

                        // Subtask progress
                        if let progress = item.subtaskProgress {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            HStack(spacing: 3) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 10))
                                Text("\(progress.done)/\(progress.total)")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(progress.done == progress.total ? .green : .secondary)
                        }

                        // Due date
                        if let dueDate = item.task.dueDate, !isDone {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(formatDueDate(dueDate))
                                .font(.system(size: 12))
                                .foregroundStyle(item.task.isOverdue ? .red : .secondary)
                        }
                    }
                }

                Spacer()

                // Chevron
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(12)
            .background(Color(uiColor: .secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func formatDueDate(_ date: Date) -> String {
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
}

// MARK: - Activity Task Info Sheet (wraps TaskInfoSheet pattern)

struct ActivityTaskInfoSheet: View {
    let task: DONEOTask
    let project: Project
    let onGoToProject: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var viewModel: ProjectChatViewModel

    init(task: DONEOTask, project: Project, onGoToProject: @escaping () -> Void) {
        self.task = task
        self.project = project
        self.onGoToProject = onGoToProject
        _viewModel = State(initialValue: ProjectChatViewModel(project: project))
    }

    private var taskMessages: [Message] {
        viewModel.project.messages.filter { $0.referencedTask?.taskId == task.id }
    }

    private var statusIcon: String {
        if task.status == .done { return "checkmark.circle.fill" }
        if task.isOverdue { return "exclamationmark.circle.fill" }
        return "circle"
    }

    private var statusText: String {
        if task.status == .done { return "Completada" }
        if task.isOverdue { return "Atrasada" }
        return "En Progreso"
    }

    private var statusColor: Color {
        if task.status == .done { return .green }
        if task.isOverdue { return .red }
        return .orange
    }

    @State private var showingDetailsOverlay = false
    @State private var commentText = ""
    @FocusState private var isCommentFocused: Bool

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                VStack(spacing: 0) {
                    // Project breadcrumb
                    Button(action: {
                        dismiss()
                        onGoToProject()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text(project.name)
                                .font(.system(size: 13))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Theme.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .background(Color(uiColor: .secondarySystemBackground))

                    // Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.system(size: 20, weight: .bold))
                                    .fixedSize(horizontal: false, vertical: true)

                                HStack(spacing: 8) {
                                    HStack(spacing: 4) {
                                        Image(systemName: statusIcon)
                                            .font(.system(size: 10))
                                        Text(statusText)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundStyle(statusColor)

                                    if task.dueDate != nil || !task.assignees.isEmpty {
                                        Text("·").foregroundStyle(.tertiary)
                                    }

                                    if let dueDate = task.dueDate {
                                        Text(formatDueDate(dueDate))
                                            .font(.system(size: 13))
                                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                                    }

                                    if let firstAssignee = task.assignees.first {
                                        if task.dueDate != nil {
                                            Text("·").foregroundStyle(.tertiary)
                                        }
                                        Text(firstAssignee.displayFirstName)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()

                            Button {
                                withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                    showingDetailsOverlay.toggle()
                                }
                            } label: {
                                Image(systemName: showingDetailsOverlay ? "xmark.circle.fill" : "info.circle")
                                    .font(.system(size: 22))
                                    .foregroundStyle(Theme.primary)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(uiColor: .systemBackground))

                    Divider()

                    // Chat area
                    ScrollView {
                        VStack(spacing: 8) {
                            if taskMessages.isEmpty {
                                VStack(spacing: 8) {
                                    Spacer().frame(height: 60)
                                    Image(systemName: "bubble.left.and.bubble.right")
                                        .font(.system(size: 32))
                                        .foregroundStyle(.quaternary)
                                    Text("Sin mensajes aun")
                                        .font(.system(size: 15))
                                        .foregroundStyle(.tertiary)
                                    Spacer()
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.top, 40)
                            } else {
                                ForEach(taskMessages) { message in
                                    TaskCommentBubble(message: message, viewModel: viewModel)
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 12)
                    }
                    .background(Color(uiColor: .systemGray6))

                    // Comment bar
                    commentBar
                }

                // Details overlay
                if showingDetailsOverlay {
                    detailsOverlay
                }
            }
            .navigationTitle("Tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private var commentBar: some View {
        HStack(spacing: 8) {
            Button {} label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.primary)
            }

            TextField("Comentar en esta tarea...", text: $commentText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($isCommentFocused)
                .submitLabel(.send)
                .onSubmit {
                    if !commentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        viewModel.sendTaskQuestion(task, message: commentText)
                        commentText = ""
                    }
                }

            if !commentText.isEmpty {
                Button {
                    viewModel.sendTaskQuestion(task, message: commentText)
                    commentText = ""
                    isCommentFocused = false
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }

    private var detailsOverlay: some View {
        Group {
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        showingDetailsOverlay = false
                    }
                }
                .transition(.opacity)

            VStack(spacing: 0) {
                HStack {
                    Text("Detalles de la Tarea")
                        .font(.system(size: 17, weight: .semibold))
                    Spacer()
                    Button {
                        withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                            showingDetailsOverlay = false
                        }
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(Color(uiColor: .systemBackground))

                Divider()

                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // Status
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Estado")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            HStack(spacing: 12) {
                                Button {
                                    viewModel.toggleTaskStatus(task)
                                } label: {
                                    HStack(spacing: 8) {
                                        Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 20))
                                        Text(task.status == .done ? "Completada" : "Marcar Completa")
                                            .font(.system(size: 15, weight: .medium))
                                    }
                                    .foregroundStyle(task.status == .done ? .green : Theme.primary)
                                }
                                Spacer()
                            }
                        }

                        Divider()

                        // Due date
                        if let dueDate = task.dueDate {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Fecha Limite")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                HStack(spacing: 8) {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(task.isOverdue ? .red : Theme.primary)
                                    Text(dueDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                        .font(.system(size: 15))
                                }
                            }
                            Divider()
                        }

                        // Assignees
                        if !task.assignees.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Asignada a")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                FlowLayout(spacing: 8) {
                                    ForEach(task.assignees) { assignee in
                                        HStack(spacing: 6) {
                                            Circle()
                                                .fill(Theme.primaryLight)
                                                .frame(width: 28, height: 28)
                                                .overlay {
                                                    Text(assignee.avatarInitials)
                                                        .font(.system(size: 10, weight: .medium))
                                                        .foregroundStyle(Theme.primary)
                                                }
                                            Text(assignee.displayFirstName)
                                                .font(.system(size: 14))
                                        }
                                        .padding(.trailing, 8)
                                        .padding(.vertical, 4)
                                        .padding(.leading, 4)
                                        .background(Color(uiColor: .secondarySystemBackground))
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                            Divider()
                        }

                        // Instructions
                        if let notes = task.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Instrucciones")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text(notes)
                                    .font(.system(size: 15))
                            }
                        }

                        // Subtasks
                        if !task.subtasks.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Subtareas")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)

                                ForEach(task.subtasks) { subtask in
                                    HStack(spacing: 8) {
                                        Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(subtask.isDone ? .green : .secondary)
                                        Text(subtask.title)
                                            .font(.system(size: 14))
                                            .strikethrough(subtask.isDone)
                                            .foregroundStyle(subtask.isDone ? .secondary : .primary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20)
                }
                .background(Color(uiColor: .systemBackground))
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.15), radius: 20, y: 5)
            .padding(.horizontal, 8)
            .padding(.top, 90)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "Hoy" }
        if calendar.isDateInTomorrow(date) { return "Manana" }
        if calendar.isDateInYesterday(date) { return "Ayer" }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

// MARK: - Preview

#Preview {
    ActivityView()
}
