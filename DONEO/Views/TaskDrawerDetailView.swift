import SwiftUI
import PhotosUI

struct TaskDrawerDetailView: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var showingAddSubtask = false
    @State private var showingTaskDetails = false

    // Get the current task from viewModel to ensure we have latest data
    private var currentTask: DONEOTask {
        viewModel.project.tasks.first { $0.id == task.id } ?? task
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Task header (tappable to see details)
                taskHeader

                // Subtasks list
                if currentTask.subtasks.isEmpty {
                    emptySubtasksView
                } else {
                    subtasksList
                }

                // Add subtask section
                addSubtaskSection
            }
            .navigationTitle("Detalles de Tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                            Text("Atras")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        viewModel.quoteTask(currentTask)
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "text.bubble")
                                .font(.system(size: 14))
                            Text("Comentar")
                                .font(.system(size: 14, weight: .medium))
                        }
                        .foregroundStyle(Theme.primary)
                    }
                }
            }
            .sheet(isPresented: $showingTaskDetails) {
                TaskInfoSheet(task: currentTask, viewModel: viewModel)
            }
        }
    }

    // MARK: - Task Header

    private var taskHeader: some View {
        Button {
            showingTaskDetails = true
        } label: {
            HStack(spacing: 12) {
                // Task info
                VStack(alignment: .leading, spacing: 6) {
                    Text(currentTask.title)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    // Info row
                    HStack(spacing: 12) {
                        // Subtask progress
                        if !currentTask.subtasks.isEmpty {
                            let completed = currentTask.subtasks.filter { $0.isDone }.count
                            let total = currentTask.subtasks.count
                            HStack(spacing: 4) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 11))
                                Text("\(completed)/\(total)")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(completed == total ? .green : .secondary)
                        }

                        // Due date
                        if let dueDate = currentTask.dueDate {
                            HStack(spacing: 4) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 11))
                                Text(formatDueDate(dueDate))
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(currentTask.isOverdue ? .red : .secondary)
                        }

                        // Has notes indicator
                        if currentTask.notes != nil {
                            HStack(spacing: 4) {
                                Image(systemName: "doc.text")
                                    .font(.system(size: 11))
                                Text("Notas")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }

                    // Assignees
                    if !currentTask.assignees.isEmpty {
                        HStack(spacing: 4) {
                            HStack(spacing: -4) {
                                ForEach(currentTask.assignees.prefix(3)) { assignee in
                                    Circle()
                                        .fill(Theme.primaryLight)
                                        .frame(width: 20, height: 20)
                                        .overlay {
                                            Text(assignee.avatarInitials)
                                                .font(.system(size: 8, weight: .medium))
                                                .foregroundStyle(Theme.primary)
                                        }
                                        .overlay(
                                            Circle()
                                                .stroke(Color(uiColor: .secondarySystemBackground), lineWidth: 1)
                                        )
                                }
                            }
                            let names = currentTask.assignees.prefix(2).map { $0.displayFirstName }
                            let displayText = currentTask.assignees.count > 2
                                ? "\(names.joined(separator: ", ")) +\(currentTask.assignees.count - 2)"
                                : names.joined(separator: ", ")
                            Text(displayText)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                // Chevron to indicate tappable
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(uiColor: .secondarySystemBackground))
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

    // MARK: - Empty Subtasks View

    private var emptySubtasksView: some View {
        VStack(spacing: 12) {
            Spacer()

            Image(systemName: "list.bullet")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("Sin subtareas")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Divide esta tarea en pasos mas pequenos")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Subtasks List (split into Pending/Completed like Tasks screen)

    private var pendingSubtasks: [Subtask] {
        currentTask.subtasks.filter { !$0.isDone }
    }

    private var completedSubtasks: [Subtask] {
        currentTask.subtasks.filter { $0.isDone }
    }

    private var subtasksList: some View {
        List {
            // Pending section
            if !pendingSubtasks.isEmpty {
                Section {
                    ForEach(pendingSubtasks) { subtask in
                        DrawerSubtaskRow(
                            subtask: subtask,
                            task: currentTask,
                            viewModel: viewModel,
                            onQuote: {
                                viewModel.quoteSubtask(currentTask, subtask: subtask)
                                dismiss()
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.deleteSubtask(from: currentTask, subtask: subtask)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }

                            Button {
                                viewModel.quoteSubtask(currentTask, subtask: subtask)
                                dismiss()
                            } label: {
                                Label("Citar", systemImage: "quote.bubble")
                            }
                            .tint(Theme.primary)
                        }
                    }
                } header: {
                    Text("Pendientes (\(pendingSubtasks.count))")
                }
            }

            // Completed section
            if !completedSubtasks.isEmpty {
                Section {
                    ForEach(completedSubtasks) { subtask in
                        DrawerSubtaskRow(
                            subtask: subtask,
                            task: currentTask,
                            viewModel: viewModel,
                            onQuote: {
                                viewModel.quoteSubtask(currentTask, subtask: subtask)
                                dismiss()
                            }
                        )
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                viewModel.deleteSubtask(from: currentTask, subtask: subtask)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }

                            Button {
                                viewModel.quoteSubtask(currentTask, subtask: subtask)
                                dismiss()
                            } label: {
                                Label("Citar", systemImage: "quote.bubble")
                            }
                            .tint(Theme.primary)
                        }
                    }
                } header: {
                    Text("Completadas (\(completedSubtasks.count))")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Add Subtask Button (red button like Add Task)

    private var addSubtaskSection: some View {
        VStack(spacing: 0) {
            Button {
                showingAddSubtask = true
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 18))
                    Text("Agregar Subtarea")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Theme.primary)
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
        }
        .sheet(isPresented: $showingAddSubtask) {
            AddSubtaskSheet(task: currentTask, viewModel: viewModel)
        }
    }
}

// MARK: - Drawer Subtask Row (matches Task row style - no chevron)

struct DrawerSubtaskRow: View {
    let subtask: Subtask
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    let onQuote: () -> Void

    @State private var showingDetail = false

    private var canToggle: Bool {
        viewModel.canToggleSubtask(subtask)
    }

    // Get attachments linked to this subtask
    private var subtaskAttachments: [Attachment] {
        task.attachments.filter { $0.linkedSubtaskId == subtask.id }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                if canToggle {
                    viewModel.toggleSubtaskStatus(task, subtask)
                }
            } label: {
                Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(subtask.isDone ? .green : (canToggle ? .secondary : .secondary.opacity(0.3)))
            }
            .buttonStyle(.plain)
            .disabled(!canToggle)

            // Subtask info - tappable for details
            Button {
                showingDetail = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    // Title
                    Text(subtask.title)
                        .font(.system(size: 16))
                        .strikethrough(subtask.isDone)
                        .foregroundStyle(subtask.isDone ? .secondary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    // Info row: assignees, due date, attachments
                    HStack(spacing: 8) {
                        // Assignees
                        if !subtask.assignees.isEmpty {
                            HStack(spacing: 4) {
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
                                            .overlay(
                                                Circle()
                                                    .stroke(Color(uiColor: .systemBackground), lineWidth: 1)
                                            )
                                    }
                                }
                                let names = subtask.assignees.prefix(2).map { $0.displayFirstName }
                                let displayText = subtask.assignees.count > 2
                                    ? "\(names.joined(separator: ", ")) +\(subtask.assignees.count - 2)"
                                    : names.joined(separator: ", ")
                                Text(displayText)
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        // Due date
                        if let dueDate = subtask.dueDate {
                            HStack(spacing: 3) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(formatDueDate(dueDate))
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(subtask.isOverdue ? .red : .secondary)
                        }

                        // Attachments count
                        if !subtaskAttachments.isEmpty {
                            HStack(spacing: 3) {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 10))
                                Text("\(subtaskAttachments.count)")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            // NO chevron - subtasks don't have sub-items
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .sheet(isPresented: $showingDetail) {
            SubtaskInfoSheet(
                subtask: subtask,
                task: task,
                viewModel: viewModel
            )
        }
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hoy"
        } else if calendar.isDateInTomorrow(date) {
            return "Manana"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Subtask Info Sheet (View-Only)

struct SubtaskInfoSheet: View {
    let subtask: Subtask
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    var onNavigateToParentTask: ((DONEOTask) -> Void)? = nil
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Estado")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)

                        HStack(spacing: 14) {
                            Button {
                                viewModel.toggleSubtaskStatus(task, subtask)
                            } label: {
                                Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 28))
                                    .foregroundStyle(subtask.isDone ? .green : Theme.primary.opacity(0.4))
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(subtask.title)
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(subtask.isDone ? .secondary : .primary)
                                    .strikethrough(subtask.isDone)

                                Text(subtask.isDone ? "Completada" : "Pendiente")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(subtask.isDone ? .green : Theme.primary)
                            }

                            Spacer()

                            if let dueDate = subtask.dueDate {
                                VStack(alignment: .trailing, spacing: 2) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 14))
                                    Text(formatDueDate(dueDate))
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundStyle(subtask.isOverdue ? .red : .secondary)
                            }
                        }
                        .padding(16)
                        .background(Color(uiColor: .systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Description/Instructions
                    if let description = subtask.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Instrucciones")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            Text(description)
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Assignees
                    if !subtask.assignees.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(subtask.assignees.count) Asignados")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                ForEach(Array(subtask.assignees.enumerated()), id: \.element.id) { index, assignee in
                                    HStack(spacing: 14) {
                                        Circle()
                                            .fill(Theme.primaryLight)
                                            .frame(width: 44, height: 44)
                                            .overlay {
                                                Text(assignee.avatarInitials)
                                                    .font(.system(size: 14, weight: .bold))
                                                    .foregroundStyle(Theme.primary)
                                            }

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(assignee.displayName)
                                                .font(.system(size: 15, weight: .medium))
                                                .foregroundStyle(.primary)
                                            Text(assignee.phoneNumber)
                                                .font(.system(size: 13))
                                                .foregroundStyle(.secondary)
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                    if index < subtask.assignees.count - 1 {
                                        Divider()
                                            .padding(.leading, 74)
                                    }
                                }
                            }
                            .background(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Attachments
                    if !subtask.instructionAttachments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Adjuntos")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                ForEach(Array(subtask.instructionAttachments.enumerated()), id: \.element.id) { index, attachment in
                                    HStack(spacing: 12) {
                                        Image(systemName: attachment.type == .image ? "photo.fill" : "doc.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(attachment.type == .image ? .blue : .orange)
                                            .frame(width: 36, height: 36)
                                            .background((attachment.type == .image ? Color.blue : Color.orange).opacity(0.15))
                                            .clipShape(RoundedRectangle(cornerRadius: 8))

                                        Text(attachment.fileName)
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.primary)
                                            .lineLimit(1)

                                        Spacer()

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 13))
                                            .foregroundStyle(Color.secondary.opacity(0.5))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)

                                    if index < subtask.instructionAttachments.count - 1 {
                                        Divider()
                                            .padding(.leading, 64)
                                    }
                                }
                            }
                            .background(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(20)
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Info de Subtarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Listo") {
                        dismiss()
                    }
                    .font(.system(size: 16, weight: .semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hoy"
        } else if calendar.isDateInTomorrow(date) {
            return "Mañana"
        } else if calendar.isDateInYesterday(date) {
            return "Ayer"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Subtask Attachment Options Sheet

struct SubtaskAttachmentOptionsSheet: View {
    let subtask: Subtask
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingFilePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .padding(8)
                        .background(Theme.primaryLight)
                        .clipShape(Circle())
                }

                Spacer()

                Text("Agregar a la Discusion")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Color.clear.frame(width: 32, height: 32)
            }
            .padding()

            Divider()

            // Options
            VStack(spacing: 0) {
                // Photos
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "photo.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fotos")
                                .font(.system(size: 16, weight: .medium))
                            Text("Comparte fotos de tu biblioteca")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 76)

                // Documents
                Button {
                    showingFilePicker = true
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "doc.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Documento")
                                .font(.system(size: 16, weight: .medium))
                            Text("Comparte archivos y documentos")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 76)

                // Camera
                Button {
                    // TODO: Open camera
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.green)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Camara")
                                .font(.system(size: 16, weight: .medium))
                            Text("Toma una foto o video")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)
            }
            .background(Color(uiColor: .systemBackground))

            Spacer()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            // Send photos as message with subtask reference
            let taskRef = TaskReference(task: task)
            let subtaskRef = SubtaskReference(subtask: subtask)
            for _ in newItems {
                let attachment = MessageAttachment(
                    type: .image,
                    fileName: "Photo_\(Date().timeIntervalSince1970).jpg"
                )
                let message = Message(
                    content: "Compartio una foto",
                    sender: viewModel.currentUser,
                    isFromCurrentUser: true,
                    referencedTask: taskRef,
                    referencedSubtask: subtaskRef,
                    attachment: attachment
                )
                viewModel.project.messages.append(message)
            }
            MockDataService.shared.updateProject(viewModel.project)
            selectedPhotoItems = []
            dismiss()
        }
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.pdf, .text, .data]) { result in
            switch result {
            case .success(let url):
                let taskRef = TaskReference(task: task)
                let subtaskRef = SubtaskReference(subtask: subtask)
                let attachment = MessageAttachment(
                    type: .document,
                    fileName: url.lastPathComponent
                )
                let message = Message(
                    content: "Compartio un documento",
                    sender: viewModel.currentUser,
                    isFromCurrentUser: true,
                    referencedTask: taskRef,
                    referencedSubtask: subtaskRef,
                    attachment: attachment
                )
                viewModel.project.messages.append(message)
                MockDataService.shared.updateProject(viewModel.project)
                dismiss()
            case .failure:
                break
            }
        }
    }
}

// MARK: - Edit Subtask Sheet (for creator/admin only)

struct EditSubtaskSheet: View {
    let subtask: Subtask
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editedTitle: String = ""
    @State private var editedDescription: String = ""
    @State private var selectedAssigneeIds: Set<UUID> = []
    @State private var dueDate: Date? = nil
    @State private var showingDatePicker = false

    // Assignees limited to task assignees (or all members if no one assigned to task)
    private var availableAssignees: [User] {
        if task.assignees.isEmpty {
            return viewModel.project.members
        }
        return task.assignees
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Titulo")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Titulo de subtarea", text: $editedTitle)
                            .font(.system(size: 17))
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Assignees section
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Asignada a")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            if !selectedAssigneeIds.isEmpty {
                                Text("\(selectedAssigneeIds.count) personas")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.primary)
                            }
                        }

                        if availableAssignees.isEmpty {
                            Text("Nadie asignado a la tarea principal")
                                .font(.system(size: 14))
                                .foregroundStyle(.tertiary)
                                .padding(14)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(uiColor: .secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(availableAssignees) { member in
                                        let isSelected = selectedAssigneeIds.contains(member.id)
                                        Button {
                                            if isSelected {
                                                selectedAssigneeIds.remove(member.id)
                                            } else {
                                                selectedAssigneeIds.insert(member.id)
                                            }
                                        } label: {
                                            HStack(spacing: 4) {
                                                Circle()
                                                    .fill(isSelected ? Color.white.opacity(0.3) : Theme.primaryLight)
                                                    .frame(width: 24, height: 24)
                                                    .overlay {
                                                        Text(member.avatarInitials)
                                                            .font(.system(size: 9, weight: .medium))
                                                            .foregroundStyle(isSelected ? .white : Theme.primary)
                                                    }
                                                Text(member.id == viewModel.currentUser.id ? "Yo" : member.displayFirstName)
                                                    .font(.system(size: 13))

                                                if isSelected {
                                                    Image(systemName: "checkmark")
                                                        .font(.system(size: 10, weight: .bold))
                                                }
                                            }
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 8)
                                            .background(isSelected ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                            .foregroundColor(isSelected ? .white : .primary)
                                            .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Due date section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fecha limite")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        Button {
                            showingDatePicker.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.primary)

                                if let date = dueDate {
                                    Text(formatDueDate(date))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Button {
                                        dueDate = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Establecer fecha limite")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                            }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        if showingDatePicker {
                            DatePicker(
                                "Fecha limite",
                                selection: Binding(
                                    get: { dueDate ?? Date() },
                                    set: { dueDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .tint(Theme.primary)
                        }
                    }

                    // Notes & Instructions section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Notas e Instrucciones")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Agregar detalles, instrucciones o contexto...", text: $editedDescription, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(3...8)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Editar Subtarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                editedTitle = subtask.title
                editedDescription = subtask.description ?? ""
                selectedAssigneeIds = Set(subtask.assignees.map { $0.id })
                dueDate = subtask.dueDate
            }
        }
    }

    private func saveChanges() {
        // Save title
        if !editedTitle.trimmingCharacters(in: .whitespaces).isEmpty && editedTitle != subtask.title {
            viewModel.updateSubtask(in: task, subtask: subtask, newTitle: editedTitle)
        }

        // Save description
        let desc = editedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let newDesc = desc.isEmpty ? nil : desc
        if newDesc != subtask.description {
            viewModel.updateSubtaskDescription(in: task, subtask: subtask, description: newDesc)
        }

        // Save due date
        if dueDate != subtask.dueDate {
            viewModel.updateSubtaskDueDate(in: task, subtask: subtask, dueDate: dueDate)
        }

        // Update assignees (only from available assignees, which are task assignees or all members if none)
        let originalIds = Set(subtask.assignees.map { $0.id })
        for member in availableAssignees {
            let wasSelected = originalIds.contains(member.id)
            let isNowSelected = selectedAssigneeIds.contains(member.id)
            if wasSelected != isNowSelected {
                viewModel.toggleSubtaskAssignee(in: task, subtask: subtask, member: member)
            }
        }
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

// MARK: - Add Subtask Sheet

struct AddSubtaskSheet: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var subtaskTitle = ""
    @State private var description = ""
    @State private var selectedAssigneeIds: Set<UUID> = []
    @State private var dueDate: Date? = nil
    @State private var showingDatePicker = false
    @FocusState private var focusedField: Field?

    // Attachment fields
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var attachments: [SubtaskAttachment] = []

    enum Field: Hashable {
        case title, description
    }

    struct SubtaskAttachment: Identifiable {
        let id = UUID()
        var type: AttachmentType
        var fileName: String
    }

    // Assignees are limited to people assigned to the parent task
    // If no one is assigned to the task, show all project members
    private var availableAssignees: [User] {
        if task.assignees.isEmpty {
            return viewModel.project.members
        }
        return task.assignees
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Subtask title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Subtarea")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Que necesita hacerse?", text: $subtaskTitle)
                            .font(.system(size: 17))
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($focusedField, equals: .title)
                    }

                    // Assignees (limited to task assignees)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Asignar a")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            if task.assignees.isEmpty {
                                Text("(cualquier miembro)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            } else {
                                Text("(de los asignados a la tarea)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        FlowLayout(spacing: 8) {
                            ForEach(availableAssignees) { member in
                                let isSelected = selectedAssigneeIds.contains(member.id)
                                Button {
                                    if isSelected {
                                        selectedAssigneeIds.remove(member.id)
                                    } else {
                                        selectedAssigneeIds.insert(member.id)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(isSelected ? Color.white.opacity(0.3) : Theme.primaryLight)
                                            .frame(width: 28, height: 28)
                                            .overlay {
                                                Text(member.avatarInitials)
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundStyle(isSelected ? .white : Theme.primary)
                                            }
                                        Text(member.id == viewModel.currentUser.id ? "Yo" : member.displayFirstName)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Due date
                    VStack(alignment: .leading, spacing: 8) {
                        Button {
                            showingDatePicker.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.primary)

                                if let date = dueDate {
                                    Text(formatDueDate(date))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.primary)

                                    Button {
                                        dueDate = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Establecer fecha limite")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        if showingDatePicker {
                            DatePicker(
                                "Fecha limite",
                                selection: Binding(
                                    get: { dueDate ?? Date() },
                                    set: { dueDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .tint(Theme.primary)
                        }
                    }

                    // Notes/Instructions with attachment icon
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notas")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            // Attachment menu in notes header
                            Menu {
                                PhotosPicker(
                                    selection: $selectedPhotos,
                                    maxSelectionCount: 10,
                                    matching: .images
                                ) {
                                    Label("Fotos", systemImage: "photo")
                                }

                                Button {
                                    let fileName = "Documento_\(attachments.count + 1).pdf"
                                    attachments.append(SubtaskAttachment(type: .document, fileName: fileName))
                                } label: {
                                    Label("Archivos", systemImage: "doc")
                                }

                                Button {
                                    let contactName = "Contacto_\(attachments.count + 1).vcf"
                                    attachments.append(SubtaskAttachment(type: .contact, fileName: contactName))
                                } label: {
                                    Label("Contactos", systemImage: "person.crop.circle")
                                }
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "paperclip")
                                        .font(.system(size: 14))
                                    if !attachments.isEmpty {
                                        Text("\(attachments.count)")
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                }
                                .foregroundStyle(attachments.isEmpty ? .secondary : Theme.primary)
                            }
                        }

                        TextField("Agregar detalles, instrucciones o contexto...", text: $description, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(4...8)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($focusedField, equals: .description)

                        // Show attachments inline only when added
                        if !attachments.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(attachments) { attachment in
                                        SubtaskAttachmentChip(
                                            attachment: attachment,
                                            onRemove: {
                                                attachments.removeAll { $0.id == attachment.id }
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Nueva Subtarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        createSubtask()
                    }
                    .fontWeight(.semibold)
                    .disabled(subtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                focusedField = .title
            }
            .onChange(of: selectedPhotos) { _, newItems in
                Task {
                    for item in newItems {
                        if let _ = try? await item.loadTransferable(type: Data.self) {
                            let fileName = "Foto_\(attachments.count + 1).jpg"
                            attachments.append(SubtaskAttachment(type: .image, fileName: fileName))
                        }
                    }
                    selectedPhotos = []
                }
            }
        }
    }

    private func createSubtask() {
        let assignees = availableAssignees.filter { selectedAssigneeIds.contains($0.id) }
        let desc = description.trimmingCharacters(in: .whitespacesAndNewlines)

        viewModel.addSubtask(
            to: task,
            title: subtaskTitle,
            description: desc.isEmpty ? nil : desc,
            assignees: assignees,
            dueDate: dueDate
        )
        dismiss()
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hoy"
        } else if calendar.isDateInTomorrow(date) {
            return "Manana"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Task Info Sheet (View-Only)

struct TaskInfoSheet: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingEditSheet = false
    @State private var showingDetailsOverlay = false

    // Comment bar state
    @State private var commentText: String = ""
    @State private var showingAttachmentOptions = false
    @FocusState private var isCommentFocused: Bool

    private var canEdit: Bool {
        viewModel.canEditTask(task)
    }

    // Messages related to this task
    private var taskMessages: [Message] {
        viewModel.project.messages.filter { $0.referencedTask?.taskId == task.id }
    }

    // Status helpers
    private var statusIcon: String {
        if task.status == .done { return "checkmark.circle.fill" }
        if task.isOverdue { return "exclamationmark.circle.fill" }
        return "circle"
    }

    private var statusText: String {
        if task.status == .done { return "Completada" }
        if task.isOverdue { return "Vencida" }
        return "En Progreso"
    }

    private var statusColor: Color {
        if task.status == .done { return .green }
        if task.isOverdue { return .red }
        return .orange
    }

    private var instructionAttachments: [Attachment] {
        task.attachments.filter { $0.isInstruction }
    }

    // Media from task chat
    private var taskPhotos: [MessageAttachment] {
        taskMessages.compactMap { $0.attachment }.filter { $0.type == .image }
    }

    private var taskDocuments: [MessageAttachment] {
        taskMessages.compactMap { $0.attachment }.filter { $0.type == .document }
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                // MARK: - Main Content
                VStack(spacing: 0) {
                    // Compact Header
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(task.title)
                                    .font(.system(size: 20, weight: .bold))
                                    .fixedSize(horizontal: false, vertical: true)

                                // Inline info
                                HStack(spacing: 8) {
                                    HStack(spacing: 4) {
                                        Image(systemName: statusIcon)
                                            .font(.system(size: 10))
                                        Text(statusText)
                                            .font(.system(size: 12, weight: .medium))
                                    }
                                    .foregroundStyle(statusColor)

                                    if task.dueDate != nil || !task.assignees.isEmpty {
                                        Text("·")
                                            .foregroundStyle(.tertiary)
                                    }

                                    if let dueDate = task.dueDate {
                                        Text(formatDueDate(dueDate))
                                            .font(.system(size: 13))
                                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                                    }

                                    if let firstAssignee = task.assignees.first {
                                        if task.dueDate != nil {
                                            Text("·")
                                                .foregroundStyle(.tertiary)
                                        }
                                        Text(firstAssignee.displayFirstName)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                        if task.assignees.count > 1 {
                                            Text("+\(task.assignees.count - 1)")
                                                .font(.system(size: 12))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                            }

                            Spacer()

                            // Info button
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
                    .zIndex(1)

                    Divider()

                    // Chat Area
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
                                    Text("Inicia la conversacion")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.quaternary)
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

                    taskCommentBar
                }

                // MARK: - Details Overlay (slides from top)
                if showingDetailsOverlay {
                    Color.black.opacity(0.3)
                        .ignoresSafeArea()
                        .onTapGesture {
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                                showingDetailsOverlay = false
                            }
                        }
                        .transition(.opacity)

                    VStack(spacing: 0) {
                        // Overlay Header
                        HStack {
                            Text("Detalles de Tarea")
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

                        // Details Content (same as TaskDetailsSheet)
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
                                        if task.isOverdue && task.status != .done {
                                            Text("Vencida")
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundStyle(.red)
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.red.opacity(0.1))
                                                .clipShape(Capsule())
                                        }
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
                                                .foregroundStyle(task.isOverdue ? .red : .primary)
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
                                                    Text(assignee.id == viewModel.currentUser.id ? "Yo" : assignee.displayFirstName)
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
                                            .foregroundStyle(.primary)
                                    }
                                    Divider()
                                }

                                // Attachments
                                if !instructionAttachments.isEmpty {
                                    VStack(alignment: .leading, spacing: 10) {
                                        Text("Adjuntos")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                                            ForEach(instructionAttachments) { attachment in
                                                TaskAttachmentCard(attachment: attachment)
                                            }
                                        }
                                    }
                                    Divider()
                                }

                                // Multimedia y Documentos
                                VStack(alignment: .leading, spacing: 10) {
                                    Text("Multimedia y Documentos")
                                        .font(.system(size: 13, weight: .medium))
                                        .foregroundStyle(.secondary)

                                    VStack(spacing: 0) {
                                        // Fotos row
                                        NavigationLink {
                                            TaskMediaListView(title: "Fotos", attachments: taskPhotos)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: "photo.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(Theme.primary)
                                                    .frame(width: 28, height: 28)
                                                    .background(Theme.primaryLight)
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                                Text("Fotos")
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(.primary)

                                                Spacer()

                                                Text("\(taskPhotos.count)")
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(.secondary)

                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .padding(.vertical, 12)
                                        }

                                        Divider()
                                            .padding(.leading, 48)

                                        // Documentos row
                                        NavigationLink {
                                            TaskMediaListView(title: "Documentos", attachments: taskDocuments)
                                        } label: {
                                            HStack(spacing: 12) {
                                                Image(systemName: "doc.fill")
                                                    .font(.system(size: 14))
                                                    .foregroundStyle(.orange)
                                                    .frame(width: 28, height: 28)
                                                    .background(.orange.opacity(0.15))
                                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                                Text("Documentos")
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(.primary)

                                                Spacer()

                                                Text("\(taskDocuments.count)")
                                                    .font(.system(size: 15))
                                                    .foregroundStyle(.secondary)

                                                Image(systemName: "chevron.right")
                                                    .font(.system(size: 12, weight: .semibold))
                                                    .foregroundStyle(.tertiary)
                                            }
                                            .padding(.vertical, 12)
                                        }
                                    }
                                    .padding(.horizontal, 12)
                                    .background(Color(uiColor: .secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                                Divider()

                                // Created by
                                if let creator = task.createdBy {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("Creada por")
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(.secondary)
                                        HStack(spacing: 8) {
                                            Circle()
                                                .fill(Color.purple.opacity(0.2))
                                                .frame(width: 28, height: 28)
                                                .overlay {
                                                    Text(creator.avatarInitials)
                                                        .font(.system(size: 10, weight: .medium))
                                                        .foregroundStyle(.purple)
                                                }
                                            Text(creator.displayFirstName)
                                                .font(.system(size: 14))
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
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .navigationTitle("Tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Listo") { dismiss() }
                }
                if canEdit {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showingEditSheet = true
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 16))
                                .foregroundStyle(Theme.primary)
                        }
                    }
                }
            }
            .sheet(isPresented: $showingEditSheet) {
                EditTaskSheet(task: task, viewModel: viewModel)
            }
            .onAppear {
                viewModel.markAsRead(task: task)
            }
        }
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

    // MARK: - Comment Input Bar

    private var taskCommentBar: some View {
        HStack(spacing: 8) {
            // Attachment button (+)
            Button {
                showingAttachmentOptions = true
            } label: {
                Image(systemName: "plus.circle.fill")
                    .font(.system(size: 26))
                    .foregroundStyle(Theme.primary)
            }

            // Text field
            TextField("Comentar en esta tarea...", text: $commentText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .focused($isCommentFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendTaskComment()
                }

            // Send button (shows when text entered) or camera/mic buttons
            if !commentText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    sendTaskComment()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.primary)
                }
            } else {
                // Camera button
                Button {
                    // TODO: Open camera for task
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }

                // Mic button
                Button {
                    // TODO: Record audio for task
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
        .sheet(isPresented: $showingAttachmentOptions) {
            TaskAttachmentOptionsSheet(task: task, viewModel: viewModel)
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
    }

    private func sendTaskComment() {
        let trimmedText = commentText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }

        // Send message with task reference
        let taskRef = TaskReference(task: task)
        viewModel.sendMessage(content: trimmedText, referencedTask: taskRef)

        commentText = ""
        isCommentFocused = false
    }
}

// MARK: - Task Comment Bubble

struct TaskCommentBubble: View {
    let message: Message
    @Bindable var viewModel: ProjectChatViewModel

    var body: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                // Name for others only
                if !message.isFromCurrentUser {
                    HStack(spacing: 4) {
                        Text(message.sender.displayFirstName)
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text(message.timestamp, style: .time)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                }

                // Message bubble
                VStack(alignment: .leading, spacing: 6) {
                    // Attachment if any
                    if let attachment = message.attachment {
                        HStack(spacing: 6) {
                            Image(systemName: attachment.type == .image ? "photo.fill" : "doc.fill")
                                .font(.system(size: 14))
                            Text(attachment.fileName)
                                .font(.system(size: 13))
                                .lineLimit(1)
                        }
                        .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.9) : Theme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .background(
                            message.isFromCurrentUser
                                ? Color.white.opacity(0.2)
                                : Theme.primaryLight
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Message content
                    if !message.content.isEmpty {
                        Text(message.content)
                            .font(.system(size: 14))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    message.isFromCurrentUser
                        ? Theme.primary
                        : Color(uiColor: .systemGray5)
                )
                .foregroundStyle(message.isFromCurrentUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 14))

                // Time for current user
                if message.isFromCurrentUser {
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }

            if !message.isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Task Attachment Options Sheet

struct TaskAttachmentOptionsSheet: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var showingFilePicker = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Theme.primary)
                        .padding(8)
                        .background(Theme.primaryLight)
                        .clipShape(Circle())
                }

                Spacer()

                Text("Agregar a la Discusion")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                Color.clear.frame(width: 32, height: 32)
            }
            .padding()

            Divider()

            // Options
            VStack(spacing: 0) {
                // Photos
                PhotosPicker(selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images) {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.blue.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "photo.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fotos")
                                .font(.system(size: 16, weight: .medium))
                            Text("Comparte fotos de tu biblioteca")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 76)

                // Documents
                Button {
                    showingFilePicker = true
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.orange.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "doc.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.orange)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Documento")
                                .font(.system(size: 16, weight: .medium))
                            Text("Comparte archivos y documentos")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)

                Divider()
                    .padding(.leading, 76)

                // Camera
                Button {
                    // TODO: Open camera
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.green.opacity(0.1))
                                .frame(width: 44, height: 44)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 20))
                                .foregroundStyle(.green)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Camara")
                                .font(.system(size: 16, weight: .medium))
                            Text("Toma una foto o video")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                }
                .buttonStyle(.plain)
            }
            .background(Color(uiColor: .systemBackground))

            Spacer()
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .onChange(of: selectedPhotoItems) { _, newItems in
            guard !newItems.isEmpty else { return }
            // Send photos as message with task reference
            let taskRef = TaskReference(task: task)
            for _ in newItems {
                let attachment = MessageAttachment(
                    type: .image,
                    fileName: "Photo_\(Date().timeIntervalSince1970).jpg"
                )
                let message = Message(
                    content: "Compartio una foto",
                    sender: viewModel.currentUser,
                    isFromCurrentUser: true,
                    referencedTask: taskRef,
                    attachment: attachment
                )
                viewModel.project.messages.append(message)
            }
            MockDataService.shared.updateProject(viewModel.project)
            selectedPhotoItems = []
            dismiss()
        }
        .fileImporter(isPresented: $showingFilePicker, allowedContentTypes: [.pdf, .text, .data]) { result in
            switch result {
            case .success(let url):
                let taskRef = TaskReference(task: task)
                let attachment = MessageAttachment(
                    type: .document,
                    fileName: url.lastPathComponent
                )
                let message = Message(
                    content: "Compartio un documento",
                    sender: viewModel.currentUser,
                    isFromCurrentUser: true,
                    referencedTask: taskRef,
                    attachment: attachment
                )
                viewModel.project.messages.append(message)
                MockDataService.shared.updateProject(viewModel.project)
                dismiss()
            case .failure:
                break
            }
        }
    }
}

// MARK: - Edit Task Sheet (for creator/admin only)

struct EditTaskSheet: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var editedTitle: String = ""
    @State private var editedNotes: String = ""
    @State private var selectedAssigneeIds: Set<UUID> = []
    @State private var dueDate: Date? = nil
    @State private var showingDatePicker = false

    // Instruction attachment states
    @State private var selectedPhotos: [PhotosPickerItem] = []

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Title section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Titulo de Tarea")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Titulo de tarea", text: $editedTitle)
                            .font(.system(size: 17))
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    // Assignees section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Asignada a")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            if !selectedAssigneeIds.isEmpty {
                                Text("\(selectedAssigneeIds.count) personas")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Theme.primary)
                            }
                        }

                        FlowLayout(spacing: 8) {
                            ForEach(viewModel.project.members) { member in
                                let isSelected = selectedAssigneeIds.contains(member.id)
                                Button {
                                    if isSelected {
                                        selectedAssigneeIds.remove(member.id)
                                    } else {
                                        selectedAssigneeIds.insert(member.id)
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(isSelected ? Color.white.opacity(0.3) : Theme.primaryLight)
                                            .frame(width: 28, height: 28)
                                            .overlay {
                                                Text(member.avatarInitials)
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundStyle(isSelected ? .white : Theme.primary)
                                            }
                                        Text(member.id == viewModel.currentUser.id ? "Yo" : member.displayFirstName)
                                            .font(.system(size: 14, weight: .medium))
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                    .foregroundStyle(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    // Due date section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fecha limite")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        Button {
                            showingDatePicker.toggle()
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 16))
                                    .foregroundStyle(Theme.primary)

                                if let date = dueDate {
                                    Text(formatDueDate(date))
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Button {
                                        dueDate = nil
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                    }
                                } else {
                                    Text("Establecer fecha limite")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.secondary)
                                    Spacer()
                                }
                            }
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        if showingDatePicker {
                            DatePicker(
                                "Fecha limite",
                                selection: Binding(
                                    get: { dueDate ?? Date() },
                                    set: { dueDate = $0 }
                                ),
                                displayedComponents: .date
                            )
                            .datePickerStyle(.graphical)
                            .tint(Theme.primary)
                        }
                    }

                    // Notes & Instructions section
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Notas e Instrucciones")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Spacer()

                            // Add instruction attachment
                            Menu {
                                PhotosPicker(selection: $selectedPhotos, maxSelectionCount: 10, matching: .images) {
                                    Label("Fotos", systemImage: "photo")
                                }
                                Button {
                                    // Add document
                                } label: {
                                    Label("Documento", systemImage: "doc")
                                }
                            } label: {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }
                        }

                        TextField("Agregar detalles, instrucciones o contexto...", text: $editedNotes, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(4...10)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Existing instruction attachments
                        let instructionAttachments = task.attachments.filter { $0.isInstruction }
                        if !instructionAttachments.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Archivos de referencia (\(instructionAttachments.count))")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.tertiary)

                                LazyVGrid(columns: [GridItem(.adaptive(minimum: 80), spacing: 8)], spacing: 8) {
                                    ForEach(instructionAttachments) { attachment in
                                        TaskAttachmentCard(attachment: attachment, compact: true)
                                    }
                                }
                            }
                        }
                    }

                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Editar Tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        saveChanges()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(editedTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                editedTitle = task.title
                editedNotes = task.notes ?? ""
                selectedAssigneeIds = Set(task.assignees.map { $0.id })
                dueDate = task.dueDate
            }
        }
    }

    private func saveChanges() {
        viewModel.updateTask(
            task,
            title: editedTitle,
            assigneeIds: selectedAssigneeIds,
            dueDate: dueDate,
            notes: editedNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : editedNotes
        )
    }

    private func formatDueDate(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "Hoy"
        } else if calendar.isDateInTomorrow(date) {
            return "Manana"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - Task Details Sheet (shown from info button)

struct TaskDetailsSheet: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    private var instructionAttachments: [Attachment] {
        task.attachments.filter { $0.isInstruction }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status section
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

                            if task.isOverdue && task.status != .done {
                                Text("Vencida")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Capsule())
                            }
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
                                    .foregroundStyle(task.isOverdue ? .red : .primary)
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
                                        Text(assignee.id == viewModel.currentUser.id ? "Yo" : assignee.displayFirstName)
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
                                .foregroundStyle(.primary)
                        }

                        Divider()
                    }

                    // Attachments
                    if !instructionAttachments.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Adjuntos")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                                ForEach(instructionAttachments) { attachment in
                                    TaskAttachmentCard(attachment: attachment)
                                }
                            }
                        }

                        Divider()
                    }

                    // Created by
                    if let creator = task.createdBy {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Creada por")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Text(creator.avatarInitials)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.purple)
                                    }
                                Text(creator.displayFirstName)
                                    .font(.system(size: 14))
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                Text(task.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Detalles de Tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Subtask Details Sheet (shown from info button)

struct SubtaskDetailsSheet: View {
    let subtask: Subtask
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Status section
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Estado")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 12) {
                            Button {
                                viewModel.toggleSubtaskStatus(task, subtask)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: 20))
                                    Text(subtask.isDone ? "Completada" : "Marcar Completa")
                                        .font(.system(size: 15, weight: .medium))
                                }
                                .foregroundStyle(subtask.isDone ? .green : Theme.primary)
                            }

                            Spacer()

                            if subtask.isOverdue && !subtask.isDone {
                                Text("Vencida")
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundStyle(.red)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    Divider()

                    // Parent task
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Parte de")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        HStack(spacing: 8) {
                            Image(systemName: "checklist")
                                .foregroundStyle(Theme.primary)
                            Text(task.title)
                                .font(.system(size: 15))
                        }
                    }

                    Divider()

                    // Due date
                    if let dueDate = subtask.dueDate {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fecha Limite")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                Image(systemName: "calendar")
                                    .foregroundStyle(subtask.isOverdue ? .red : Theme.primary)
                                Text(dueDate.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                                    .font(.system(size: 15))
                                    .foregroundStyle(subtask.isOverdue ? .red : .primary)
                            }
                        }

                        Divider()
                    }

                    // Assignees
                    if !subtask.assignees.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Asignada a")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            FlowLayout(spacing: 8) {
                                ForEach(subtask.assignees) { assignee in
                                    HStack(spacing: 6) {
                                        Circle()
                                            .fill(Theme.primaryLight)
                                            .frame(width: 28, height: 28)
                                            .overlay {
                                                Text(assignee.avatarInitials)
                                                    .font(.system(size: 10, weight: .medium))
                                                    .foregroundStyle(Theme.primary)
                                            }
                                        Text(assignee.id == viewModel.currentUser.id ? "Yo" : assignee.displayFirstName)
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
                    if let description = subtask.description, !description.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Instrucciones")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            Text(description)
                                .font(.system(size: 15))
                                .foregroundStyle(.primary)
                        }

                        Divider()
                    }

                    // Attachments
                    if !subtask.instructionAttachments.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Adjuntos")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 12)], spacing: 12) {
                                ForEach(subtask.instructionAttachments) { attachment in
                                    TaskAttachmentCard(attachment: attachment)
                                }
                            }
                        }

                        Divider()
                    }

                    // Created by
                    if let creator = subtask.createdBy {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Creada por")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            HStack(spacing: 8) {
                                Circle()
                                    .fill(Color.purple.opacity(0.2))
                                    .frame(width: 28, height: 28)
                                    .overlay {
                                        Text(creator.avatarInitials)
                                            .font(.system(size: 10, weight: .medium))
                                            .foregroundStyle(.purple)
                                    }
                                Text(creator.displayFirstName)
                                    .font(.system(size: 14))
                                Text("·")
                                    .foregroundStyle(.tertiary)
                                Text(subtask.createdAt.formatted(.dateTime.month(.abbreviated).day().year()))
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle("Detalles de Subtarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - Task Attachment Card

struct TaskAttachmentCard: View {
    let attachment: Attachment
    var compact: Bool = false

    var body: some View {
        VStack(spacing: compact ? 4 : 6) {
            RoundedRectangle(cornerRadius: compact ? 8 : 10)
                .fill(Color(uiColor: .secondarySystemBackground))
                .frame(height: compact ? 60 : 80)
                .overlay {
                    VStack(spacing: 4) {
                        Image(systemName: iconForType)
                            .font(.system(size: compact ? 22 : 28))
                            .foregroundStyle(colorForType)

                        if !compact {
                            Text(attachment.type.rawValue.capitalized)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }
                }

            if !compact {
                VStack(spacing: 2) {
                    Text(attachment.fileName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Text(attachment.fileSizeFormatted)
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                }
            }
        }
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

// MARK: - Document Row View

struct DocumentRowView: View {
    let attachment: Attachment

    var body: some View {
        HStack(spacing: 10) {
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.orange.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "doc.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.orange)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(attachment.fileSizeFormatted)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Contact Row View

struct ContactRowView: View {
    let attachment: Attachment

    var body: some View {
        HStack(spacing: 10) {
            Circle()
                .fill(Color.green.opacity(0.15))
                .frame(width: 36, height: 36)
                .overlay {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.green)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text(attachment.fileName.replacingOccurrences(of: ".vcf", with: ""))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("Contacto")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(10)
        .background(Color(uiColor: .secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Subtask Attachment Chip (compact inline display)

struct SubtaskAttachmentChip: View {
    let attachment: AddSubtaskSheet.SubtaskAttachment
    let onRemove: () -> Void

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: iconForType)
                .font(.system(size: 12))
                .foregroundStyle(colorForType)

            Text(attachment.fileName)
                .font(.system(size: 12))
                .foregroundStyle(.primary)
                .lineLimit(1)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.tertiary)
            }
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

// MARK: - Deliverable Upload Sheet

struct DeliverableUploadSheet: View {
    let task: DONEOTask
    let attachmentType: AttachmentType
    let itemCount: Int
    @Bindable var viewModel: ProjectChatViewModel
    let onDismiss: () -> Void

    @State private var comment = ""
    @FocusState private var isCommentFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Preview of what's being uploaded
                VStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(colorForType.opacity(0.15))
                            .frame(width: 60, height: 60)

                        Image(systemName: iconForType)
                            .font(.system(size: 26))
                            .foregroundStyle(colorForType)
                    }

                    Text(uploadLabel)
                        .font(.system(size: 17, weight: .medium))

                    Text("para tarea: \(task.title)")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .padding(.top, 20)

                // Comment input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Agregar un comentario (opcional)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.secondary)

                    TextField("Ej., Aqui estan las fotos de la inspeccion de hoy...", text: $comment, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.plain)
                        .padding(14)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .focused($isCommentFocused)
                }
                .padding(.horizontal)

                Spacer()

                // Upload button
                Button {
                    uploadDeliverable()
                } label: {
                    Text("Subir al Chat")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Theme.primary)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal)
                .padding(.bottom, 8)
            }
            .navigationTitle("Subir Entregable")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        onDismiss()
                    }
                }
            }
        }
    }

    private var uploadLabel: String {
        switch attachmentType {
        case .image:
            return itemCount == 1 ? "1 Foto" : "\(itemCount) Fotos"
        case .document:
            return itemCount == 1 ? "1 Documento" : "\(itemCount) Documentos"
        case .video:
            return itemCount == 1 ? "1 Video" : "\(itemCount) Videos"
        case .contact:
            return itemCount == 1 ? "1 Contacto" : "\(itemCount) Contactos"
        }
    }

    private var iconForType: String {
        switch attachmentType {
        case .image: return "photo.fill"
        case .document: return "doc.fill"
        case .video: return "video.fill"
        case .contact: return "person.crop.circle.fill"
        }
    }

    private var colorForType: Color {
        switch attachmentType {
        case .image: return .blue
        case .document: return .orange
        case .video: return .purple
        case .contact: return .green
        }
    }

    private func uploadDeliverable() {
        // Create placeholder items for now (in production, these would be real file URLs)
        let items: [(type: AttachmentType, fileName: String, fileSize: Int64, thumbnailURL: URL?, fileURL: URL?)] = (0..<itemCount).map { index in
            let fileName: String
            switch attachmentType {
            case .image: fileName = "Foto_\(Date().formatted(.dateTime.month().day().hour().minute()))_\(index + 1).jpg"
            case .document: fileName = "Documento_\(index + 1).pdf"
            case .video: fileName = "Video_\(index + 1).mp4"
            case .contact: fileName = "Contacto_\(index + 1).vcf"
            }
            return (type: attachmentType, fileName: fileName, fileSize: Int64.random(in: 100_000...5_000_000), thumbnailURL: nil, fileURL: nil)
        }

        let trimmedComment = comment.trimmingCharacters(in: .whitespaces)
        viewModel.addDeliverablesToTask(
            task,
            items: items,
            comment: trimmedComment.isEmpty ? nil : trimmedComment
        )

        onDismiss()
    }
}

#Preview {
    TaskDrawerDetailView(
        task: DONEOTask(
            title: "Order materials for kitchen",
            assignees: [MockDataService.allUsers[1]],
            status: .pending,
            subtasks: [
                Subtask(title: "Get quotes from 3 suppliers", isDone: true, assignees: [MockDataService.allUsers[1]]),
                Subtask(title: "Compare prices", isDone: false),
                Subtask(title: "Place order", isDone: false)
            ]
        ),
        viewModel: ProjectChatViewModel(project: Project(
            name: "Test Project",
            members: MockDataService.allUsers
        ))
    )
}

// MARK: - Task Media List View

struct TaskMediaListView: View {
    let title: String
    let attachments: [MessageAttachment]

    var body: some View {
        Group {
            if attachments.isEmpty {
                ContentUnavailableView(
                    "Sin \(title)",
                    systemImage: title == "Fotos" ? "photo" : "doc",
                    description: Text("No hay \(title.lowercased()) compartidos en esta tarea")
                )
            } else {
                ScrollView {
                    if title == "Fotos" {
                        // Photo grid
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100), spacing: 2)], spacing: 2) {
                            ForEach(attachments, id: \.id) { attachment in
                                if let imageData = attachment.imageData,
                                   let uiImage = UIImage(data: imageData) {
                                    Image(uiImage: uiImage)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(minWidth: 0, maxWidth: .infinity)
                                        .aspectRatio(1, contentMode: .fill)
                                        .clipped()
                                } else {
                                    Rectangle()
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                        .aspectRatio(1, contentMode: .fill)
                                        .overlay {
                                            Image(systemName: "photo")
                                                .foregroundStyle(.tertiary)
                                        }
                                }
                            }
                        }
                    } else {
                        // Document list
                        VStack(spacing: 0) {
                            ForEach(attachments, id: \.id) { attachment in
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.fill")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.orange)

                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(attachment.fileName)
                                            .font(.system(size: 15))
                                            .lineLimit(1)
                                        Text(formatFileSize(attachment.fileSize))
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                    }

                                    Spacer()

                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12))
                                        .foregroundStyle(.tertiary)
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)

                                if attachment.id != attachments.last?.id {
                                    Divider()
                                        .padding(.leading, 52)
                                }
                            }
                        }
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .padding()
                    }
                }
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}
