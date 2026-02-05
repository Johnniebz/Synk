import Foundation
import Observation

@Observable
final class HomeViewModel {
    private var dataService = MockDataService.shared
    var searchText: String = ""
    var isLoading: Bool = false

    var projects: [Project] {
        dataService.projects
    }

    var filteredProjects: [Project] {
        let sorted = projects.sorted { p1, p2 in
            let date1 = p1.lastActivity ?? .distantPast
            let date2 = p2.lastActivity ?? .distantPast
            return date1 > date2
        }
        if searchText.isEmpty {
            return sorted
        }
        return sorted.filter { project in
            project.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var totalUnreadCount: Int {
        projects.reduce(0) { $0 + $1.unreadCount }
    }

    init() {
        loadProjects()
    }

    func loadProjects() {
        isLoading = true
        dataService.loadProjects()
        isLoading = false
    }

    func createProject(name: String, description: String? = nil) {
        let currentUser = dataService.currentUser
        let newProject = Project(
            name: name,
            description: description,
            members: [currentUser],
            lastActivity: Date()
        )
        dataService.projects.insert(newProject, at: 0)
    }

    func createProject(name: String, description: String? = nil, selectedContacts: [Contact], pendingInvites: [NewProjectFlowView.PendingInvite]) {
        let currentUser = dataService.currentUser

        // Convert selected contacts to Users (for those on Synk)
        var members: [User] = [currentUser]
        for contact in selectedContacts where contact.isOnDONEO {
            // Find matching user in mock data
            if let user = MockDataService.allUsers.first(where: { $0.phoneNumber == contact.phoneNumber }) {
                if !members.contains(where: { $0.id == user.id }) {
                    members.append(user)
                }
            }
        }

        let newProject = Project(
            name: name,
            description: description,
            members: members,
            lastActivity: Date(),
            lastActivityPreview: "Project created"
        )
        dataService.projects.insert(newProject, at: 0)

        // In production: send SMS invites to pendingInvites and contacts not on Synk
        // For now, we just create the project with available members
    }

    func deleteProject(_ project: Project) {
        dataService.projects.removeAll { $0.id == project.id }
    }
}
