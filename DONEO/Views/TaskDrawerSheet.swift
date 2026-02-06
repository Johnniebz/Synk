import SwiftUI
import PhotosUI

struct TaskDrawerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProjectChatViewModel
    @State private var showingAddTask = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Task list
                if viewModel.tasks.isEmpty {
                    emptyStateView
                } else {
                    taskListView
                }

                // Add task button at bottom
                addTaskButton
            }
            .navigationTitle("Tareas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        dismiss()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundStyle(Theme.primary)
                    }
                }
            }
            .sheet(isPresented: $showingAddTask) {
                AddTaskSheet(viewModel: viewModel)
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)

            Text("Sin tareas aun")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Crea tu primera tarea para comenzar")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Task List

    private var taskListView: some View {
        List {
            // Pending tasks
            if !viewModel.pendingTasks.isEmpty {
                Section {
                    ForEach(viewModel.pendingTasks) { task in
                        SimpleTaskRowView(task: task, viewModel: viewModel)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    viewModel.deleteTask(task)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }

                                Button {
                                    viewModel.quoteTask(task)
                                    dismiss()
                                } label: {
                                    Label("Comentar", systemImage: "text.bubble")
                                }
                                .tint(Theme.primary)
                            }
                    }
                } header: {
                    Text("Pendientes (\(viewModel.pendingTasks.count))")
                }
            }

            // Completed tasks
            if !viewModel.completedTasks.isEmpty {
                Section {
                    ForEach(viewModel.completedTasks) { task in
                        SimpleTaskRowView(task: task, viewModel: viewModel)
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    viewModel.deleteTask(task)
                                } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }

                                Button {
                                    viewModel.quoteTask(task)
                                    dismiss()
                                } label: {
                                    Label("Comentar", systemImage: "text.bubble")
                                }
                                .tint(Theme.primary)
                            }
                    }
                } header: {
                    Text("Completadas (\(viewModel.completedTasks.count))")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Add Task Button

    private var addTaskButton: some View {
        Button {
            showingAddTask = true
        } label: {
            HStack {
                Image(systemName: "plus.circle.fill")
                Text("Agregar Tarea")
                    .fontWeight(.semibold)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.primary)
            .foregroundColor(.white)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(uiColor: .systemBackground))
    }
}

// MARK: - Simple Task Row View (no expand/collapse)

struct SimpleTaskRowView: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel

    @State private var showingTaskDetail = false

    private var progress: (completed: Int, total: Int) {
        viewModel.subtaskProgress(for: task)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                viewModel.toggleTaskStatus(task)
            } label: {
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(task.status == .done ? .green : .secondary)
            }
            .buttonStyle(.plain)

            // Task title and info - tappable to open detail
            Button {
                showingTaskDetail = true
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 16))
                        .strikethrough(task.status == .done)
                        .foregroundStyle(task.status == .done ? .secondary : .primary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 8) {
                        // Assignees
                        if !task.assignees.isEmpty {
                            HStack(spacing: -6) {
                                ForEach(task.assignees.prefix(3)) { assignee in
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
                                                .stroke(Color(uiColor: .systemBackground), lineWidth: 1)
                                        )
                                }
                            }

                            let names = task.assignees.prefix(2).map { $0.displayFirstName }
                            let displayText = task.assignees.count > 2
                                ? "\(names.joined(separator: ", ")) +\(task.assignees.count - 2)"
                                : names.joined(separator: ", ")
                            Text(displayText)
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        // Subtask progress
                        if progress.total > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 10))
                                Text("\(progress.completed)/\(progress.total)")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(progress.completed == progress.total ? .green : .secondary)
                        }

                        // Due date
                        if let dueDate = task.dueDate {
                            HStack(spacing: 2) {
                                Image(systemName: "calendar")
                                    .font(.system(size: 10))
                                Text(formatDueDate(dueDate))
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(task.isOverdue ? .red : .secondary)
                        }

                        // Attachments indicator
                        let instructionCount = task.attachments.filter { $0.isInstruction }.count
                        if instructionCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "paperclip")
                                    .font(.system(size: 10))
                                Text("\(instructionCount)")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(Theme.primary)
                        }

                        // Unread comments indicator
                        let unreadCount = viewModel.unreadCount(for: task)
                        if unreadCount > 0 {
                            HStack(spacing: 2) {
                                Image(systemName: "bubble.left.fill")
                                    .font(.system(size: 10))
                                Text("\(unreadCount)")
                                    .font(.system(size: 12))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.primary)
                            .clipShape(Capsule())
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .fullScreenCover(isPresented: $showingTaskDetail) {
            UnifiedTaskDetailView(task: task, viewModel: viewModel)
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

// MARK: - Legacy views kept for compatibility with AddTaskSheet

struct AddSubtaskRowView: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel

    @State private var showingAddSubtask = false

    var body: some View {
        Button {
            showingAddSubtask = true
        } label: {
            HStack(spacing: 10) {
                // Indentation spacer
                Color.clear.frame(width: 20)

                Image(systemName: "plus.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.primary)

                Text("Agregar subtarea")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)

                Spacer()
            }
        }
        .buttonStyle(.plain)
        .padding(.vertical, 4)
        .listRowBackground(Color(uiColor: .secondarySystemGroupedBackground).opacity(0.5))
        .sheet(isPresented: $showingAddSubtask) {
            AddSubtaskSheet(task: task, viewModel: viewModel)
        }
    }
}

// MARK: - Add Task Sheet

struct AddTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProjectChatViewModel

    // Task fields
    @State private var taskTitle = ""
    @State private var selectedAssigneeIds: Set<UUID> = []
    @State private var dueDate: Date? = nil
    @State private var showingDatePicker = false
    @State private var notes = ""
    @State private var subtasks: [NewSubtaskData] = []
    @FocusState private var focusedField: Field?

    // Attachment fields
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @State private var attachments: [NewAttachment] = []
    @State private var showingAttachmentMenu = false
    @State private var showingAddSubtask = false

    enum Field: Hashable {
        case title, notes
    }

    // Helper struct for subtasks being created (with full details)
    struct NewSubtaskData: Identifiable {
        let id = UUID()
        var title: String
        var description: String?
        var assigneeIds: Set<UUID>
        var dueDate: Date?
        var attachments: [NewAttachment]
    }

    // Helper struct for attachments being created
    struct NewAttachment: Identifiable {
        let id = UUID()
        var type: AttachmentType
        var fileName: String
        var data: Data?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Task title
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tarea")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        TextField("Que hay que hacer?", text: $taskTitle)
                            .font(.system(size: 17))
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($focusedField, equals: .title)
                    }

                    // Assignees as chips
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Asignar a")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

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

                    // Notes & Attachments
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
                                    attachments.append(NewAttachment(type: .document, fileName: fileName, data: nil))
                                } label: {
                                    Label("Archivos", systemImage: "doc")
                                }

                                Button {
                                    let contactName = "Contacto_\(attachments.count + 1).vcf"
                                    attachments.append(NewAttachment(type: .contact, fileName: contactName, data: nil))
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

                        TextField("Agregar detalles, instrucciones o contexto...", text: $notes, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(4...8)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($focusedField, equals: .notes)

                        // Show attachments inline only when added
                        if !attachments.isEmpty {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 10) {
                                    ForEach(attachments) { attachment in
                                        AttachmentChip(
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

                    // Subtasks
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Subtareas")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        // Existing subtasks with details
                        ForEach(subtasks) { subtask in
                            HStack(spacing: 12) {
                                Image(systemName: "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(.secondary)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(subtask.title)
                                        .font(.system(size: 15, weight: .medium))

                                    // Subtask details row
                                    HStack(spacing: 8) {
                                        // Assignees
                                        if !subtask.assigneeIds.isEmpty {
                                            let assigneeNames = viewModel.project.members
                                                .filter { subtask.assigneeIds.contains($0.id) }
                                                .prefix(2)
                                                .map { $0.displayFirstName }
                                            HStack(spacing: 4) {
                                                HStack(spacing: -4) {
                                                    ForEach(viewModel.project.members.filter { subtask.assigneeIds.contains($0.id) }.prefix(2)) { member in
                                                        Circle()
                                                            .fill(Theme.primaryLight)
                                                            .frame(width: 16, height: 16)
                                                            .overlay {
                                                                Text(member.avatarInitials)
                                                                    .font(.system(size: 6, weight: .medium))
                                                                    .foregroundStyle(Theme.primary)
                                                            }
                                                    }
                                                }
                                                Text(assigneeNames.joined(separator: ", "))
                                                    .font(.system(size: 11))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }

                                        // Due date
                                        if let date = subtask.dueDate {
                                            HStack(spacing: 3) {
                                                Image(systemName: "calendar")
                                                    .font(.system(size: 9))
                                                Text(formatDueDate(date))
                                                    .font(.system(size: 11))
                                            }
                                            .foregroundStyle(.secondary)
                                        }

                                        // Attachments
                                        if !subtask.attachments.isEmpty {
                                            HStack(spacing: 3) {
                                                Image(systemName: "paperclip")
                                                    .font(.system(size: 9))
                                                Text("\(subtask.attachments.count)")
                                                    .font(.system(size: 11))
                                            }
                                            .foregroundStyle(.secondary)
                                        }
                                    }
                                }

                                Spacer()

                                Button {
                                    subtasks.removeAll { $0.id == subtask.id }
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 18))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }

                        // Add subtask button (opens sheet)
                        Button {
                            showingAddSubtask = true
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: "plus.circle")
                                    .font(.system(size: 18))
                                    .foregroundStyle(Theme.primary)

                                Text("Agregar subtarea")
                                    .font(.system(size: 15))
                                    .foregroundStyle(.secondary)

                                Spacer()
                            }
                            .padding(12)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }
            .navigationTitle("Nueva Tarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Crear") {
                        createTask()
                    }
                    .fontWeight(.semibold)
                    .disabled(taskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
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
                            attachments.append(NewAttachment(type: .image, fileName: fileName, data: nil))
                        }
                    }
                    selectedPhotos = []
                }
            }
            .sheet(isPresented: $showingAddSubtask) {
                AddSubtaskToNewTaskSheet(
                    viewModel: viewModel,
                    taskAssigneeIds: selectedAssigneeIds,
                    onAdd: { subtaskData in
                        subtasks.append(subtaskData)
                    }
                )
            }
        }
    }

    private func createTask() {
        let assignees = viewModel.project.members.filter { selectedAssigneeIds.contains($0.id) }
        let subtaskList = subtasks.map { subtaskData -> Subtask in
            let subtaskAssignees = viewModel.project.members.filter { subtaskData.assigneeIds.contains($0.id) }
            return Subtask(
                title: subtaskData.title,
                description: subtaskData.description,
                assignees: subtaskAssignees,
                dueDate: subtaskData.dueDate,
                createdBy: viewModel.currentUser
            )
        }
        let notesText = notes.trimmingCharacters(in: .whitespacesAndNewlines)

        // Create attachments for the task
        let taskAttachments = attachments.map { att in
            Attachment(
                type: att.type,
                category: .reference,
                fileName: att.fileName,
                fileSize: Int64.random(in: 50000...500000),
                uploadedBy: viewModel.currentUser
            )
        }

        viewModel.addTaskWithAttachments(
            title: taskTitle,
            assignees: assignees,
            subtasks: subtaskList,
            dueDate: dueDate,
            notes: notesText.isEmpty ? nil : notesText,
            attachments: taskAttachments
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

// MARK: - Flow Layout for chips

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrangeSubviews(proposal: proposal, subviews: subviews)
        for (index, frame) in result.frames.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + frame.minX, y: bounds.minY + frame.minY), proposal: .init(frame.size))
        }
    }

    private func arrangeSubviews(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, frames: [CGRect]) {
        let maxWidth = proposal.width ?? .infinity
        var frames: [CGRect] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }

            frames.append(CGRect(origin: CGPoint(x: x, y: y), size: size))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }

        return (CGSize(width: maxWidth, height: y + rowHeight), frames)
    }
}

// MARK: - Attachment Thumbnail

struct AttachmentThumbnail: View {
    let attachment: AddTaskSheet.NewAttachment
    let onRemove: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(uiColor: .secondarySystemBackground))
                    .frame(width: 80, height: 80)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: iconForType)
                                .font(.system(size: 28))
                                .foregroundStyle(colorForType)

                            Text(attachment.type.rawValue.capitalized)
                                .font(.system(size: 9, weight: .medium))
                                .foregroundStyle(.secondary)
                        }
                    }

                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white, Color.red)
                }
                .offset(x: 8, y: -8)
            }

            Text(attachment.fileName)
                .font(.system(size: 10))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(width: 80)
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

// MARK: - Attachment Chip (compact inline display)

struct AttachmentChip: View {
    let attachment: AddTaskSheet.NewAttachment
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

// MARK: - Add Subtask Sheet (for new task creation)

struct AddSubtaskToNewTaskSheet: View {
    @Bindable var viewModel: ProjectChatViewModel
    let taskAssigneeIds: Set<UUID>
    let onAdd: (AddTaskSheet.NewSubtaskData) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var title = ""
    @State private var description = ""
    @State private var selectedAssigneeIds: Set<UUID> = []
    @State private var dueDate: Date? = nil
    @State private var showingDatePicker = false
    @State private var attachments: [AddTaskSheet.NewAttachment] = []
    @State private var selectedPhotos: [PhotosPickerItem] = []
    @FocusState private var focusedField: Field?

    enum Field: Hashable {
        case title, description
    }

    // Available assignees - from task assignees or all members if none selected
    private var availableAssignees: [User] {
        if taskAssigneeIds.isEmpty {
            return viewModel.project.members
        }
        return viewModel.project.members.filter { taskAssigneeIds.contains($0.id) }
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

                        TextField("Que hay que hacer?", text: $title)
                            .font(.system(size: 17))
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .focused($focusedField, equals: .title)
                    }

                    // Assignees
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Asignar a")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            if !taskAssigneeIds.isEmpty {
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

                    // Notes/Description with attachment icon
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
                                    attachments.append(AddTaskSheet.NewAttachment(type: .document, fileName: fileName, data: nil))
                                } label: {
                                    Label("Archivos", systemImage: "doc")
                                }

                                Button {
                                    let contactName = "Contacto_\(attachments.count + 1).vcf"
                                    attachments.append(AddTaskSheet.NewAttachment(type: .contact, fileName: contactName, data: nil))
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
                                        AttachmentChip(
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
                    Button("Agregar") {
                        let subtaskData = AddTaskSheet.NewSubtaskData(
                            title: title,
                            description: description.isEmpty ? nil : description,
                            assigneeIds: selectedAssigneeIds,
                            dueDate: dueDate,
                            attachments: attachments
                        )
                        onAdd(subtaskData)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
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
                            attachments.append(AddTaskSheet.NewAttachment(type: .image, fileName: fileName, data: nil))
                        }
                    }
                    selectedPhotos = []
                }
            }
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

#Preview {
    TaskDrawerSheet(viewModel: ProjectChatViewModel(project: Project(
        name: "Proyecto de Prueba",
        members: MockDataService.allUsers,
        tasks: [
            DONEOTask(
                title: "Pedir materiales para cocina",
                assignees: [MockDataService.allUsers[1]],
                status: .pending,
                subtasks: [
                    Subtask(title: "Obtener cotizaciones", isDone: true),
                    Subtask(title: "Comparar precios", isDone: false)
                ]
            ),
            DONEOTask(title: "Programar inspeccion", status: .done)
        ]
    )))
}
