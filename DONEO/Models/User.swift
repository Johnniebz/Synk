import Foundation

struct User: Identifiable, Hashable {
    let id: UUID
    var name: String
    var phoneNumber: String
    var avatarInitials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    init(id: UUID = UUID(), name: String, phoneNumber: String) {
        self.id = id
        self.name = name
        self.phoneNumber = phoneNumber
    }

    // Display name that shows "Me" for current user
    var displayName: String {
        if id == MockDataService.shared.currentUser.id {
            return "Me"
        }
        return name
    }

    // First name only, or "Me" for current user
    var displayFirstName: String {
        if id == MockDataService.shared.currentUser.id {
            return "Me"
        }
        return name.components(separatedBy: " ").first ?? name
    }
}
