import SwiftUI
import PhotosUI

/// Unified Task Detail View - Path B Implementation
/// Shows task info, expandable subtasks with inline details, and ONE chat
struct UnifiedTaskDetailView: View {
    let task: DONEOTask
    @Bindable var viewModel: ProjectChatViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var showingAddSubtask = false
    @State private var showingDetailsSheet = false  // For details sheet
    @State private var showingSubtasks = false      // For collapsible subtasks section
    @State private var selectedSubtask: Subtask?    // For subtask info sheet
    @State private var showingAttachmentOptions = false  // For attachment options sheet

    // Comment bar state
    @State private var commentText: String = ""
    @State private var quotedMessage: Message? = nil  // For quoting/replying to messages
    @State private var quotedSubtask: Subtask? = nil  // For quoting/referencing subtasks
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

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Scrollable content: Task info + Subtasks + Chat
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 0) {
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
            .toolbarBackground(Color(uiColor: .systemBackground), for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
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
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingDetailsSheet = true
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.system(size: 20))
                            .foregroundStyle(Theme.primary)
                    }
                }
            }
            .sheet(isPresented: $showingAddSubtask) {
                AddSubtaskSheet(task: currentTask, viewModel: viewModel)
            }
            .sheet(isPresented: $showingDetailsSheet) {
                TaskInstructionsSheet(task: currentTask)
            }
            .sheet(isPresented: $showingAttachmentOptions) {
                AttachmentOptionsSheet()
            }
        }
    }

    // MARK: - Task Header Section

    private var hasDetails: Bool {
        (currentTask.notes != nil && !currentTask.notes!.isEmpty) ||
        !currentTask.attachments.filter({ $0.isInstruction }).isEmpty
    }

    // MARK: - Subtasks Section (Collapsible Card)

    private var subtasksSection: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    showingSubtasks.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "checklist")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                        .frame(width: 32, height: 32)
                        .background(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Subtareas")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.primary)

                    let completed = currentTask.subtasks.filter { $0.isDone }.count
                    let total = currentTask.subtasks.count
                    if total > 0 {
                        Text("\(completed)/\(total)")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(completed == total ? .green : Theme.primary)
                    }

                    Spacer()

                    // Add button
                    Button {
                        showingAddSubtask = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                            .frame(width: 28, height: 28)
                            .background(Theme.primaryLight)
                            .clipShape(Circle())
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.secondary.opacity(0.5))
                        .rotationEffect(.degrees(showingSubtasks ? 90 : 0))
                }
                .padding(14)
            }
            .buttonStyle(.plain)

            // Expanded subtasks list
            if showingSubtasks && !currentTask.subtasks.isEmpty {
                Divider().padding(.leading, 58)

                List {
                    ForEach(currentTask.subtasks.sorted { !$0.isDone && $1.isDone }) { subtask in
                        subtaskRow(subtask)
                            .listRowInsets(EdgeInsets())
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    quotedSubtask = subtask
                                    isCommentFocused = true
                                } label: {
                                    Label("Citar", systemImage: "arrowshape.turn.up.left.fill")
                                }
                                .tint(Theme.primary)
                            }
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(currentTask.subtasks.count) * 60)
                .transition(.opacity)
            }
        }
        .background(Color(uiColor: .systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .sheet(item: $selectedSubtask) { subtask in
            SubtaskInfoSheet(subtask: subtask, task: currentTask, viewModel: viewModel)
        }
    }

    // MARK: - Subtask Row

    private func subtaskRow(_ subtask: Subtask) -> some View {
        HStack(spacing: 12) {
            // Checkbox
            Button {
                if viewModel.canToggleSubtask(subtask) {
                    viewModel.toggleSubtaskStatus(currentTask, subtask)
                }
            } label: {
                Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(subtask.isDone ? .green : Theme.primary.opacity(0.3))
            }
            .buttonStyle(.plain)

            // Title and info
            VStack(alignment: .leading, spacing: 3) {
                Text(subtask.title)
                    .font(.system(size: 14, weight: .medium))
                    .strikethrough(subtask.isDone)
                    .foregroundStyle(subtask.isDone ? .secondary : .primary)
                    .lineLimit(2)

                // Info row
                HStack(spacing: 8) {
                    if !subtask.assignees.isEmpty {
                        HStack(spacing: -4) {
                            ForEach(subtask.assignees.prefix(2)) { assignee in
                                Circle()
                                    .fill(Theme.primaryLight)
                                    .frame(width: 18, height: 18)
                                    .overlay {
                                        Text(assignee.avatarInitials)
                                            .font(.system(size: 7, weight: .bold))
                                            .foregroundStyle(Theme.primary)
                                    }
                                    .overlay(Circle().stroke(.white, lineWidth: 1))
                            }
                        }
                    }

                    if subtask.description != nil || !subtask.instructionAttachments.isEmpty {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Theme.primary)
                    }

                    if let dueDate = subtask.dueDate {
                        HStack(spacing: 3) {
                            Image(systemName: "calendar")
                                .font(.system(size: 9))
                            Text(formatDueDate(dueDate))
                                .font(.system(size: 10))
                        }
                        .foregroundStyle(subtask.isOverdue ? .red : .secondary)
                    }
                }
            }

            Spacer()

            // Info button (i)
            Button {
                selectedSubtask = subtask
            } label: {
                Image(systemName: "info.circle")
                    .font(.system(size: 18))
                    .foregroundStyle(Theme.primary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    // MARK: - Chat Section

    private var chatSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Section header
            HStack(spacing: 12) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.green)
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                Text("Conversación")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.primary)

                if !allTaskMessages.isEmpty {
                    Text("\(allTaskMessages.count)")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.green)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Capsule())
                }

                Spacer()
            }
            .padding(14)
            .background(Color(uiColor: .systemBackground))

            Divider()

            // Messages area
            if allTaskMessages.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 36))
                        .foregroundStyle(Color.secondary.opacity(0.3))
                    Text("Sin mensajes aún")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.secondary)
                    Text("Inicia la conversación sobre esta tarea")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.secondary.opacity(0.6))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .background(Color(uiColor: .systemBackground))
            } else {
                VStack(spacing: 12) {
                    ForEach(allTaskMessages) { message in
                        UnifiedMessageBubble(message: message, task: currentTask, viewModel: viewModel)
                            .id(message.id)
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button {
                                    quotedMessage = message
                                    isCommentFocused = true
                                } label: {
                                    Label("Citar", systemImage: "arrowshape.turn.up.left.fill")
                                }
                                .tint(Theme.primary)
                            }
                    }
                }
                .padding(16)
                .background(Color(uiColor: .systemBackground))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 8)
    }

    // MARK: - Comment Input Bar

    private var commentInputBar: some View {
        VStack(spacing: 0) {
            // Quoted message preview
            if let quoted = quotedMessage {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Theme.primary)
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(quoted.sender.displayFirstName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                        Text(quoted.content)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button {
                        quotedMessage = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }

            // Quoted subtask preview
            if let subtask = quotedSubtask {
                HStack(spacing: 10) {
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 3)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Image(systemName: "checklist")
                                .font(.system(size: 10))
                            Text("Subtarea")
                                .font(.system(size: 12, weight: .semibold))
                        }
                        .foregroundStyle(.orange)
                        Text(subtask.title)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Button {
                        quotedSubtask = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 20))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(uiColor: .secondarySystemGroupedBackground))
            }

            HStack(spacing: 10) {
                // Plus button for attachments
                Button {
                    showingAttachmentOptions = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 36, height: 36)
                        .background(Theme.primaryLight)
                        .clipShape(Circle())
                }

                // Text field
                TextField("Escribe un mensaje...", text: $commentText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused($isCommentFocused)
                    .submitLabel(.send)
                    .onSubmit {
                        sendMessage()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(Color(uiColor: .tertiarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                // Camera button
                Button {
                    // TODO: Open camera
                } label: {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.primary)
                }

                // Microphone button
                Button {
                    // TODO: Start voice recording
                } label: {
                    Image(systemName: "mic.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Theme.primary)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(
            Color(uiColor: .systemBackground)
                .shadow(color: .black.opacity(0.05), radius: 8, y: -4)
        )
    }

    // MARK: - Helper Methods

    private func sendMessage() {
        let text = commentText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }

        // Send as task-level message, with optional quoted message or subtask reference
        let quoted = quotedMessage.map { QuotedMessage(message: $0) }
        let subtaskRef = quotedSubtask.map { SubtaskReference(subtask: $0) }

        viewModel.sendMessage(
            content: text,
            referencedTask: TaskReference(task: currentTask),
            referencedSubtask: subtaskRef,
            quotedMessage: quoted
        )
        commentText = ""
        quotedMessage = nil
        quotedSubtask = nil
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

    @State private var showingEmojiPicker = false
    private let quickEmojis = ["👍", "❤️", "😂", "😮", "😢", "🙏"]

    private var isCurrentUser: Bool {
        message.sender.id == viewModel.currentUser.id
    }

    // Check if message references a subtask
    private var referencedSubtask: Subtask? {
        guard let ref = message.referencedSubtask else { return nil }
        return task.subtasks.first { $0.id == ref.subtaskId }
    }

    var body: some View {
        HStack(alignment: .bottom, spacing: 10) {
            if isCurrentUser { Spacer(minLength: 60) }

            if !isCurrentUser {
                Circle()
                    .fill(Theme.primaryLight)
                    .frame(width: 32, height: 32)
                    .overlay {
                        Text(message.sender.avatarInitials)
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Theme.primary)
                    }
            }

            VStack(alignment: isCurrentUser ? .trailing : .leading, spacing: 6) {
                // Subtask reference indicator
                if let subtask = referencedSubtask {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.turn.down.right")
                            .font(.system(size: 10))
                        Text("Re: \(subtask.title)")
                            .font(.system(size: 12, weight: .medium))
                            .lineLimit(1)
                    }
                    .foregroundStyle(Theme.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.primaryLight)
                    .clipShape(Capsule())
                }

                VStack(alignment: .leading, spacing: 6) {
                    if !isCurrentUser {
                        Text(message.sender.displayFirstName)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(Theme.primary)
                    }

                    // Quoted message preview
                    if let quoted = message.quotedMessage {
                        HStack(spacing: 8) {
                            Rectangle()
                                .fill(isCurrentUser ? Color.white.opacity(0.5) : Theme.primary)
                                .frame(width: 2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(quoted.senderName)
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(isCurrentUser ? .white.opacity(0.9) : Theme.primary)
                                Text(quoted.content)
                                    .font(.system(size: 12))
                                    .foregroundStyle(isCurrentUser ? .white.opacity(0.7) : .secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(8)
                        .background(isCurrentUser ? Color.white.opacity(0.15) : Color(uiColor: .secondarySystemGroupedBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    Text(message.content)
                        .font(.system(size: 15))
                        .foregroundStyle(isCurrentUser ? .white : .primary)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(message.timestamp.formatted(.dateTime.hour().minute()))
                        .font(.system(size: 11))
                        .foregroundStyle(isCurrentUser ? .white.opacity(0.7) : .secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(isCurrentUser ? Theme.primary : Color(uiColor: .tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

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
                                    viewModel.addReaction(emoji, to: message)
                                }
                            }
                        }
                    }
                }
            }
            .contentShape(Rectangle())
            .onLongPressGesture {
                showingEmojiPicker = true
            }
            .popover(isPresented: $showingEmojiPicker) {
                emojiPickerView
                    .presentationCompactAdaptation(.popover)
            }

            if !isCurrentUser { Spacer(minLength: 60) }
        }
    }

    private var emojiPickerView: some View {
        HStack(spacing: 12) {
            ForEach(quickEmojis, id: \.self) { emoji in
                Button {
                    viewModel.addReaction(emoji, to: message)
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


// MARK: - Task Instructions Sheet

struct TaskInstructionsSheet: View {
    let task: DONEOTask
    @Environment(\.dismiss) private var dismiss

    // Categorize attachments
    private var photoCount: Int {
        task.attachments.filter { $0.type == .image }.count
    }

    private var documentCount: Int {
        task.attachments.filter { $0.type == .document }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Instructions section (notes + instruction attachments)
                    let instructionAttachments = task.attachments.filter { $0.isInstruction }
                    if (task.notes != nil && !task.notes!.isEmpty) || !instructionAttachments.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Instrucciones")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                // Notes text
                                if let notes = task.notes, !notes.isEmpty {
                                    Text(notes)
                                        .font(.system(size: 15))
                                        .foregroundStyle(.primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(16)

                                    if !instructionAttachments.isEmpty {
                                        Divider()
                                    }
                                }

                                // Instruction attachments (adjuntos)
                                ForEach(Array(instructionAttachments.enumerated()), id: \.element.id) { index, attachment in
                                    HStack(spacing: 12) {
                                        Image(systemName: iconForAttachment(attachment))
                                            .font(.system(size: 18))
                                            .foregroundStyle(colorForAttachment(attachment))
                                            .frame(width: 36, height: 36)
                                            .background(colorForAttachment(attachment).opacity(0.15))
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

                                    if index < instructionAttachments.count - 1 {
                                        Divider()
                                            .padding(.leading, 64)
                                    }
                                }
                            }
                            .background(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Assignees section
                    if !task.assignees.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("\(task.assignees.count) Asignados")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                ForEach(Array(task.assignees.enumerated()), id: \.element.id) { index, assignee in
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

                                    if index < task.assignees.count - 1 {
                                        Divider()
                                            .padding(.leading, 74)
                                    }
                                }
                            }
                            .background(Color(uiColor: .systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    // Multimedia y Documentos section
                    if photoCount > 0 || documentCount > 0 {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Multimedia y Documentos")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 4)

                            VStack(spacing: 0) {
                                // Photos row
                                if photoCount > 0 {
                                    HStack(spacing: 14) {
                                        Image(systemName: "photo.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Theme.primary)
                                            .frame(width: 28)

                                        Text("Fotos")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        Text("\(photoCount)")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.secondary)

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.secondary.opacity(0.5))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)

                                    if documentCount > 0 {
                                        Divider()
                                            .padding(.leading, 58)
                                    }
                                }

                                // Documents row
                                if documentCount > 0 {
                                    HStack(spacing: 14) {
                                        Image(systemName: "doc.fill")
                                            .font(.system(size: 18))
                                            .foregroundStyle(Theme.primary)
                                            .frame(width: 28)

                                        Text("Documentos")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.primary)

                                        Spacer()

                                        Text("\(documentCount)")
                                            .font(.system(size: 15))
                                            .foregroundStyle(.secondary)

                                        Image(systemName: "chevron.right")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.secondary.opacity(0.5))
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 14)
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
            .navigationTitle("Info de Tarea")
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

    private func iconForAttachment(_ attachment: Attachment) -> String {
        switch attachment.type {
        case .image: return "photo.fill"
        case .document: return "doc.fill"
        case .video: return "video.fill"
        case .contact: return "person.crop.circle.fill"
        }
    }

    private func colorForAttachment(_ attachment: Attachment) -> Color {
        switch attachment.type {
        case .image: return .blue
        case .document: return .orange
        case .video: return .purple
        case .contact: return .green
        }
    }
}

// MARK: - Attachment Options Sheet

struct AttachmentOptionsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Photos option
                Button {
                    // TODO: Open photo library
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "photo.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.blue)
                            .frame(width: 44, height: 44)
                            .background(Color.blue.opacity(0.15))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Fotos")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                            Text("Comparte fotos de tu biblioteca")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }

                Divider()
                    .padding(.leading, 80)

                // Document option
                Button {
                    // TODO: Open document picker
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "doc.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.orange)
                            .frame(width: 44, height: 44)
                            .background(Color.orange.opacity(0.15))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Documento")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                            Text("Comparte archivos y documentos")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }

                Divider()
                    .padding(.leading, 80)

                // Contact option
                Button {
                    // TODO: Open contact picker
                    dismiss()
                } label: {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.green)
                            .frame(width: 44, height: 44)
                            .background(Color.green.opacity(0.15))
                            .clipShape(Circle())

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Contacto")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(.primary)
                            Text("Comparte un contacto")
                                .font(.system(size: 13))
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                }

                Spacer()
            }
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Agregar a la Discusion")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 24))
                            .foregroundStyle(Color.secondary.opacity(0.5))
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
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
