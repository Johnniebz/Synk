import SwiftUI

struct GroupChatView: View {
    @State private var viewModel: GroupChatViewModel
    @FocusState private var isInputFocused: Bool

    init(project: Project) {
        _viewModel = State(initialValue: GroupChatViewModel(project: project))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            if viewModel.messages.isEmpty {
                emptyState
            } else {
                messagesList
            }

            Divider()

            // Input field
            inputField
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundStyle(.tertiary)
            Text("No hay mensajes aun")
                .font(.headline)
                .foregroundStyle(.secondary)
            Text("Inicia la conversacion")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(viewModel.messages) { message in
                        GroupMessageBubble(message: message)
                            .id(message.id)
                    }
                }
                .padding()
            }
            .onChange(of: viewModel.messages.count) { _, _ in
                if let lastMessage = viewModel.messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
            .onAppear {
                if let lastMessage = viewModel.messages.last {
                    proxy.scrollTo(lastMessage.id, anchor: .bottom)
                }
            }
        }
    }

    private var inputField: some View {
        HStack(spacing: 12) {
            TextField("Mensaje...", text: $viewModel.newMessageText, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...4)
                .focused($isInputFocused)
                .submitLabel(.send)
                .onSubmit {
                    viewModel.sendMessage()
                }

            Button {
                viewModel.sendMessage()
                isInputFocused = false
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 28))
                    .foregroundColor(
                        viewModel.newMessageText.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Color.secondary
                        : Theme.primary
                    )
            }
            .disabled(viewModel.newMessageText.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(uiColor: .systemBackground))
    }
}

struct GroupMessageBubble: View {
    let message: Message

    var body: some View {
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

                Text(message.content)
                    .font(.system(size: 15))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.isFromCurrentUser
                        ? Theme.primary
                        : Color(uiColor: .systemGray5)
                    )
                    .foregroundStyle(message.isFromCurrentUser ? .white : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                Text(formatTimestamp(message.timestamp))
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
            }

            if !message.isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
    }

    private func formatTimestamp(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return date.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(date) {
            return "Ayer " + date.formatted(date: .omitted, time: .shortened)
        } else {
            return date.formatted(date: .abbreviated, time: .shortened)
        }
    }
}

#Preview {
    GroupChatView(project: Project(
        name: "Test Project",
        members: [
            User(name: "Alex Johnson", phoneNumber: "+1 555-0100"),
            User(name: "Maria Garcia", phoneNumber: "+1 555-0101")
        ]
    ))
}
