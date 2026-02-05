import Foundation

struct DONEOTask: Identifiable, Hashable {
    let id: UUID
    var title: String
    var assignees: [User] // Multiple assignees
    var status: TaskStatus
    var dueDate: Date?
    var createdAt: Date
    var lastActivity: Date
    var subtasks: [Subtask]
    var attachments: [Attachment]
    var notes: String? // Initial notes/description added when creating the task
    var createdBy: User? // Who created the task
    var acknowledgedBy: Set<UUID> // User IDs who have accepted this task assignment

    init(
        id: UUID = UUID(),
        title: String,
        assignees: [User] = [],
        status: TaskStatus = .pending,
        dueDate: Date? = nil,
        createdAt: Date = Date(),
        lastActivity: Date? = nil,
        subtasks: [Subtask] = [],
        attachments: [Attachment] = [],
        notes: String? = nil,
        createdBy: User? = nil,
        acknowledgedBy: Set<UUID> = []
    ) {
        self.id = id
        self.title = title
        self.assignees = assignees
        self.status = status
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.lastActivity = lastActivity ?? createdAt
        self.subtasks = subtasks
        self.attachments = attachments
        self.notes = notes
        self.createdBy = createdBy
        self.acknowledgedBy = acknowledgedBy
    }

    // Check if a specific user has acknowledged this task
    func isAcknowledged(by userId: UUID) -> Bool {
        acknowledgedBy.contains(userId)
    }

    // Check if task is new (unacknowledged) for a specific user
    func isNew(for userId: UUID) -> Bool {
        assignees.contains { $0.id == userId } && !acknowledgedBy.contains(userId)
    }

    // Convenience for backward compatibility
    var assignee: User? {
        assignees.first
    }

    var isOverdue: Bool {
        guard let dueDate = dueDate, status == .pending else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }

    var isDueToday: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInToday(dueDate)
    }

    var isDueTomorrow: Bool {
        guard let dueDate = dueDate else { return false }
        return Calendar.current.isDateInTomorrow(dueDate)
    }
}

enum TaskStatus: String, CaseIterable {
    case pending = "Pending"
    case done = "Done"
}

struct Subtask: Identifiable, Hashable {
    let id: UUID
    var title: String
    var description: String? // Instructions/details for this subtask
    var isDone: Bool
    var assignees: [User] // Multiple assignees
    var dueDate: Date?
    var createdBy: User?
    var createdAt: Date
    var attachments: [Attachment] // Support documents and deliverables

    init(id: UUID = UUID(), title: String, description: String? = nil, isDone: Bool = false, assignees: [User] = [], dueDate: Date? = nil, createdBy: User? = nil, createdAt: Date = Date(), attachments: [Attachment] = []) {
        self.id = id
        self.title = title
        self.description = description
        self.isDone = isDone
        self.assignees = assignees
        self.dueDate = dueDate
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.attachments = attachments
    }

    // Convenience for backward compatibility
    var assignee: User? {
        assignees.first
    }

    var isOverdue: Bool {
        guard let dueDate = dueDate, !isDone else { return false }
        return dueDate < Calendar.current.startOfDay(for: Date())
    }

    // Instruction attachments (from creator)
    var instructionAttachments: [Attachment] {
        attachments.filter { $0.isInstruction }
    }

    // Deliverable attachments (from team)
    var deliverableAttachments: [Attachment] {
        attachments.filter { $0.isDeliverable }
    }
}

// MARK: - Attachment

enum AttachmentType: String, Hashable {
    case image
    case document
    case video
    case contact
}

enum AttachmentCategory: String, Hashable {
    case reference  // Files added as part of task instructions (specs, blueprints, reference photos)
    case work       // Files uploaded by workers (progress photos, completion photos, invoices)
}

struct Attachment: Identifiable, Hashable {
    let id: UUID
    let type: AttachmentType
    let category: AttachmentCategory
    let fileName: String
    let fileSize: Int64 // bytes
    let uploadedBy: User
    let uploadedAt: Date
    let thumbnailURL: URL? // For images/videos
    let fileURL: URL?
    let linkedSubtaskId: UUID? // Optional link to a specific subtask
    let caption: String? // Optional description (mainly for work uploads)

    init(
        id: UUID = UUID(),
        type: AttachmentType,
        category: AttachmentCategory = .reference,
        fileName: String,
        fileSize: Int64 = 0,
        uploadedBy: User,
        uploadedAt: Date = Date(),
        thumbnailURL: URL? = nil,
        fileURL: URL? = nil,
        linkedSubtaskId: UUID? = nil,
        caption: String? = nil
    ) {
        self.id = id
        self.type = type
        self.category = category
        self.fileName = fileName
        self.fileSize = fileSize
        self.uploadedBy = uploadedBy
        self.uploadedAt = uploadedAt
        self.thumbnailURL = thumbnailURL
        self.fileURL = fileURL
        self.linkedSubtaskId = linkedSubtaskId
        self.caption = caption
    }

    var fileSizeFormatted: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    /// True if this is an instruction/reference attachment (from task creator)
    var isInstruction: Bool {
        category == .reference
    }

    /// True if this is a deliverable/work attachment (from team members)
    var isDeliverable: Bool {
        category == .work
    }

    var fileExtension: String {
        (fileName as NSString).pathExtension.lowercased()
    }

    var iconName: String {
        switch type {
        case .image:
            return "photo.fill"
        case .video:
            return "video.fill"
        case .document:
            switch fileExtension {
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
