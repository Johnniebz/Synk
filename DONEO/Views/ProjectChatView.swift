import SwiftUI
import PhotosUI
import AVFoundation
import ContactsUI

struct ProjectChatView: View {
    @State private var viewModel: ProjectChatViewModel
    @State private var showingProjectInfo = false
    @State private var showingTaskDrawer = false
    @State private var showingNewTasksInbox = false
    @State private var selectedTaskForInfo: DONEOTask? = nil
    @State private var selectedPendingTask: DONEOTask? = nil // For assignment screen
    @State private var selectedSubtaskForInfo: (subtask: Subtask, task: DONEOTask)? = nil
    @State private var showingAttachmentOptions = false
    @State private var taskToExpandInDrawer: UUID? = nil
    @FocusState private var isInputFocused: Bool
    @Environment(\.dismiss) private var dismiss

    // Media picker states
    @State private var showingCamera = false
    @State private var showingPhotoPicker = false
    @State private var showingDocumentPicker = false
    @State private var showingContactPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []

    // Voice recording states
    @State private var isRecording = false
    @State private var audioRecorder: AVAudioRecorder?
    @State private var recordingURL: URL?

    init(project: Project) {
        _viewModel = State(initialValue: ProjectChatViewModel(project: project))
    }

    var body: some View {
        chatMessagesArea
            .safeAreaInset(edge: .bottom) {
                taskButtonBar
            }
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

                            // Badge
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
        .sheet(isPresented: $showingTaskDrawer, onDismiss: {
            taskToExpandInDrawer = nil
        }) {
            TaskDrawerSheet(viewModel: viewModel, initialExpandedTaskId: taskToExpandInDrawer)
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showingProjectInfo) {
            ProjectInfoView(viewModel: viewModel)
        }
        .sheet(isPresented: $showingNewTasksInbox) {
            ProjectNewTasksInboxSheet(viewModel: viewModel)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedTaskForInfo) { task in
            TaskInfoSheet(task: task, viewModel: viewModel)
        }
        .sheet(item: $selectedPendingTask) { task in
            NewTaskInboxDetailSheet(
                task: task,
                projectName: viewModel.project.name,
                viewModel: viewModel,
                onAccept: {
                    viewModel.acceptTask(task, message: nil)
                    selectedPendingTask = nil
                },
                onCancel: {
                    selectedPendingTask = nil
                }
            )
        }
        .sheet(isPresented: Binding(
            get: { selectedSubtaskForInfo != nil },
            set: { if !$0 { selectedSubtaskForInfo = nil } }
        )) {
            if let info = selectedSubtaskForInfo {
                SubtaskInfoSheet(
                    subtask: info.subtask,
                    task: info.task,
                    viewModel: viewModel,
                    onNavigateToParentTask: { parentTask in
                        selectedSubtaskForInfo = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            taskToExpandInDrawer = parentTask.id
                            showingTaskDrawer = true
                        }
                    }
                )
            }
        }
        .sheet(isPresented: $showingAttachmentOptions) {
            ChatAttachmentOptionsSheet(
                viewModel: viewModel,
                onSelectPhotos: {
                    showingAttachmentOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingPhotoPicker = true
                    }
                },
                onSelectDocuments: {
                    showingAttachmentOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingDocumentPicker = true
                    }
                },
                onSelectContacts: {
                    showingAttachmentOptions = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        showingContactPicker = true
                    }
                }
            )
                .presentationDetents([.height(200)])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showingCamera) {
            CameraImagePicker { image in
                if let image = image {
                    handleCapturedImage(image)
                }
            }
            .ignoresSafeArea()
        }
        .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItems, maxSelectionCount: 10, matching: .images)
        .onChange(of: selectedPhotoItems) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        handleCapturedImage(image)
                    }
                }
                selectedPhotoItems = []
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPicker { urls in
                for url in urls {
                    handleSelectedDocument(url)
                }
            }
        }
        .sheet(isPresented: $showingContactPicker) {
            ContactPicker { contact in
                handleSelectedContact(contact)
            }
        }
    }

    // MARK: - Media Handling

    private func handleCapturedImage(_ image: UIImage) {
        if let imageData = image.jpegData(compressionQuality: 0.8) {
            viewModel.sendImageMessage(imageData: imageData)
        }
    }

    private func handleSelectedDocument(_ url: URL) {
        let fileName = url.lastPathComponent
        viewModel.sendSystemMessage("Compartio un documento: \(fileName)")
    }

    private func handleSelectedContact(_ contact: CNContact) {
        let name = "\(contact.givenName) \(contact.familyName)".trimmingCharacters(in: .whitespaces)
        viewModel.sendSystemMessage("Compartio un contacto: \(name)")
    }

    private func startRecording() {
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.playAndRecord, mode: .default)
            try audioSession.setActive(true)

            let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            let audioFilename = documentsPath.appendingPathComponent("recording_\(Date().timeIntervalSince1970).m4a")
            recordingURL = audioFilename

            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]

            audioRecorder = try AVAudioRecorder(url: audioFilename, settings: settings)
            audioRecorder?.record()
            isRecording = true
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    private func stopRecording() {
        audioRecorder?.stop()
        isRecording = false

        if let url = recordingURL {
            viewModel.sendSystemMessage("Envio un mensaje de voz")
            // In a real app, you would upload the audio file
            _ = url
        }
    }

    // MARK: - Header View (Project name + member count)

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

    // MARK: - Chat Messages Area

    private var chatMessagesArea: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    if viewModel.messages.isEmpty {
                        emptyStateView
                    } else {
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            let previousMessage = index > 0 ? viewModel.messages[index - 1] : nil
                            let nextMessage = index < viewModel.messages.count - 1 ? viewModel.messages[index + 1] : nil

                            // Determine if we should show sender name (first in group or different sender)
                            let isFirstInGroup = previousMessage == nil ||
                                previousMessage?.sender.id != message.sender.id ||
                                previousMessage?.messageType != .regular ||
                                message.messageType != .regular

                            // Determine if this is last in sender group (for bottom padding)
                            let isLastInGroup = nextMessage == nil ||
                                nextMessage?.sender.id != message.sender.id ||
                                nextMessage?.messageType != .regular ||
                                message.messageType != .regular

                            // Determine if task context changed from previous message
                            let previousTaskId = previousMessage?.referencedTask?.taskId ?? previousMessage?.referencedSubtask?.subtaskId
                            let currentTaskId = message.referencedTask?.taskId ?? message.referencedSubtask?.subtaskId
                            let showTaskContext = currentTaskId != previousTaskId || isFirstInGroup

                            ProjectMessageBubble(
                                message: message,
                                showSenderName: isFirstInGroup,
                                showTaskContext: showTaskContext,
                                isLastInGroup: isLastInGroup,
                                pendingTaskIds: Set(viewModel.newTasksForCurrentUser.map { $0.id }),
                                onTaskTap: { taskRef in
                                    // Check if task is pending assignment for current user
                                    if let task = viewModel.project.tasks.first(where: { $0.id == taskRef.taskId }) {
                                        if task.isNew(for: viewModel.currentUser.id) {
                                            // Pending assignment → show assignment screen
                                            selectedPendingTask = task
                                        } else {
                                            // Active task → show task info screen
                                            selectedTaskForInfo = task
                                        }
                                    }
                                },
                                onSubtaskTap: { subtaskRef in
                                    // Find the task and subtask, then open SubtaskInfoSheet
                                    for task in viewModel.project.tasks {
                                        if let subtask = task.subtasks.first(where: { $0.id == subtaskRef.subtaskId }) {
                                            selectedSubtaskForInfo = (subtask, task)
                                            break
                                        }
                                    }
                                },
                                onReaction: { emoji in
                                    viewModel.addReaction(emoji, to: message)
                                }
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding()
            }
            .background(Theme.chatBackground)
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 40))
                .foregroundStyle(.tertiary)

            Text("Sin mensajes aun")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(.secondary)

            Text("Abre una tarea para iniciar una discusion")
                .font(.system(size: 14))
                .foregroundStyle(.tertiary)

            // Quick task button
            Button {
                showingTaskDrawer = true
            } label: {
                HStack {
                    Image(systemName: "checklist")
                    Text("Ver Tareas")
                }
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Theme.primaryLight)
                .foregroundStyle(Theme.primary)
                .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 60)
    }

    // MARK: - Reference Preview

    private var referencePreview: some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Theme.primary)
                .frame(width: 3, height: 32)

            VStack(alignment: .leading, spacing: 1) {
                if let quoted = viewModel.quotedMessage {
                    Text("Respondiendo a \(quoted.senderName)")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.primary)
                    Text(quoted.content)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let subtaskRef = viewModel.referencedSubtask {
                    Text("Subtarea")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.primary)
                    Text(subtaskRef.subtaskTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else if let taskRef = viewModel.referencedTask {
                    Text("Tarea")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.primary)
                    Text(taskRef.taskTitle)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Button {
                viewModel.clearAllReferences()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(uiColor: .secondarySystemBackground))
    }

    // MARK: - Task Button Bar

    private var taskButtonBar: some View {
        Button {
            showingTaskDrawer = true
        } label: {
            HStack(spacing: 10) {
                Image(systemName: "checklist")
                    .font(.system(size: 20, weight: .semibold))

                Text("Ver Tareas")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundStyle(Theme.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Theme.primaryLight)
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.thinMaterial)
    }
}

// MARK: - Project Message Bubble

struct ProjectMessageBubble: View {
    let message: Message
    var showSenderName: Bool = true
    var showTaskContext: Bool = true
    var isLastInGroup: Bool = true
    var pendingTaskIds: Set<UUID> = []
    var onTaskTap: ((TaskReference) -> Void)? = nil
    var onSubtaskTap: ((SubtaskReference) -> Void)? = nil
    var onReaction: ((String) -> Void)? = nil

    @State private var showingEmojiPicker = false

    private let quickEmojis = ["👍", "❤️", "😂", "😮", "😢", "🙏"]

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

    private func subtaskStatusMessage(completed: Bool, subtaskRef: SubtaskReference) -> some View {
        HStack(spacing: 8) {
            Spacer()

            HStack(spacing: 6) {
                Image(systemName: completed ? "checkmark.circle.fill" : "arrow.uturn.backward.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(completed ? Theme.success : Theme.warning)

                Text(message.sender.displayFirstName)
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
        .padding(.vertical, 8)
    }

    private var regularMessage: some View {
        HStack(alignment: .bottom) {
            if message.isFromCurrentUser {
                Spacer(minLength: 60)
            }

            VStack(alignment: message.isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                // Sender name - only show if first in group
                if !message.isFromCurrentUser && showSenderName {
                    Text(message.sender.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                        .padding(.bottom, 2)
                }

                // Task/Subtask context - shown above bubble only when context changes
                if showTaskContext {
                    if let subtaskRef = message.referencedSubtask {
                        // Subtask - show with arrow to indicate it's nested
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 9))
                            Text("Subtarea:")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(subtaskRef.subtaskTitle)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)
                        }
                        .foregroundStyle(Theme.primary)
                        .padding(.leading, message.isFromCurrentUser ? 0 : 4)
                        .padding(.trailing, message.isFromCurrentUser ? 4 : 0)
                    } else if let taskRef = message.referencedTask {
                        // Task - show with checklist icon
                        HStack(spacing: 3) {
                            Image(systemName: "checklist")
                                .font(.system(size: 9))
                            Text("Tarea:")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(taskRef.taskTitle)
                                .font(.system(size: 11, weight: .medium))
                                .lineLimit(1)

                            // Badge for pending tasks
                            if pendingTaskIds.contains(taskRef.taskId) {
                                Text("Nueva")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.orange)
                                    .clipShape(Capsule())
                            }
                        }
                        .foregroundStyle(Theme.primary)
                        .padding(.leading, message.isFromCurrentUser ? 0 : 4)
                        .padding(.trailing, message.isFromCurrentUser ? 4 : 0)
                    }
                }

                // Message bubble
                VStack(alignment: .leading, spacing: 4) {
                    // Quoted message
                    if let quoted = message.quotedMessage {
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(message.isFromCurrentUser ? Color.white.opacity(0.5) : Theme.primary.opacity(0.5))
                                .frame(width: 3)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(quoted.senderName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.9) : Theme.primary)
                                Text(quoted.content)
                                    .font(.system(size: 12))
                                    .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(8)
                        .background(
                            message.isFromCurrentUser
                                ? Color.white.opacity(0.15)
                                : Color(uiColor: .systemGray4)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Attachment preview
                    if let attachment = message.attachment {
                        attachmentPreview(attachment)
                    }

                    // Message content (hide if just camera emoji for image)
                    if message.content != "📷" || message.attachment == nil {
                        Text(message.content)
                            .font(.system(size: 15))
                    }
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

                // Reactions display
                if !message.reactions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(Array(message.groupedReactions.keys.sorted()), id: \.self) { emoji in
                            if let reactions = message.groupedReactions[emoji] {
                                HStack(spacing: 2) {
                                    Text(emoji)
                                        .font(.system(size: 14))
                                    if reactions.count > 1 {
                                        Text("\(reactions.count)")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color(uiColor: .systemGray5))
                                .clipShape(Capsule())
                                .onTapGesture {
                                    onReaction?(emoji)
                                }
                            }
                        }
                    }
                }

                // Time - only show on last message in group
                if isLastInGroup {
                    Text(message.timestamp, style: .time)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                // Tap to navigate to subtask if present, otherwise task
                if let subtaskRef = message.referencedSubtask {
                    onSubtaskTap?(subtaskRef)
                } else if let taskRef = message.referencedTask {
                    onTaskTap?(taskRef)
                }
            }
            .onLongPressGesture {
                showingEmojiPicker = true
            }
            .popover(isPresented: $showingEmojiPicker) {
                emojiPickerView
                    .presentationCompactAdaptation(.popover)
            }

            if !message.isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.bottom, isLastInGroup ? 8 : 0)
    }

    private var emojiPickerView: some View {
        HStack(spacing: 12) {
            ForEach(quickEmojis, id: \.self) { emoji in
                Button {
                    onReaction?(emoji)
                    showingEmojiPicker = false
                } label: {
                    Text(emoji)
                        .font(.system(size: 28))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private func attachmentPreview(_ attachment: MessageAttachment) -> some View {
        switch attachment.type {
        case .image:
            // Photo attachment - show actual image if available
            if let imageData = attachment.imageData,
               let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(maxWidth: 220, maxHeight: 280)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                // Fallback if no image data
                HStack(spacing: 8) {
                    Image(systemName: "photo.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.8) : Theme.primary)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Foto")
                            .font(.system(size: 13, weight: .medium))
                        Text(attachment.fileName)
                            .font(.system(size: 11))
                            .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                            .lineLimit(1)
                    }
                }
                .padding(10)
                .background(
                    message.isFromCurrentUser
                        ? Color.white.opacity(0.15)
                        : Color(uiColor: .systemGray4)
                )
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

        case .document:
            // Document attachment
            HStack(spacing: 8) {
                Image(systemName: "doc.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.8) : Theme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(attachment.fileName)
                        .font(.system(size: 13, weight: .medium))
                        .lineLimit(1)
                    if attachment.fileSize > 0 {
                        Text(ByteCountFormatter.string(fromByteCount: attachment.fileSize, countStyle: .file))
                            .font(.system(size: 11))
                            .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                    }
                }

                Spacer()

                Image(systemName: "arrow.down.circle")
                    .font(.system(size: 20))
                    .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.8) : Theme.primary)
            }
            .padding(10)
            .background(
                message.isFromCurrentUser
                    ? Color.white.opacity(0.15)
                    : Color(uiColor: .systemGray4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

        case .video:
            // Video attachment
            HStack(spacing: 8) {
                Image(systemName: "video.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.8) : Theme.primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Video")
                        .font(.system(size: 13, weight: .medium))
                    Text(attachment.fileName)
                        .font(.system(size: 11))
                        .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(
                message.isFromCurrentUser
                    ? Color.white.opacity(0.15)
                    : Color(uiColor: .systemGray4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))

        case .contact:
            // Contact attachment
            HStack(spacing: 8) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.8) : .green)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Contacto")
                        .font(.system(size: 13, weight: .medium))
                    Text(attachment.fileName)
                        .font(.system(size: 11))
                        .foregroundStyle(message.isFromCurrentUser ? .white.opacity(0.7) : .secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .background(
                message.isFromCurrentUser
                    ? Color.white.opacity(0.15)
                    : Color(uiColor: .systemGray4)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }
}

// MARK: - Project Info View

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
