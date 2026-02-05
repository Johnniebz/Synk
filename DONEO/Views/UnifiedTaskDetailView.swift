import SwiftUI
import PhotosUI

/// Unified Task Detail View - Path B Implementation
/// Shows task info, expandable subtasks with inline details, and ONE chat
struct UnifiedTaskDetailView: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var expandedSubtaskIds: Set<UUID> = []
    @State private var showingAddSubtask = false
    @State private var showingEditTask = false

    // Comment bar state
    @State private var commentText: String = ""
    @FocusState private var isCommentFocused: Bool

    // Get the current task from viewModel to ensure we have latest data
    private var currentTask: DONEOTask {
        viewModel.project.tasks.first { $0.id == task.id } ?? task
    }

    // ALL messages for this task (task-level + subtask-level)
    private var allTaskMessages: [Message] {
        viewModel.project.messages.filter { message in
            // Messages referencing this task directly
            if message.referencedTask?.taskId == task.id { return true }
            // Messages referencing any subtask of this task
            if let subtaskRef = message.referencedSubtask,
               currentTask.subtasks.contains(where: { $0.id == subtaskRef.subtaskId }) {
                return true
            }
            return false
        }.sorted { $0.timestamp < $1.timestamp }
    }

    private var canEdit: Bool {
        viewModel.canEditTask(task)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scrollable content: Task info + Subtasks + Chat
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
                            // Task Header Section
                            taskHeaderSection

                            // Subtasks Section
                            subtasksSection

                            // Chat Section
                            chatSection
                        }
                    }
                    .onChange(of: allTaskMessages.count) { _, _ in
                        // Scroll to bottom when new message arrives
                        if let lastMessage = allTaskMessages.last {
                            withAnimation {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Comment input bar
                commentInputBar
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(currentTask.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Listo") { dismiss() }
                }
                if canEdit {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingEditTask = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingAddSubtask) {
                AddSubtaskSheet(task: currentTask, viewModel: viewModel)
            }
            .sheet(isPresented: $showingEditTask) {
                EditTaskSheet(task: currentTask, viewModel: viewModel)
            }
        }
    }

    // MARK: - Task Header Section

    private var taskHeaderSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Status & Checkbox
            HStack(spacing: 12) {
                Button {
                    viewModel.toggleTaskStatus(currentTask)
                } label: {
                    Image(systemName: currentTask.status == .done ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 28))
                        .foregroundStyle(currentTask.status == .done ? .green : .secondary)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(currentTask.status == .done ? "Completada" : "Pendiente")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(currentTask.status == .done ? .green : .orange)

                    if currentTask.isOverdue && currentTask.status != .done {
                        Text("Vencida")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.red)
                    }
                }

                Spacer()

                // Due date badge
                if let dueDate = currentTask.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "calendar")
                            .font(.system(size: 12))
                        Text(formatDueDate(dueDate))
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundStyle(currentTask.isOverdue ? .red : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .tertiarySystemBackground))
                    .clipShape(Capsule())
                }
            }

            // Assignees
            if !currentTask.assignees.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Asignado a")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        ForEach(currentTask.assignees) { assignee in
                            HStack(spacing: 6) {
                                Circle()
                                    .fill(Theme.primaryLight)
                                    .frame(width: 24, height: 24)
                                    .overlay {
                                        Text(assignee.avatarInitials)
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(Theme.primary)
                                    }
                                Text(assignee.id == viewModel.currentUser.id ? "Yo" : assignee.displayFirstName)
                                    .font(.system(size: 13))
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color(uiColor: .tertiarySystemBackground))
                            .clipShape(Capsule())
                        }
                    }
                }
            }

            // Notes/Instructions
            if let notes = currentTask.notes, !notes.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Instrucciones")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    Text(notes)
                        .font(.system(size: 14))
                        .foregroundStyle(.primary)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }

            // Attachments
            if !currentTask.attachments.filter({ $0.isInstruction }).isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Adjuntos")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(currentTask.attachments.filter { $0.isInstruction }) { attachment in
                                TaskAttachmentChip(attachment: attachment)
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Subtasks Section

    private var subtasksSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("Subtareas")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                let completed = currentTask.subtasks.filter { $0.isDone }.count
                let total = currentTask.subtasks.count
                if total > 0 {
                    Text("\(completed)/\(total)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(completed == total ? .green : .secondary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 8)

            // Subtasks list
            if currentTask.subtasks.isEmpty {
                Text("Sin subtareas")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(currentTask.subtasks.sorted { !$0.isDone && $1.isDone }) { subtask in
                        expandableSubtaskRow(subtask)

                        if subtask.id != currentTask.subtasks.sorted(by: { !$0.isDone && $1.isDone }).last?.id {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 16)
            }

            // Add subtask button
            Button {
                showingAddSubtask = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Agregar Subtarea")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(Theme.primary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.primaryLight.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 16)
        }
    }

    // MARK: - Expandable Subtask Row

    @ViewBuilder
    private func expandableSubtaskRow(_ subtask: Subtask) -> some View {
        let isExpanded = expandedSubtaskIds.contains(subtask.id)

        VStack(spacing: 0) {
            // Main row
            HStack(spacing: 12) {
                // Checkbox
                Button {
                    if viewModel.canToggleSubtask(subtask) {
                        viewModel.toggleSubtaskStatus(currentTask, subtask)
                    }
                } label: {
                    Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundStyle(subtask.isDone ? .green : .secondary)
                }

                // Title and basic info
                VStack(alignment: .leading, spacing: 4) {
                    Text(subtask.title)
                        .font(.system(size: 15))
                        .strikethrough(subtask.isDone)
                        .foregroundStyle(subtask.isDone ? .secondary : .primary)

                    // Mini info row
                    HStack(spacing: 8) {
                        if !subtask.assignees.isEmpty {
                            HStack(spacing: -4) {
                                ForEach(subtask.assignees.prefix(2)) { assignee in
                                    Circle()
                                        .fill(Theme.primaryLight)
                                        .frame(width: 18, height: 18)
                                        .overlay {
                                            Text(assignee.avatarInitials)
                                                .font(.system(size: 7, weight: .medium))
                                                .foregroundStyle(Theme.primary)
                                        }
                                }
                            }
                        }

                        if let dueDate = subtask.dueDate {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(formatDueDate(dueDate))
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(subtask.isOverdue ? .red : .secondary)
                        }

                        if subtask.description != nil || !subtask.instructionAttachments.isEmpty {
                            Image(systemName: "doc.text")
                                .font(.system(size: 10))
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }

                Spacer()

                // Expand/collapse button
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        if isExpanded {
                            expandedSubtaskIds.remove(subtask.id)
                        } else {
                            expandedSubtaskIds.insert(subtask.id)
                        }
                    }
                } label: {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.tertiary)
                        .frame(width: 28, height: 28)
                        .background(Color(uiColor: .tertiarySystemBackground))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Expanded details
            if isExpanded {
                VStack(alignment: .leading, spacing: 12) {
                    // Assignees detail
                    if !subtask.assignees.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Asignado a")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)

                            HStack(spacing: 6) {
                                ForEach(subtask.assignees) { assignee in
                                    HStack(spacing: 4) {
                                        Circle()
                                            .fill(Theme.primaryLight)
                                            .frame(width: 20, height: 20)
                                            .overlay {
                                                Text(assignee.avatarInitials)
                                                    .font(.system(size: 8, weight: .medium))
                                                    .foregroundStyle(Theme.primary)
                                            }
                                        Text(assignee.id == viewModel.currentUser.id ? "Yo" : assignee.displayFirstName)
                                            .font(.system(size: 12))
                                    }
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color(uiColor: .tertiarySystemBackground))
                                    .clipShape(Capsule())
                                }
                            }
                        }
                    }

                    // Due date detail
                    if let dueDate = subtask.dueDate {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Fecha limite")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)

                            HStack(spacing: 6) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 12))
                                Text(dueDate.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                    .font(.system(size: 13))
                            }
                            .foregroundStyle(subtask.isOverdue ? .red : .primary)
                        }
                    }

                    // Description/Notes
                    if let description = subtask.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Notas")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)

                            Text(description)
                                .font(.system(size: 13))
                                .foregroundStyle(.primary)
                        }
                    }

                    // Attachments
                    if !subtask.instructionAttachments.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Adjuntos")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.tertiary)

                            HStack(spacing: 8) {
                                ForEach(subtask.instructionAttachments) { attachment in
                                    TaskAttachmentChip(attachment: attachment)
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal, 52)
                .padding(.bottom, 12)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack {
                Text("Conversacion")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if !allTaskMessages.isEmpty {
                    Text("\(allTaskMessages.count) mensajes")
                        .font(.system(size: 12))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Messages
            if allTaskMessages.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 28))
                        .foregroundStyle(.quaternary)
                    Text("Sin mensajes aun")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                    Text("Inicia la conversacion sobre esta tarea")
                        .font(.system(size: 12))
                        .foregroundStyle(.quaternary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                VStack(spacing: 8) {
                    ForEach(allTaskMessages) { message in
                        UnifiedMessageBubble(message: message, task: currentTask, viewModel: viewModel)
                            .id(message.id)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.bottom, 12)
            }
        }
        .background(Color(uiColor: .systemGray6))
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        HStack(spacing: 8) {
            // Text field
            TextField("Escribe un mensaje...", text: $commentText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .focused($isCommentFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendMessage()
                }

            // Send button
            if !commentText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(Theme.primary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }

    // MARK: - Helper Methods

    private func sendMessage() {
        let text = commentText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        // Send as task-level message
        viewModel.sendMessage(content: text, referencedTask: TaskReference(task: currentTask))
        commentText = ""
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

// MARK: - Unified Message Bubble

struct UnifiedMessageBubble: View {
    let message: Message
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel

    private var isCurrentUser: Bool {
        message.sender.id == viewModel.currentUser.id
    }

    // Check if message references a subtask
    private var referencedSubtask: Subtask? {
        guard let ref = message.referencedSubtask else { return nil }
        return task.subtasks.first { $0.id == ref.subtaskId }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isCurrentUser { Spacer(minLength: 50) }

            if !isCurrentUser {
                Circle()
                    .fill(Theme.primaryLight)
                    .frame(width: 28, height: 28)
                    .overlay {
                        Text(message.sender.avatarInitials)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Theme.primary)
                    }
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 4) {
                // Subtask reference indicator
                if let subtask = referencedSubtask {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 9))
                        Text("Re: \(subtask.title)")
                            .font(.system(size: 11))
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if !isCurrentUser {
                        Text(message.sender.displayFirstName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundStyle(isCurrentUser ? .white : .primary)

                    Text(message.timestamp.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 10))
                        .foregroundStyle(isCurrentUser ? .white.opacity(0.7) : .secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(isCurrentUser ? Theme.primary : Color(uiColor: .systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }

            if !isCurrentUser { Spacer(minLength: 50) }
        }
    }
}

// MARK: - Supporting Views

struct TaskAttachmentChip: View {
    let attachment: Attachment

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconForType)
                .font(.system(size: 12))
                .foregroundStyle(colorForType)

            Text(attachment.fileName)
                .font(.system(size: 12))
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color(uiColor: .tertiarySystemBackground))
        .clipShape(Capsule())
    }

    private var iconForType: String {
        switch attachment.type {
        case .image: return "photo.fill"
        case .document: return "doc.fill"
        case .video: return "video.fill"
        case .contact: return "person.crop.circle.fill"
        }
    }

    private var colorForType: Color {
        switch attachment.type {
        case .image: return .blue
        case .document: return .orange
        case .video: return .purple
        case .contact: return .green
        }
    }
}


#Preview {
    UnifiedTaskDetailView(
        task: DONEOTask(
            title: "Pedir materiales para cocina",
            assignees: [MockDataService.allUsers[0]],
            status: .pending,
            subtasks: [
                Subtask(title: "Obtener cotizaciones", description: "Llamar a 3 tiendas diferentes", isDone: true),
                Subtask(title: "Comparar precios", isDone: false),
                Subtask(title: "Hacer el pedido", isDone: false)
            ],
            notes: "Necesitamos materiales de buena calidad para la remodelacion"
        ),
        viewModel: ProjectChatViewModel(project: Project(
            name: "Proyecto de Prueba",
            members: MockDataService.allUsers
        ))
    )
}
