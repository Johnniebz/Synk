import SwiftUI

struct SubtaskListView: View {
    @Bindable var viewModel: TaskDetailViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with progress
            HStack {
                Text("Subtareas")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                if !viewModel.task.subtasks.isEmpty {
                    Text("\(viewModel.completedSubtaskCount)/\(viewModel.task.subtasks.count)")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                Button {
                    viewModel.isAddingSubtask = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.primary)
                }
            }

            // Progress bar
            if !viewModel.task.subtasks.isEmpty {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.secondary.opacity(0.2))
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: geometry.size.width * viewModel.subtaskProgress, height: 4)
                    }
                }
                .frame(height: 4)
            }

            // Subtask list
            ForEach(viewModel.task.subtasks) { subtask in
                SubtaskRow(subtask: subtask) {
                    viewModel.toggleSubtask(subtask)
                } onDelete: {
                    viewModel.deleteSubtask(subtask)
                }
            }

            // Add subtask field
            if viewModel.isAddingSubtask {
                HStack(spacing: 8) {
                    Image(systemName: "circle")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)

                    TextField("Que hay que hacer?", text: $viewModel.newSubtaskTitle)
                        .textFieldStyle(.plain)
                        .submitLabel(.done)
                        .onSubmit {
                            viewModel.addSubtask()
                        }

                    Button("Agregar") {
                        viewModel.addSubtask()
                    }
                    .font(.system(size: 14, weight: .medium))
                    .disabled(viewModel.newSubtaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)

                    Button {
                        viewModel.isAddingSubtask = false
                        viewModel.newSubtaskTitle = ""
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }
}

struct SubtaskRow: View {
    let subtask: Subtask
    let onToggle: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onToggle) {
                Image(systemName: subtask.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18))
                    .foregroundStyle(subtask.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)

            Text(subtask.title)
                .font(.system(size: 15))
                .foregroundStyle(subtask.isDone ? .secondary : .primary)
                .strikethrough(subtask.isDone)

            Spacer()

            Button(action: onDelete) {
                Image(systemName: "trash")
                    .font(.system(size: 14))
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, 4)
    }
}
