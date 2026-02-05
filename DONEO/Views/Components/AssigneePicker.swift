import SwiftUI

struct AssigneePicker: View {
    @Binding var selectedUser: User?
    let members: [User]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    // Unassigned option
                    Button {
                        selectedUser = nil
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "person.slash")
                                .foregroundColor(.secondary)
                                .frame(width: 32)
                            Text("Sin asignar")
                            Spacer()
                            if selectedUser == nil {
                                Image(systemName: "checkmark")
                                    .foregroundColor(Theme.primary)
                            }
                        }
                    }
                    .foregroundColor(.primary)

                    // Members
                    ForEach(members) { member in
                        Button {
                            selectedUser = member
                            dismiss()
                        } label: {
                            HStack {
                                ZStack {
                                    Circle()
                                        .fill(Theme.primaryLight)
                                        .frame(width: 32, height: 32)
                                    Text(member.avatarInitials)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(Theme.primary)
                                }
                                Text(member.name)
                                Spacer()
                                if selectedUser?.id == member.id {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(Theme.primary)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
            }
            .navigationTitle("Asignar a")
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

// MARK: - Assignee Display Helper

struct AssigneeLabel: View {
    let user: User?
    var compact: Bool = false

    var body: some View {
        HStack(spacing: compact ? 4 : 8) {
            if let user = user {
                if !compact {
                    ZStack {
                        Circle()
                            .fill(Theme.primaryLight)
                            .frame(width: 24, height: 24)
                        Text(user.avatarInitials)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(Theme.primary)
                    }
                }
                Text(compact ? user.displayFirstName : user.displayName)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "person")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                Text("Sin asignar")
                    .font(.system(size: 13))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

#Preview {
    AssigneePicker(
        selectedUser: .constant(nil),
        members: [
            User(name: "Maria Garcia", phoneNumber: "+1 555-0101"),
            User(name: "James Wilson", phoneNumber: "+1 555-0102")
        ]
    )
}
