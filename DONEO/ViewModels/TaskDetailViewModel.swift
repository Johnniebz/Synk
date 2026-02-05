import Foundation
import Observation

@Observable
final class TaskDetailViewModel {
    var task: DONEOTask
    var messages: [Message] = []
    var newMessageText: String = ""
    var newSubtaskTitle: String = ""
    var isAddingSubtask: Bool = false
    var referencedTaskForMessage: TaskReference? = nil
    var referencedSubtaskForMessage: SubtaskReference? = nil
    var members: [User]
    let allProjectTasks: [DONEOTask]
    let projectMembers: [User] // All available project members for adding
    var isMuted: Bool = false

    init(task: DONEOTask, members: [User], allProjectTasks: [DONEOTask] = []) {
        self.task = task
        self.members = members
        self.projectMembers = members
        self.allProjectTasks = allProjectTasks.filter { $0.id != task.id } // Exclude current task
        loadMockMessages()
    }

    // MARK: - Admin & Permissions

    var currentUser: User {
        MockDataService.shared.currentUser
    }

    var isAdmin: Bool {
        // Task creator is admin, or if no creator, first assignee or current user
        if let creator = task.createdBy {
            return creator.id == currentUser.id
        }
        return task.assignees.first?.id == currentUser.id || task.assignees.isEmpty
    }

    // MARK: - Member Management (Admin only)

    func removeMember(_ user: User) {
        guard isAdmin else { return }
        members.removeAll { $0.id == user.id }
        // Also remove from assignees if assigned
        task.assignees.removeAll { $0.id == user.id }
    }

    func addMember(_ user: User) {
        guard isAdmin else { return }
        if !members.contains(where: { $0.id == user.id }) {
            members.append(user)
        }
    }

    var availableMembersToAdd: [User] {
        projectMembers.filter { projectMember in
            !members.contains { $0.id == projectMember.id }
        }
    }

    func toggleTaskStatus() {
        task.status = task.status == .pending ? .done : .pending
    }

    func toggleAssignee(_ user: User) {
        if let index = task.assignees.firstIndex(where: { $0.id == user.id }) {
            task.assignees.remove(at: index)
        } else {
            task.assignees.append(user)
        }
    }

    func clearAllAssignees() {
        task.assignees = []
    }

    // MARK: - Subtasks

    func addSubtask() {
        guard !newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let subtask = Subtask(title: newSubtaskTitle, createdBy: currentUser)
        task.subtasks.append(subtask)
        newSubtaskTitle = ""
        isAddingSubtask = false
    }

    func toggleSubtask(_ subtask: Subtask) {
        guard let index = task.subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
        task.subtasks[index].isDone.toggle()

        // Add a message to the chat when subtask status changes
        let isNowDone = task.subtasks[index].isDone
        let subtaskRef = SubtaskReference(subtask: task.subtasks[index])
        let messageType: MessageType = isNowDone ? .subtaskCompleted(subtaskRef) : .subtaskReopened(subtaskRef)
        let content = isNowDone
            ? "completed \"\(subtask.title)\""
            : "reopened \"\(subtask.title)\""

        let message = Message(
            content: content,
            sender: currentUser,
            isFromCurrentUser: true,
            referencedSubtask: subtaskRef,
            messageType: messageType
        )
        messages.append(message)
    }

    func deleteSubtask(_ subtask: Subtask) {
        task.subtasks.removeAll { $0.id == subtask.id }
    }

    func updateSubtask(_ subtask: Subtask, newTitle: String) {
        guard let index = task.subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
        task.subtasks[index].title = newTitle
    }

    func updateSubtaskDescription(_ subtask: Subtask, description: String?) {
        guard let index = task.subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
        task.subtasks[index].description = description
    }

    func updateSubtaskAssignees(_ subtask: Subtask, assignees: [User]) {
        guard let index = task.subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
        task.subtasks[index].assignees = assignees
    }

    func toggleSubtaskAssignee(_ subtask: Subtask, member: User) {
        guard let index = task.subtasks.firstIndex(where: { $0.id == subtask.id }) else { return }
        if let memberIndex = task.subtasks[index].assignees.firstIndex(where: { $0.id == member.id }) {
            task.subtasks[index].assignees.remove(at: memberIndex)
        } else {
            task.subtasks[index].assignees.append(member)
        }
    }

    func canEditSubtask(_ subtask: Subtask) -> Bool {
        // Creator can edit, or admin can edit, or if no creator anyone can edit
        if let creator = subtask.createdBy {
            return creator.id == currentUser.id || isAdmin
        }
        return true // No creator means anyone can edit (legacy subtasks)
    }

    var completedSubtaskCount: Int {
        task.subtasks.filter { $0.isDone }.count
    }

    var subtaskProgress: Double {
        guard !task.subtasks.isEmpty else { return 0 }
        return Double(completedSubtaskCount) / Double(task.subtasks.count)
    }

    // MARK: - Attachments

    func addAttachment(_ attachment: Attachment) {
        task.attachments.append(attachment)
    }

    func removeAttachment(_ attachment: Attachment) {
        task.attachments.removeAll { $0.id == attachment.id }
    }

    var mediaAttachments: [Attachment] {
        task.attachments.filter { $0.type == .image || $0.type == .video }
    }

    var docAttachments: [Attachment] {
        task.attachments.filter { $0.type == .document }
    }

    func attachmentsForSubtask(_ subtaskId: UUID?) -> [Attachment] {
        task.attachments.filter { $0.linkedSubtaskId == subtaskId }
    }

    func subtaskName(for subtaskId: UUID) -> String? {
        task.subtasks.first { $0.id == subtaskId }?.title
    }

    // MARK: - Messages

    func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let currentUser = MockDataService.shared.currentUser
        let message = Message(
            content: newMessageText,
            sender: currentUser,
            isFromCurrentUser: true,
            referencedTask: referencedTaskForMessage,
            referencedSubtask: referencedSubtaskForMessage
        )
        messages.append(message)
        newMessageText = ""
        referencedTaskForMessage = nil
        referencedSubtaskForMessage = nil
    }

    func sendContactMessage(contact: Contact) {
        let currentUser = MockDataService.shared.currentUser
        let message = Message(
            content: "Shared contact: \(contact.name)\n\(contact.phoneNumber)",
            sender: currentUser,
            isFromCurrentUser: true
        )
        messages.append(message)
    }

    private func loadMockMessages() {
        let currentUser = MockDataService.shared.currentUser
        var loadedMessages: [Message] = []

        // Check if this is a task created by the user (has createdBy or notes or initial attachments)
        let isUserCreatedTask = task.createdBy != nil || task.notes != nil

        // If task has notes or attachments, add them as the first message from the creator
        if isUserCreatedTask {
            let creator = task.createdBy ?? currentUser
            let isFromCurrentUser = creator.id == currentUser.id

            // Notes message
            if let notes = task.notes, !notes.isEmpty {
                let notesMessage = Message(
                    content: notes,
                    sender: creator,
                    timestamp: task.createdAt,
                    isFromCurrentUser: isFromCurrentUser
                )
                loadedMessages.append(notesMessage)
            }

            // Show attachments count if any were added at creation
            if !task.attachments.isEmpty {
                let attachmentText = task.attachments.count == 1
                    ? "Attached 1 file"
                    : "Attached \(task.attachments.count) files"
                let attachmentMessage = Message(
                    content: attachmentText,
                    sender: creator,
                    timestamp: task.createdAt.addingTimeInterval(1), // Slightly after notes
                    isFromCurrentUser: isFromCurrentUser
                )
                loadedMessages.append(attachmentMessage)
            }
        } else {
            // For mock/demo tasks, add demo conversation if there's an assignee
            if let assignee = task.assignee {
                loadedMessages.append(contentsOf: [
                    Message(
                        content: "I'll start working on this today",
                        sender: assignee,
                        timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: Date()) ?? Date(),
                        isFromCurrentUser: false
                    ),
                    Message(
                        content: "Great, let me know if you need anything",
                        sender: currentUser,
                        timestamp: Calendar.current.date(byAdding: .hour, value: -1, to: Date()) ?? Date(),
                        isFromCurrentUser: true
                    )
                ])
            }
        }

        messages = loadedMessages
    }
}
