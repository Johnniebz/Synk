import SwiftUI

struct TaskChatView: View {
    @Bindable var viewModel: TaskDetailViewModel
    @FocusState private var isInputFocused: Bool
    @State private var showingAttachmentOptions = false
    @State private var showingSubtaskPicker = false

    // Chat background color - warm cream
    private var chatBackgroundColor: Color {
        Theme.chatBackground
    }

    var body: some View {
        VStack(spacing: 0) {
            // Chat header
            HStack {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 12))
                Text("Discusion")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text("\(viewModel.messages.count)")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 10)
            .background(Color(uiColor: .secondarySystemBackground))

            // Messages with tinted background
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 8) {
                        if viewModel.messages.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "bubble.left.and.bubble.right")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.tertiary)
                                Text("No hay mensajes aun")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                                Text("Inicia la conversacion sobre esta tarea")
                                    .font(.system(size: 12))
                                    .foregroundStyle(.quaternary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 40)
                        } else {
                            ForEach(viewModel.messages) { message in
                                MessageBubble(message: message) { subtaskRef in
                                    // Handle subtask tap - could scroll to subtask in header
                                    // For now, just highlight by setting as referenced
                                    viewModel.referencedSubtaskForMessage = subtaskRef
                                    isInputFocused = true
                                }
                                .id(message.id)
                            }
                        }
                    }
                    .padding()
                }
                .background(chatBackgroundColor)
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
            }

            // Referenced subtask preview
            if let subtaskRef = viewModel.referencedSubtaskForMessage {
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.primary)
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Referenciando subtarea")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                        Text(subtaskRef.subtaskTitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Theme.primary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Button {
                        viewModel.referencedSubtaskForMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(uiColor: .secondarySystemBackground))
            }

            // Input field (Telegram-style)
            HStack(spacing: 8) {
                // Add attachment button (+ icon)
                Button {
                    showingAttachmentOptions = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundStyle(Theme.primary)
                }

                // Reference subtask button
                if !viewModel.task.subtasks.isEmpty {
                    Button {
                        showingSubtaskPicker = true
                    } label: {
                        Image(systemName: "checklist")
                            .font(.system(size: 20))
                            .foregroundStyle(viewModel.referencedSubtaskForMessage != nil ? Theme.primary : .secondary)
                    }
                }

                // Text field - sends on return, no send button
                TextField("Mensaje", text: $viewModel.newMessageText, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .focused($isInputFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        viewModel.sendMessage()
                    }

                // Quick camera button
                Button {
                    addMockAttachment(type: .image, fileName: "Camera_\(Date().timeIntervalSince1970).jpg")
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }

                // Quick audio button
                Button {
                    // TODO: Record audio
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(uiColor: .systemBackground))
        }
        .sheet(isPresented: $showingAttachmentOptions) {
            TelegramStyleAttachmentSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingSubtaskPicker) {
            SubtaskPickerSheet(
                subtasks: viewModel.task.subtasks,
                onSelect: { subtask in
                    viewModel.referencedSubtaskForMessage = SubtaskReference(subtask: subtask)
                    showingSubtaskPicker = false
                    isInputFocused = true
                }
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func addMockAttachment(type: AttachmentType, fileName: String) {
        let attachment = Attachment(
            type: type,
            fileName: fileName,
            fileSize: Int64.random(in: 50000...2000000),
            uploadedBy: MockDataService.shared.currentUser,
            linkedSubtaskId: nil
        )
        viewModel.addAttachment(attachment)
    }
}

// MARK: - Telegram Style Attachment Sheet

struct TelegramStyleAttachmentSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var viewModel: TaskDetailViewModel
    @State private var selectedTab = 0
    @State private var showingContactPicker = false
    @State private var newSubtaskTitle = ""
    @State private var newSubtaskDescription = ""
    @State private var selectedAssigneeIds: Set<UUID> = []
    @FocusState private var isSubtaskFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header with close button
            HStack {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.primary)
                        .padding(8)
                        .background(Color(uiColor: .secondarySystemBackground))
                        .clipShape(Circle())
                }

                Spacer()

                Text("Recientes")
                    .font(.system(size: 16, weight: .semibold))

                Spacer()

                // Placeholder for symmetry
                Color.clear.frame(width: 32, height: 32)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .padding(.bottom, 8)

            // Content based on selected tab
            TabView(selection: $selectedTab) {
                // Gallery tab - Photo grid
                photoGridView
                    .tag(0)

                // File tab
                filePickerView
                    .tag(1)

                // Checklist tab - Subtasks
                checklistView
                    .tag(2)

                // Contact tab
                contactListView
                    .tag(3)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            // Bottom tab bar
            HStack(spacing: 0) {
                TabButton(icon: "photo.fill", title: "Galeria", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                TabButton(icon: "doc.fill", title: "Archivo", isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                TabButton(icon: "checklist", title: "Lista", isSelected: selectedTab == 2) {
                    selectedTab = 2
                }
                TabButton(icon: "person.fill", title: "Contacto", isSelected: selectedTab == 3) {
                    selectedTab = 3
                }
            }
            .padding(.vertical, 8)
            .background(Color(uiColor: .secondarySystemBackground))
        }
    }

    // MARK: - Photo Grid View
    private var photoGridView: some View {
        let columns = [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2)
        ]

        return ScrollView {
            LazyVGrid(columns: columns, spacing: 2) {
                // Camera button
                Button {
                    addMockAttachment(type: .image, fileName: "Camera_\(Date().timeIntervalSince1970).jpg")
                } label: {
                    ZStack {
                        Rectangle()
                            .fill(Color(uiColor: .tertiarySystemBackground))
                            .aspectRatio(1, contentMode: .fill)
                        VStack(spacing: 4) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 28))
                            Text("Camara")
                                .font(.system(size: 12))
                        }
                        .foregroundStyle(.secondary)
                    }
                }

                // Mock photo placeholders
                ForEach(0..<11, id: \.self) { index in
                    Button {
                        addMockAttachment(type: .image, fileName: "Photo_\(index)_\(Date().timeIntervalSince1970).jpg")
                    } label: {
                        ZStack {
                            Rectangle()
                                .fill(Color(hue: Double(index) / 12.0, saturation: 0.3, brightness: 0.9))
                                .aspectRatio(1, contentMode: .fill)

                            // Selection circle
                            VStack {
                                HStack {
                                    Spacer()
                                    Circle()
                                        .strokeBorder(Color.white, lineWidth: 2)
                                        .frame(width: 24, height: 24)
                                        .padding(6)
                                }
                                Spacer()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - File Picker View
    private var filePickerView: some View {
        VStack(spacing: 20) {
            Spacer()

            Button {
                addMockAttachment(type: .document, fileName: "Document_\(Date().timeIntervalSince1970).pdf")
            } label: {
                VStack(spacing: 12) {
                    Image(systemName: "doc.badge.plus")
                        .font(.system(size: 48))
                        .foregroundStyle(.orange)
                    Text("Elegir Archivo")
                        .font(.system(size: 16, weight: .medium))
                    Text("PDF, Word, Excel, y mas")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }

    // MARK: - Checklist View (Just for adding subtasks)
    private var checklistView: some View {
        VStack(spacing: 0) {
            // Add subtask section
            VStack(spacing: 16) {
                // Title input
                HStack(spacing: 12) {
                    Image(systemName: "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(.secondary)

                    TextField("Agregar una subtarea...", text: $newSubtaskTitle)
                        .font(.system(size: 17))
                        .focused($isSubtaskFieldFocused)
                        .submitLabel(.next)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Description input (optional)
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "text.alignleft")
                        .font(.system(size: 20))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)

                    TextField("Agregar descripcion (opcional)...", text: $newSubtaskDescription, axis: .vertical)
                        .font(.system(size: 15))
                        .lineLimit(1...4)
                }
                .padding()
                .background(Color(uiColor: .secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Quick assign picker (multi-select)
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Asignar a")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)

                        if !selectedAssigneeIds.isEmpty {
                            Text("\(selectedAssigneeIds.count) seleccionados")
                                .font(.system(size: 11))
                                .foregroundStyle(Theme.primary)
                        }
                    }

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            // Team members (tap to toggle)
                            ForEach(viewModel.members) { member in
                                let isSelected = selectedAssigneeIds.contains(member.id)
                                Button {
                                    if isSelected {
                                        selectedAssigneeIds.remove(member.id)
                                    } else {
                                        selectedAssigneeIds.insert(member.id)
                                    }
                                } label: {
                                    VStack(spacing: 4) {
                                        ZStack {
                                            Circle()
                                                .fill(isSelected ? Theme.primary : Color(uiColor: .tertiarySystemBackground))
                                                .frame(width: 44, height: 44)
                                            Text(member.avatarInitials)
                                                .font(.system(size: 14, weight: .medium))
                                                .foregroundStyle(isSelected ? .white : .primary)

                                            // Checkmark overlay when selected
                                            if isSelected {
                                                Circle()
                                                    .fill(Color.green)
                                                    .frame(width: 16, height: 16)
                                                    .overlay {
                                                        Image(systemName: "checkmark")
                                                            .font(.system(size: 8, weight: .bold))
                                                            .foregroundStyle(.white)
                                                    }
                                                    .offset(x: 14, y: 14)
                                            }
                                        }
                                        Text(member.displayFirstName)
                                            .font(.system(size: 11))
                                            .foregroundStyle(isSelected ? Theme.primary : .secondary)
                                            .lineLimit(1)
                                    }
                                    .frame(width: 60)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 4)

                // Add button
                Button {
                    addSubtask()
                } label: {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("Agregar Subtarea")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(newSubtaskTitle.isEmpty ? Color(uiColor: .tertiarySystemBackground) : Theme.primary)
                    .foregroundColor(newSubtaskTitle.isEmpty ? .secondary : .white)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .disabled(newSubtaskTitle.isEmpty)
            }
            .padding()

            Spacer()

            // Subtle hint about where subtasks appear
            if !viewModel.task.subtasks.isEmpty {
                HStack {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                    Text("\(viewModel.task.subtasks.count) subtarea\(viewModel.task.subtasks.count == 1 ? "" : "s") agregada\(viewModel.task.subtasks.count == 1 ? "" : "s") · Ver en encabezado de tarea")
                        .font(.system(size: 12))
                }
                .foregroundStyle(.tertiary)
                .padding(.bottom, 16)
            }
        }
    }

    // MARK: - Contact List View
    private var contactListView: some View {
        VStack(spacing: 0) {
            List {
                ForEach(MockContacts.all) { contact in
                    Button {
                        viewModel.sendContactMessage(contact: contact)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(avatarColor(for: contact.name))
                                .frame(width: 44, height: 44)
                                .overlay {
                                    Text(contact.initials)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(.white)
                                }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(contact.name)
                                    .font(.system(size: 16))
                                    .foregroundStyle(.primary)
                                Text(contact.phoneNumber)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .listStyle(.plain)
        }
    }

    // MARK: - Helper Functions

    private func addSubtask() {
        guard !newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let selectedAssignees = viewModel.members.filter { selectedAssigneeIds.contains($0.id) }
        let description = newSubtaskDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        let subtask = Subtask(
            title: newSubtaskTitle,
            description: description.isEmpty ? nil : description,
            assignees: selectedAssignees,
            createdBy: MockDataService.shared.currentUser
        )
        viewModel.task.subtasks.append(subtask)
        newSubtaskTitle = ""
        newSubtaskDescription = ""
        selectedAssigneeIds = []
    }

    private func addMockAttachment(type: AttachmentType, fileName: String) {
        let attachment = Attachment(
            type: type,
            fileName: fileName,
            fileSize: Int64.random(in: 50000...2000000),
            uploadedBy: MockDataService.shared.currentUser,
            linkedSubtaskId: nil
        )
        viewModel.addAttachment(attachment)
        dismiss()
    }

    private func avatarColor(for name: String) -> Color {
        Theme.primary
    }
}

// MARK: - Tab Button

struct TabButton: View {
    let icon: String
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 22))
                Text(title)
                    .font(.system(size: 11))
            }
            .foregroundStyle(isSelected ? Theme.primary : .secondary)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Message Bubble

struct MessageBubble: View {
    let message: Message
    var onSubtaskTap: ((SubtaskReference) -> Void)? = nil

    var body: some View {
        switch message.messageType {
        case .subtaskCompleted(let subtaskRef):
            subtaskStatusMessage(completed: true, subtaskRef: subtaskRef)
        case .subtaskReopened(let subtaskRef):
            subtaskStatusMessage(completed: false, subtaskRef: subtaskRef)
        case .regular:
            regularMessage
        }
    }

    // MARK: - Subtask Status Message (System-style)

    private func subtaskStatusMessage(completed: Bool, subtaskRef: SubtaskReference) -> some View {
        HStack(spacing: 8) {
            Spacer()

            HStack(spacing: 6) {
                Image(systemName: completed ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(completed ? Theme.success : Theme.warning)

                Text(message.sender.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.secondary)

                Text(completed ? "completo" : "reabrio")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)

                Button {
                    onSubtaskTap?(subtaskRef)
                } label: {
                    Text("\"\(subtaskRef.subtaskTitle)\"")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color(uiColor: .secondarySystemBackground))
            .clipShape(Capsule())

            Spacer()
        }
        .padding(.vertical, 4)
    }

    // MARK: - Regular Message

    private var regularMessage: some View {
        HStack {
            if message.isFromCurrentUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                if !message.isFromCurrentUser {
                    Text(message.sender.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 4) {
                    // Subtask reference badge (if referencing a subtask)
                    if let subtaskRef = message.referencedSubtask {
                        Button {
                            onSubtaskTap?(subtaskRef)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "checklist")
                                    .font(.system(size: 10))
                                Text(subtaskRef.subtaskTitle)
                                    .font(.system(size: 12, weight: .medium))
                                    .lineLimit(1)
                            }
                            .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.9) : Theme.primary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                message.isFromCurrentUser
                                    ? Color.white.opacity(0.2)
                                    : Theme.primaryLight
                            )
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    // Message content
                    Text(message.content)
                        .font(.system(size: 15))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    message.isFromCurrentUser
                    ? Theme.primary
                    : Color(uiColor: .systemGray5)
                )
                .foregroundStyle(message.isFromCurrentUser ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(message.timestamp, style: .time)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            if !message.isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }
}

// MARK: - Subtask Picker Sheet

struct SubtaskPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let subtasks: [Subtask]
    let onSelect: (Subtask) -> Void

    var body: some View {
        NavigationStack {
            List {
                if subtasks.isEmpty {
                    ContentUnavailableView(
                        "Sin Subtareas",
                        systemImage: "checklist",
                        description: Text("Agrega subtareas para referenciarlas en el chat")
                    )
                } else {
                    ForEach(subtasks) { subtask in
                        Button {
                            onSelect(subtask)
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 20))
                                    .foregroundStyle(subtask.isDone ? Theme.success : .secondary)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(subtask.title)
                                        .font(.system(size: 16))
                                        .foregroundStyle(subtask.isDone ? .secondary : .primary)
                                        .strikethrough(subtask.isDone)

                                    if let description = subtask.description, !description.isEmpty {
                                        Text(description)
                                            .font(.system(size: 13))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.right")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .navigationTitle("Referenciar Subtarea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") {
                        dismiss()
                    }
                }
            }
        }
    }
}
