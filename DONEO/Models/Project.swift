import Foundation
import SwiftUI

// MARK: - Project Attachment

struct ProjectAttachment: Identifiable, Hashable {
    let id: UUID
    let type: AttachmentType
    let fileName: String
    let fileSize: Int64
    let uploadedBy: User
    let uploadedAt: Date
    let thumbnailURL: URL?
    let fileURL: URL?
    var linkedTaskId: UUID?      // Optional link to a task
    var linkedSubtaskId: UUID?   // Optional link to a subtask
    var caption: String?

    init(
        id: UUID = UUID(),
        type: AttachmentType,
        fileName: String,
        fileSize: Int64 = 0,
        uploadedBy: User,
        uploadedAt: Date = Date(),
        thumbnailURL: URL? = nil,
        fileURL: URL? = nil,
        linkedTaskId: UUID? = nil,
        linkedSubtaskId: UUID? = nil,
        caption: String? = nil
    ) {
        self.id = id
        self.type = type
        self.fileName = fileName
        self.fileSize = fileSize
        self.uploadedBy = uploadedBy
        self.uploadedAt = uploadedAt
        self.thumbnailURL = thumbnailURL
        self.fileURL = fileURL
        self.linkedTaskId = linkedTaskId
        self.linkedSubtaskId = linkedSubtaskId
        self.caption = caption
    }

    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var iconName: String {
        switch type {
        case .image:
            return "photo.fill"
        case .video:
            return "video.fill"
        case .document:
            let ext = (fileName as NSString).pathExtension.lowercased()
            switch ext {
            case "pdf":
                return "doc.fill"
            case "doc", "docx":
                return "doc.text.fill"
            case "xls", "xlsx":
                return "tablecells.fill"
            default:
                return "paperclip"
            }
        case .contact:
            return "person.crop.circle.fill"
        }
    }
}

// MARK: - Project

struct Project: Identifiable, Hashable {
    let id: UUID
    var name: String
    var description: String?
    var members: [User]
    var tasks: [DONEOTask]
    var messages: [Message]  // Project-level chat messages
    var attachments: [ProjectAttachment]  // Project attachments linked to tasks/subtasks
    var unreadTaskIds: [UUID: Set<UUID>]  // Maps user ID to set of unread task IDs
    var lastActivity: Date?
    var lastActivityPreview: String?

    init(
        id: UUID = UUID(),
        name: String,
        description: String? = nil,
        members: [User] = [],
        tasks: [DONEOTask] = [],
        messages: [Message] = [],
        attachments: [ProjectAttachment] = [],
        unreadTaskIds: [UUID: Set<UUID>] = [:],
        lastActivity: Date? = nil,
        lastActivityPreview: String? = nil
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.members = members
        self.tasks = tasks
        self.messages = messages
        self.attachments = attachments
        self.unreadTaskIds = unreadTaskIds
        self.lastActivity = lastActivity
        self.lastActivityPreview = lastActivityPreview
    }

    // Last message for preview in HomeView
    var lastMessage: Message? {
        messages.sorted { $0.timestamp > $1.timestamp }.first
    }

    // Get unread count for current user
    var unreadCount: Int {
        let currentUserId = MockDataService.shared.currentUser.id
        return unreadTaskIds[currentUserId]?.count ?? 0
    }

    // Mark a task as read for a user
    mutating func markTaskAsRead(_ taskId: UUID, for userId: UUID) {
        unreadTaskIds[userId]?.remove(taskId)
    }

    // Add unread notification for a user
    mutating func addUnreadTask(_ taskId: UUID, for userId: UUID) {
        if unreadTaskIds[userId] == nil {
            unreadTaskIds[userId] = []
        }
        unreadTaskIds[userId]?.insert(taskId)
    }

    var pendingTaskCount: Int {
        tasks.filter { $0.status == .pending }.count
    }

    var completedTaskCount: Int {
        tasks.filter { $0.status == .done }.count
    }

    var overdueTaskCount: Int {
        tasks.filter { $0.isOverdue }.count
    }

    var initials: String {
        let parts = name.components(separatedBy: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1) + parts[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    // MARK: - Attachment Helpers

    /// Get attachments linked to a specific task
    func attachments(for taskId: UUID) -> [ProjectAttachment] {
        attachments.filter { $0.linkedTaskId == taskId }
    }

    /// Get attachments linked to a specific subtask
    func attachments(for taskId: UUID, subtaskId: UUID) -> [ProjectAttachment] {
        attachments.filter { $0.linkedTaskId == taskId && $0.linkedSubtaskId == subtaskId }
    }

    /// Get attachments not linked to any task
    var unlinkedAttachments: [ProjectAttachment] {
        attachments.filter { $0.linkedTaskId == nil }
    }

    /// Get attachments grouped by task
    var attachmentsGroupedByTask: [(task: DONEOTask?, attachments: [ProjectAttachment])] {
        var result: [(task: DONEOTask?, attachments: [ProjectAttachment])] = []

        // Group by task
        for task in tasks {
            let taskAttachments = attachments(for: task.id)
            if !taskAttachments.isEmpty {
                result.append((task: task, attachments: taskAttachments))
            }
        }

        // Add unlinked
        let unlinked = unlinkedAttachments
        if !unlinked.isEmpty {
            result.append((task: nil, attachments: unlinked))
        }

        return result
    }
}
