import SwiftUI
import PhotosUI
import AVFoundation
import ContactsUI

struct ProjectChatView: View {
    @State private var viewModel: ProjectChatViewModel
    @State private var showingProjectInfo = false
    @State private var showingAddTask = false
    @State private var showingNewTasksInbox = false
    @State private var selectedTask: DONEOTask? = nil
    @Environment(\.dismiss) private var dismiss

    init(project: Project) {
        _viewModel = State(initialValue: ProjectChatViewModel(project: project))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Task list with activity previews
            if viewModel.tasks.isEmpty {
                emptyStateView
            } else {
                taskListView
            }

            // Add task button at bottom
            addTaskButton
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                headerView
            }
            ToolbarItem(placement: .topBarTrailing) {
                if viewModel.newTasksCount > 0 {
                    Button {
                        showingNewTasksInbox = true
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            Image(systemName: "bell.fill")
                                .font(.system(size: 18))
                                .foregroundStyle(Theme.primary)
                                .padding(.trailing, 6)

                            Text("\(viewModel.newTasksCount)")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(.orange)
                                .clipShape(Capsule())
                                .offset(x: 2, y: -4)
                        }
                    }
                }
            }
        }
        .toolbar(.hidden, for: .tabBar)
        .sheet(isPresented: $showingProjectInfo) {
            ProjectInfoView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingNewTasksInbox) {
            ProjectNewTasksInboxSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingAddTask) {
            AddTaskSheet(viewModel: viewModel)
        }
        .fullScreenCover(item: $selectedTask) { task in
            UnifiedTaskDetailView(task: task, viewModel: viewModel)
        }
    }

    // MARK: - Header

    private var headerView: some View {
        Button {
            showingProjectInfo = true
        } label: {
            VStack(spacing: 1) {
                Text(viewModel.project.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text("\(viewModel.project.members.count) miembros")
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "checklist")
                .font(.system(size: 56))
                .foregroundStyle(Color.secondary.opacity(0.3))

            Text("Sin tareas aún")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.secondary)

            Text("Crea tu primera tarea para comenzar\na colaborar con tu equipo")
                .font(.system(size: 15))
                .foregroundStyle(Color.secondary.opacity(0.7))
                .multilineTextAlignment(.center)

            Spacer()
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Task List

    private var taskListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                // Pending tasks
                if !viewModel.pendingTasks.isEmpty {
                    ForEach(viewModel.pendingTasks.sorted { task1, task2 in
                        // Sort by most recent activity
                        let date1 = lastActivityDate(for: task1)
                        let date2 = lastActivityDate(for: task2)
                        return date1 > date2
                    }) { task in
                        TaskActivityRow(
                            task: task,
                            viewModel: viewModel,
                            onTap: {
                                selectedTask = task
                            }
                        )
                    }
                }

                // Completed tasks section
                if !viewModel.completedTasks.isEmpty {
                    HStack {
                        Text("Completadas")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 24)
                    .padding(.bottom, 8)

                    ForEach(viewModel.completedTasks) { task in
                        TaskActivityRow(
                            task: task,
                            viewModel: viewModel,
                            onTap: {
                                selectedTask = task
                            }
                        )
                    }
                }
            }
            .padding(.top, 8)
        }
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
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
    }

    // MARK: - Helpers

    private func lastActivityDate(for task: DONEOTask) -> Date {
        // Get the most recent message for this task
        let taskMessages = viewModel.project.messages.filter { message in
            if message.referencedTask?.taskId == task.id { return true }
            if let subtaskRef = message.referencedSubtask,
               task.subtasks.contains(where: { $0.id == subtaskRef.subtaskId }) {
                return true
            }
            return false
        }
        return taskMessages.map { $0.timestamp }.max() ?? task.createdAt
    }
}

// MARK: - Task Activity Row

struct TaskActivityRow: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    let onTap: () -> Void

    // Get latest message for this task
    private var latestMessage: Message? {
        viewModel.project.messages
            .filter { message in
                if message.referencedTask?.taskId == task.id { return true }
                if let subtaskRef = message.referencedSubtask,
                   task.subtasks.contains(where: { $0.id == subtaskRef.subtaskId }) {
                    return true
                }
                return false
            }
            .sorted { $0.timestamp > $1.timestamp }
            .first
    }

    // Check if there are unread messages
    private var hasUnread: Bool {
        let taskMessages = viewModel.project.messages.filter { message in
            if message.referencedTask?.taskId == task.id { return true }
            if let subtaskRef = message.referencedSubtask,
               task.subtasks.contains(where: { $0.id == subtaskRef.subtaskId }) {
                return true
            }
            return false
        }
        return taskMessages.contains { !$0.isRead(by: viewModel.currentUser.id) }
    }

    // Unread count
    private var unreadCount: Int {
        viewModel.unreadCount(for: task)
    }

    // Subtask progress
    private var progress: (completed: Int, total: Int) {
        viewModel.subtaskProgress(for: task)
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                // Checkbox
                Image(systemName: task.status == .done ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 24))
                    .foregroundStyle(task.status == .done ? .green : Color.secondary.opacity(0.4))

                // Content
                VStack(alignment: .leading, spacing: 4) {
                    // Task title row
                    HStack {
                        Text(task.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(task.status == .done ? .secondary : .primary)
                            .lineLimit(1)

                        Spacer()

                        // Time
                        if let message = latestMessage {
                            Text(formatTime(message.timestamp))
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Preview row
                    HStack(spacing: 6) {
                        // Latest message preview
                        if let message = latestMessage {
                            Text("\(message.sender.displayFirstName):")
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)

                            Text(message.content)
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondary.opacity(0.8))
                                .lineLimit(1)
                        } else {
                            Text("Sin mensajes")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.secondary.opacity(0.5))
                                .italic()
                        }

                        Spacer()

                        // Subtask progress
                        if progress.total > 0 {
                            HStack(spacing: 3) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 11))
                                Text("\(progress.completed)/\(progress.total)")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundStyle(progress.completed == progress.total ? .green : .secondary)
                        }

                        // Unread badge
                        if unreadCount > 0 {
                            Text("\(unreadCount)")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Theme.primary)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(Color(uiColor: .systemBackground))
        }
        .buttonStyle(.plain)

        // Divider
        Divider()
            .padding(.leading, 54)
    }

    private func formatTime(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(.dateTime.hour().minute())
        } else if calendar.isDateInYesterday(date) {
            return "Ayer"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            return date.formatted(.dateTime.weekday(.abbreviated))
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

#Preview {
    NavigationStack {
        ProjectChatView(project: Project(
            name: "Renovacion Centro",
            members: MockDataService.allUsers,
            tasks: [
                DONEOTask(
                    title: "Pedir materiales para cocina",
                    assignees: [MockDataService.allUsers[0]],
                    status: .pending,
                    subtasks: [
                        Subtask(title: "Obtener cotizaciones", isDone: true),
                        Subtask(title: "Comparar precios", isDone: false)
                    ]
                ),
                DONEOTask(
                    title: "Coordinar con inspector",
                    assignees: [MockDataService.allUsers[1]],
                    status: .pending
                ),
                DONEOTask(
                    title: "Pintar paredes",
                    status: .done
                )
            ]
        ))
    }
}
struct ProjectInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: ProjectChatViewModel

    var body: some View {
        NavigationStack {
            List {
                // Project header
                Section {
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Theme.primaryLight)
                                .frame(width: 80, height: 80)
                            Text(viewModel.project.initials)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(Theme.primary)
                        }

                        Text(viewModel.project.name)
                            .font(.system(size: 20, weight: .bold))
                            .multilineTextAlignment(.center)

                        if let description = viewModel.project.description {
                            Text(description)
                                .font(.system(size: 14))
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        // Task stats
                        HStack(spacing: 24) {
                            VStack {
                                Text("\(viewModel.pendingTasks.count)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(Theme.primary)
                                Text("Pendientes")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }

                            VStack {
                                Text("\(viewModel.completedTasks.count)")
                                    .font(.system(size: 20, weight: .bold))
                                    .foregroundStyle(.green)
                                Text("Completadas")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.top, 8)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                // Notifications section
                Section {
                    Toggle(isOn: $viewModel.isMuted) {
                        Label("Silenciar Notificaciones", systemImage: "bell.slash")
                    }
                }

                // Members section
                Section {
                    ForEach(viewModel.project.members) { member in
                        HStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(Theme.primary)
                                    .frame(width: 40, height: 40)
                                Text(member.avatarInitials)
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(member.name)
                                        .font(.system(size: 16))
                                    if member.id == viewModel.currentUser.id {
                                        Text("Tu")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Text(member.phoneNumber)
                                    .font(.system(size: 13))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("\(viewModel.project.members.count) Miembros")
                }

                // Media & Documents section
                if !viewModel.project.attachments.isEmpty {
                    Section {
                        // Photos
                        let photos = viewModel.project.attachments.filter { $0.type == .image }
                        if !photos.isEmpty {
                            NavigationLink {
                                mediaListView(title: "Fotos", attachments: photos)
                            } label: {
                                HStack {
                                    Label("Fotos", systemImage: "photo.fill")
                                    Spacer()
                                    Text("\(photos.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Documents
                        let documents = viewModel.project.attachments.filter { $0.type == .document }
                        if !documents.isEmpty {
                            NavigationLink {
                                mediaListView(title: "Documentos", attachments: documents)
                            } label: {
                                HStack {
                                    Label("Documentos", systemImage: "doc.fill")
                                    Spacer()
                                    Text("\(documents.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        // Videos
                        let videos = viewModel.project.attachments.filter { $0.type == .video }
                        if !videos.isEmpty {
                            NavigationLink {
                                mediaListView(title: "Videos", attachments: videos)
                            } label: {
                                HStack {
                                    Label("Videos", systemImage: "video.fill")
                                    Spacer()
                                    Text("\(videos.count)")
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    } header: {
                        Text("Multimedia y Documentos")
                    }
                }

                // Actions section
                Section {
                    Button {
                        // Export project
                    } label: {
                        Label("Exportar Proyecto", systemImage: "square.and.arrow.up")
                    }

                    Button {
                        // Copy link
                    } label: {
                        Label("Copiar Enlace", systemImage: "link")
                    }
                }

                // Danger zone
                Section {
                    Button(role: .destructive) {
                        // Leave project
                    } label: {
                        Label("Abandonar Proyecto", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Info del Proyecto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Media List View

    private func mediaListView(title: String, attachments: [ProjectAttachment]) -> some View {
        List {
            // Group by task
            let grouped = Dictionary(grouping: attachments) { $0.linkedTaskId }

            ForEach(Array(grouped.keys), id: \.self) { taskId in
                Section {
                    ForEach(grouped[taskId] ?? []) { attachment in
                        mediaRow(attachment)
                    }
                } header: {
                    if let taskId = taskId,
                       let task = viewModel.project.tasks.first(where: { $0.id == taskId }) {
                        Label(task.title, systemImage: "checklist")
                    } else {
                        Text("General")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private func mediaRow(_ attachment: ProjectAttachment) -> some View {
        HStack(spacing: 12) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Theme.primaryLight)
                    .frame(width: 50, height: 50)

                Image(systemName: attachment.iconName)
                    .font(.system(size: 20))
                    .foregroundStyle(Theme.primary)
            }

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(attachment.fileName)
                    .font(.system(size: 15, weight: .medium))
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(attachment.uploadedBy.displayFirstName)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    Text(attachment.uploadedAt, style: .date)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)

                    if attachment.fileSize > 0 {
                        Text(attachment.fileSizeFormatted)
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Project Attachment Sheet

struct ProjectAttachmentSheet: View {
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab: AttachmentTab = .photos
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var loadedImages: [UIImage] = []
    @State private var selectedFiles: [(url: URL, name: String, size: Int64)] = []
    @State private var showingUploadDetails = false
    @State private var showingFilePicker = false

    enum AttachmentTab: String, CaseIterable {
        case photos = "Fotos"
        case files = "Archivos"
        case contact = "Contacto"

        var icon: String {
            switch self {
            case .photos: return "photo.fill"
            case .files: return "doc.fill"
            case .contact: return "person.crop.square.fill"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            // Content based on selected tab
            tabContent

            // Tab bar
            tabBar
        }
        .sheet(isPresented: $showingUploadDetails) {
            AttachmentUploadSheet(
                viewModel: viewModel,
                selectedImages: loadedImages,
                selectedFiles: selectedFiles
            ) {
                selectedPhotoItems = []
                loadedImages = []
                selectedFiles = []
                dismiss()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
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

            Text(headerTitle)
                .font(.system(size: 16, weight: .semibold))

            Spacer()

            // Next/Send button (only show when photos selected)
            if !selectedPhotoItems.isEmpty {
                Button {
                    showingUploadDetails = true
                } label: {
                    Text("Siguiente (\(selectedPhotoItems.count))")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                }
            } else {
                Color.clear.frame(width: 32, height: 32)
            }
        }
        .padding(.horizontal)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    private var headerTitle: String {
        switch selectedTab {
        case .photos: return "Recientes"
        case .files: return "Archivos"
        case .contact: return "Contactos"
        }
    }

    // MARK: - Tab Content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .photos:
            photosContent
        case .files:
            filesContent
        case .contact:
            contactContent
        }
    }

    // MARK: - Photos Content

    private var photosContent: some View {
        VStack(spacing: 0) {
            // Selected photos preview
            if !loadedImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(loadedImages.indices, id: \.self) { index in
                            Image(uiImage: loadedImages[index])
                                .resizable()
                                .scaledToFill()
                                .frame(width: 80, height: 80)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .overlay(alignment: .topTrailing) {
                                    Button {
                                        loadedImages.remove(at: index)
                                        if index < selectedPhotoItems.count {
                                            selectedPhotoItems.remove(at: index)
                                        }
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .font(.system(size: 20))
                                            .foregroundStyle(.white)
                                            .shadow(radius: 2)
                                    }
                                    .padding(4)
                                }
                        }
                    }
                    .padding()
                }
                .background(Color(uiColor: .secondarySystemBackground))
            }

            // PhotosPicker
            PhotosPicker(
                selection: $selectedPhotoItems,
                maxSelectionCount: 10,
                matching: .images,
                photoLibrary: .shared()
            ) {
                VStack(spacing: 16) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 48))
                        .foregroundStyle(Theme.primary.opacity(0.6))

                    Text("Seleccionar Fotos")
                        .font(.system(size: 18, weight: .semibold))

                    Text("Elige fotos de tu biblioteca")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 8) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 16))
                        Text(selectedPhotoItems.isEmpty ? "Toca para seleccionar" : "\(selectedPhotoItems.count) seleccionadas")
                            .font(.system(size: 15, weight: .medium))
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Theme.primary)
                    .clipShape(Capsule())
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .onChange(of: selectedPhotoItems) { _, newItems in
                loadImages(from: newItems)
            }
        }
    }

    private func loadImages(from items: [PhotosPickerItem]) {
        loadedImages = []
        for item in items {
            item.loadTransferable(type: Data.self) { result in
                switch result {
                case .success(let data):
                    if let data = data, let image = UIImage(data: data) {
                        DispatchQueue.main.async {
                            if !loadedImages.contains(where: { $0.pngData() == image.pngData() }) {
                                loadedImages.append(image)
                            }
                        }
                    }
                case .failure:
                    break
                }
            }
        }
    }

    // MARK: - Files Content

    private var filesContent: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.primary.opacity(0.6))

                Text("Explorar Archivos")
                    .font(.system(size: 18, weight: .semibold))

                Text("Selecciona documentos, PDFs u otros archivos")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    showingFilePicker = true
                } label: {
                    Text("Elegir Archivo")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.pdf, .text, .data, .spreadsheet, .presentation],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                // Store selected files and show upload sheet for tagging
                selectedFiles = urls.compactMap { url in
                    let accessing = url.startAccessingSecurityScopedResource()
                    let fileName = url.lastPathComponent
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64) ?? 0
                    if accessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                    return (url: url, name: fileName, size: fileSize)
                }
                // Show upload sheet for tagging
                if !selectedFiles.isEmpty {
                    showingUploadDetails = true
                }
            case .failure:
                break
            }
        }
    }

    // MARK: - Contact Content

    private var contactContent: some View {
        VStack(spacing: 16) {
            Spacer()

            VStack(spacing: 16) {
                Image(systemName: "person.crop.circle.badge.plus")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.primary.opacity(0.6))

                Text("Compartir Contacto")
                    .font(.system(size: 18, weight: .semibold))

                Text("Comparte una tarjeta de contacto con tu equipo")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                Button {
                    // Open contact picker
                } label: {
                    Text("Elegir Contacto")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                }
                .padding(.top, 8)
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(AttachmentTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 22))
                        Text(tab.rawValue)
                            .font(.system(size: 11))
                    }
                    .frame(maxWidth: .infinity)
                    .foregroundStyle(selectedTab == tab ? Theme.primary : .secondary)
                }
            }
        }
        .padding(.vertical, 12)
        .background(Color(uiColor: .systemBackground))
        .overlay(alignment: .top) {
            Divider()
        }
    }
}

// MARK: - Attachment Upload Sheet (Link to Task)

struct AttachmentUploadSheet: View {
    @Bindable var viewModel: ProjectChatViewModel
    let selectedImages: [UIImage]
    let selectedFiles: [(url: URL, name: String, size: Int64)]
    let onComplete: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTaskId: UUID? = nil
    @State private var selectedSubtaskId: UUID? = nil
    @State private var caption: String = ""

    var selectedCount: Int { selectedImages.count + selectedFiles.count }
    var hasImages: Bool { !selectedImages.isEmpty }
    var hasFiles: Bool { !selectedFiles.isEmpty }

    private var selectedTask: DONEOTask? {
        viewModel.project.tasks.first { $0.id == selectedTaskId }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // Preview
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Seleccionado")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // Show images
                                ForEach(selectedImages.indices.prefix(4), id: \.self) { index in
                                    Image(uiImage: selectedImages[index])
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 60, height: 60)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                }

                                // Show files
                                ForEach(selectedFiles.indices.prefix(4), id: \.self) { index in
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Theme.primaryLight)
                                        .frame(width: 60, height: 60)
                                        .overlay {
                                            VStack(spacing: 2) {
                                                Image(systemName: "doc.fill")
                                                    .font(.system(size: 20))
                                                    .foregroundStyle(Theme.primary)
                                                Text(selectedFiles[index].name)
                                                    .font(.system(size: 8))
                                                    .foregroundStyle(.secondary)
                                                    .lineLimit(1)
                                            }
                                            .padding(4)
                                        }
                                }

                                if selectedCount > 4 {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(uiColor: .secondarySystemBackground))
                                        .frame(width: 60, height: 60)
                                        .overlay {
                                            Text("+\(selectedCount - 4)")
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(.secondary)
                                        }
                                }
                            }
                        }
                    }

                    // Link to task (optional)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Vincular a tarea")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("(opcional)")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }

                        // Task picker
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                // No link option
                                Button {
                                    selectedTaskId = nil
                                    selectedSubtaskId = nil
                                } label: {
                                    Text("Ninguna")
                                        .font(.system(size: 14, weight: .medium))
                                        .padding(.horizontal, 14)
                                        .padding(.vertical, 8)
                                        .background(selectedTaskId == nil ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                        .foregroundStyle(selectedTaskId == nil ? .white : .primary)
                                        .clipShape(Capsule())
                                }

                                ForEach(viewModel.project.tasks) { task in
                                    Button {
                                        selectedTaskId = task.id
                                        selectedSubtaskId = nil
                                    } label: {
                                        Text(task.title)
                                            .font(.system(size: 14, weight: .medium))
                                            .lineLimit(1)
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedTaskId == task.id ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                            .foregroundStyle(selectedTaskId == task.id ? .white : .primary)
                                            .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }

                    // Link to subtask (if task selected)
                    if let task = selectedTask, !task.subtasks.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Vincular a subtarea")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundStyle(.secondary)
                                Text("(opcional)")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.tertiary)
                            }

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Button {
                                        selectedSubtaskId = nil
                                    } label: {
                                        Text("Ninguna")
                                            .font(.system(size: 14, weight: .medium))
                                            .padding(.horizontal, 14)
                                            .padding(.vertical, 8)
                                            .background(selectedSubtaskId == nil ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                            .foregroundStyle(selectedSubtaskId == nil ? .white : .primary)
                                            .clipShape(Capsule())
                                    }

                                    ForEach(task.subtasks) { subtask in
                                        Button {
                                            selectedSubtaskId = subtask.id
                                        } label: {
                                            Text(subtask.title)
                                                .font(.system(size: 14, weight: .medium))
                                                .lineLimit(1)
                                                .padding(.horizontal, 14)
                                                .padding(.vertical, 8)
                                                .background(selectedSubtaskId == subtask.id ? Theme.primary : Color(uiColor: .secondarySystemBackground))
                                                .foregroundStyle(selectedSubtaskId == subtask.id ? .white : .primary)
                                                .clipShape(Capsule())
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Caption
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Descripcion")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)
                            Text("(opcional)")
                                .font(.system(size: 11))
                                .foregroundStyle(.tertiary)
                        }

                        TextField("Agregar una descripcion...", text: $caption, axis: .vertical)
                            .font(.system(size: 15))
                            .lineLimit(2...4)
                            .padding(14)
                            .background(Color(uiColor: .secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding()
            }
            .navigationTitle("Agregar Detalles")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Enviar") {
                        // Create attachment items from images
                        var items: [(type: AttachmentType, fileName: String, fileSize: Int64, fileURL: URL?)] = selectedImages.enumerated().map { index, _ in
                            (type: .image, fileName: "Photo_\(Date().timeIntervalSince1970)_\(index).jpg", fileSize: 0, fileURL: nil)
                        }

                        // Add file items
                        items += selectedFiles.map { file in
                            (type: .document, fileName: file.name, fileSize: file.size, fileURL: file.url)
                        }

                        viewModel.addAttachments(
                            items: items,
                            linkedTaskId: selectedTaskId,
                            linkedSubtaskId: selectedSubtaskId,
                            caption: caption.isEmpty ? nil : caption
                        )

                        dismiss()
                        onComplete()
                    }
                    .fontWeight(.semibold)
                    .disabled(selectedCount == 0)
                }
            }
        }
    }
}

// MARK: - New Tasks Inbox Sheet

struct ProjectNewTasksInboxSheet: View {
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTask: DONEOTask?
    @State private var showTaskDetail = false

    var body: some View {
        NavigationStack {
            Group {
                if viewModel.newTasksForCurrentUser.isEmpty {
                    ContentUnavailableView(
                        "Todo al Dia",
                        systemImage: "tray",
                        description: Text("Sin nuevas asignaciones de tareas")
                    )
                } else {
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(viewModel.newTasksForCurrentUser) { task in
                                NewTaskInboxRow(task: task) {
                                    selectedTask = task
                                    showTaskDetail = true
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("Nuevas Tareas")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Listo") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showTaskDetail) {
                if let task = selectedTask {
                    NewTaskInboxDetailSheet(
                        task: task,
                        projectName: viewModel.project.name,
                        viewModel: viewModel,
                        onAccept: {
                            viewModel.acceptTask(task, message: nil)
                            showTaskDetail = false
                            selectedTask = nil
                        },
                        onCancel: {
                            showTaskDetail = false
                            selectedTask = nil
                        }
                    )
                }
            }
        }
    }
}

// MARK: - New Task Inbox Row

struct NewTaskInboxRow: View {
    let task: DONEOTask
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Blue indicator dot
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(task.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)

                        if task.isOverdue {
                            Text("VENCIDA")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.red)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        } else if task.isDueToday {
                            Text("HOY")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2)
                                .background(.orange)
                                .clipShape(RoundedRectangle(cornerRadius: 3))
                        }
                    }

                    HStack(spacing: 6) {
                        if let createdBy = task.createdBy {
                            Text("de \(createdBy.displayFirstName)")
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        if let dueDate = task.dueDate, !task.isOverdue && !task.isDueToday {
                            if task.createdBy != nil {
                                Text("•")
                                    .foregroundStyle(.tertiary)
                            }
                            Text(formatDueDate(dueDate))
                                .font(.system(size: 12))
                                .foregroundStyle(.secondary)
                        }

                        if !task.subtasks.isEmpty {
                            if task.createdBy != nil || task.dueDate != nil {
                                Text("•")
                                    .foregroundStyle(.tertiary)
                            }
                            HStack(spacing: 3) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 10))
                                Text("\(task.subtasks.count)")
                                    .font(.system(size: 11))
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding()
            .background(Color(uiColor: .systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private func formatDueDate(_ date: Date) -> String {
        if Calendar.current.isDateInTomorrow(date) {
            return "Manana"
        } else {
            return date.formatted(.dateTime.month(.abbreviated).day())
        }
    }
}

// MARK: - New Task Inbox Detail Sheet

struct NewTaskInboxDetailSheet: View {
    let task: DONEOTask
    let projectName: String
    @Bindable var viewModel: ProjectChatViewModel
    let onAccept: () -> Void
    let onCancel: () -> Void

    @State private var commentText = ""
    @FocusState private var isCommentFocused: Bool

    // Messages related to this task (for assignment discussion)
    private var assignmentMessages: [Message] {
        viewModel.project.messages.filter { message in
            message.referencedTask?.taskId == task.id
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        // Task header
                        VStack(alignment: .leading, spacing: 8) {
                            Text(task.title)
                                .font(.system(size: 20, weight: .semibold))

                            HStack(spacing: 8) {
                                if let createdBy = task.createdBy {
                                    Label("de \(createdBy.displayFirstName)", systemImage: "person")
                                        .font(.system(size: 13))
                                        .foregroundStyle(.secondary)
                                }

                                if let dueDate = task.dueDate {
                                    Label(dueDate.formatted(.dateTime.month(.abbreviated).day()), systemImage: "calendar")
                                        .font(.system(size: 13))
                                        .foregroundStyle(task.isOverdue ? .red : (task.isDueToday ? .orange : .secondary))
                                }
                            }
                        }
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Notes section
                        if let notes = task.notes, !notes.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("Notas", systemImage: "doc.text")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)

                                Text(notes)
                                    .font(.system(size: 15))
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Subtasks section
                        if !task.subtasks.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("\(task.subtasks.count) Subtareas", systemImage: "checklist")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.secondary)

                                ForEach(task.subtasks) { subtask in
                                    HStack(spacing: 8) {
                                        Image(systemName: "circle")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.tertiary)
                                        Text(subtask.title)
                                            .font(.system(size: 14))
                                            .foregroundStyle(.primary)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(uiColor: .secondarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Accept button
                        Button {
                            onAccept()
                        } label: {
                            Text("Aceptar Tarea")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.green)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }

                        // Discussion section header
                        HStack {
                            Text("Discusion")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundStyle(.secondary)

                            if !assignmentMessages.isEmpty {
                                Text("(\(assignmentMessages.count))")
                                    .font(.system(size: 13))
                                    .foregroundStyle(.tertiary)
                            }
                        }

                        // Chat area with background
                        VStack(spacing: 0) {
                            if assignmentMessages.isEmpty {
                                HStack {
                                    Spacer()
                                    VStack(spacing: 8) {
                                        Image(systemName: "bubble.left.and.bubble.right")
                                            .font(.system(size: 28))
                                            .foregroundStyle(.tertiary)
                                        Text("Sin comentarios aun")
                                            .font(.system(size: 14))
                                            .foregroundStyle(.secondary)
                                        Text("Haz preguntas o discute detalles abajo")
                                            .font(.system(size: 12))
                                            .foregroundStyle(.tertiary)
                                    }
                                    .padding(.vertical, 40)
                                    Spacer()
                                }
                            } else {
                                VStack(spacing: 8) {
                                    ForEach(assignmentMessages) { message in
                                        AssignmentChatBubble(message: message)
                                    }
                                }
                                .padding(.vertical, 12)
                                .padding(.horizontal, 8)
                            }

                            Spacer(minLength: 60) // Space for input bar
                        }
                        .frame(maxWidth: .infinity)
                        .background(Color(uiColor: .systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                }

                // Comment input bar at bottom
                assignmentCommentBar
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(projectName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") {
                        onCancel()
                    }
                }
            }
        }
    }

    // MARK: - Comment Input Bar

    private var assignmentCommentBar: some View {
        HStack(spacing: 8) {
            // Text field
            TextField("Haz una pregunta o comenta...", text: $commentText)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18))
                .focused($isCommentFocused)
                .submitLabel(.send)
                .onSubmit {
                    sendComment()
                }

            // Send button (shows when text entered)
            if !commentText.trimmingCharacters(in: .whitespaces).isEmpty {
                Button {
                    sendComment()
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
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private func sendComment() {
        let trimmedText = commentText.trimmingCharacters(in: .whitespaces)
        guard !trimmedText.isEmpty else { return }

        // Send message with task reference
        let taskRef = TaskReference(task: task)
        viewModel.sendMessage(content: trimmedText, referencedTask: taskRef)

        commentText = ""
        isCommentFocused = false
    }
}

// MARK: - Assignment Chat Bubble

// MARK: - Chat Attachment Options Sheet

struct ChatAttachmentOptionsSheet: View {
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    var onSelectPhotos: () -> Void = {}
    var onSelectDocuments: () -> Void = {}
    var onSelectContacts: () -> Void = {}

    var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Text("Agregar Adjunto")
                    .font(.system(size: 17, weight: .semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal)
            .padding(.top, 16)

            // Options
            HStack(spacing: 32) {
                // Photo Library
                Button {
                    onSelectPhotos()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle")
                            .font(.system(size: 28))
                            .foregroundStyle(Theme.primary)
                        Text("Fotos")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                    }
                }

                // Document
                Button {
                    onSelectDocuments()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "doc")
                            .font(.system(size: 28))
                            .foregroundStyle(.orange)
                        Text("Documentos")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                    }
                }

                // Contacts
                Button {
                    onSelectContacts()
                } label: {
                    VStack(spacing: 8) {
                        Image(systemName: "person.crop.circle")
                            .font(.system(size: 28))
                            .foregroundStyle(.blue)
                        Text("Contactos")
                            .font(.system(size: 12))
                            .foregroundStyle(.primary)
                    }
                }
            }
            .padding(.horizontal)

            Spacer()
        }
    }
}

// MARK: - Assignment Chat Bubble

struct AssignmentChatBubble: View {
    let message: Message

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            // Avatar on left for others
            if !message.isFromCurrentUser {
                Circle()
                    .fill(Theme.primaryLight)
                    .frame(width: 26, height: 26)
                    .overlay {
                        Text(message.sender.avatarInitials)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Theme.primary)
                    }
            } else {
                Spacer(minLength: 40)
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
                Text(message.content)
                    .font(.system(size: 14))
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

            // Spacer on right for others
            if !message.isFromCurrentUser {
                Spacer(minLength: 40)
            }
        }
    }
}

// MARK: - Camera Image Picker

struct CameraImagePicker: UIViewControllerRepresentable {
    var onImageCaptured: (UIImage?) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onImageCaptured: onImageCaptured)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var onImageCaptured: (UIImage?) -> Void

        init(onImageCaptured: @escaping (UIImage?) -> Void) {
            self.onImageCaptured = onImageCaptured
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey : Any]) {
            let image = info[.originalImage] as? UIImage
            onImageCaptured(image)
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            onImageCaptured(nil)
            picker.dismiss(animated: true)
        }
    }
}

// MARK: - Document Picker

struct DocumentPicker: UIViewControllerRepresentable {
    var onDocumentsSelected: ([URL]) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item], asCopy: true)
        picker.allowsMultipleSelection = true
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onDocumentsSelected: onDocumentsSelected)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onDocumentsSelected: ([URL]) -> Void

        init(onDocumentsSelected: @escaping ([URL]) -> Void) {
            self.onDocumentsSelected = onDocumentsSelected
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            onDocumentsSelected(urls)
        }

        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
            onDocumentsSelected([])
        }
    }
}

// MARK: - Contact Picker

struct ContactPicker: UIViewControllerRepresentable {
    var onContactSelected: (CNContact) -> Void

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let picker = CNContactPickerViewController()
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onContactSelected: onContactSelected)
    }

    class Coordinator: NSObject, CNContactPickerDelegate {
        var onContactSelected: (CNContact) -> Void

        init(onContactSelected: @escaping (CNContact) -> Void) {
            self.onContactSelected = onContactSelected
        }

        func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
            onContactSelected(contact)
        }
    }
}

#Preview {
    NavigationStack {
        ProjectChatView(project: Project(
            name: "Downtown Renovation",
            members: MockDataService.allUsers,
            tasks: [
                DONEOTask(title: "Order materials", status: .pending),
                DONEOTask(title: "Schedule inspection", status: .done)
            ]
        ))
    }
}
