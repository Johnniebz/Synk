import Foundation
import Observation

@Observable
final class GroupChatViewModel {
    var project: Project
    var messages: [Message] = []
    var newMessageText: String = ""

    init(project: Project) {
        self.project = project
        loadMockMessages()
    }

    func sendMessage() {
        guard !newMessageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        let currentUser = MockDataService.shared.currentUser
        let message = Message(
            content: newMessageText,
            sender: currentUser,
            isFromCurrentUser: true
        )
        messages.append(message)
        newMessageText = ""
    }

    private func loadMockMessages() {
        guard project.members.count > 1 else { return }
        let currentUser = MockDataService.shared.currentUser
        let otherMembers = project.members.filter { $0.id != currentUser.id }

        guard let firstMember = otherMembers.first else { return }

        messages = [
            Message(
                content: "Hey team, just checking in on progress",
                sender: currentUser,
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date(),
                isFromCurrentUser: true
            ),
            Message(
                content: "Making good progress! Should be done by end of day",
                sender: firstMember,
                timestamp: Calendar.current.date(byAdding: .hour, value: -20, to: Date()) ?? Date(),
                isFromCurrentUser: false
            ),
            Message(
                content: "Great, let me know if you need any help",
                sender: currentUser,
                timestamp: Calendar.current.date(byAdding: .hour, value: -19, to: Date()) ?? Date(),
                isFromCurrentUser: true
            )
        ]

        if otherMembers.count > 1 {
            messages.append(Message(
                content: "I can help with that too if needed",
                sender: otherMembers[1],
                timestamp: Calendar.current.date(byAdding: .hour, value: -18, to: Date()) ?? Date(),
                isFromCurrentUser: false
            ))
        }
    }
}
