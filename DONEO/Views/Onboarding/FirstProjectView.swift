import SwiftUI

struct FirstProjectView: View {
    @Binding var projectName: String
    @Binding var projectDescription: String
    let onCreateProject: () -> Void
    let onSkip: () -> Void
    @FocusState private var isNameFocused: Bool

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Header
            VStack(spacing: 12) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(Theme.primary)

                Text("Crea tu primer proyecto")
                    .font(.system(size: 24, weight: .bold))

                Text("Los proyectos te ayudan a organizar el trabajo por sitio, cliente o equipo")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Project name input
            VStack(alignment: .leading, spacing: 8) {
                Text("Nombre del proyecto")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("ej. Renovación de Cocina", text: $projectName)
                    .font(.system(size: 20))
                    .focused($isNameFocused)
                    .submitLabel(.next)
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Project description input
            VStack(alignment: .leading, spacing: 8) {
                Text("Descripción (Opcional)")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(.secondary)

                TextField("¿De qué se trata este proyecto?", text: $projectDescription, axis: .vertical)
                    .font(.system(size: 17))
                    .lineLimit(2...4)
                    .submitLabel(.done)
                    .onSubmit {
                        if !projectName.trimmingCharacters(in: .whitespaces).isEmpty {
                            onCreateProject()
                        }
                    }
                    .padding()
                    .background(Color(uiColor: .secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }

            // Create button
            Button(action: onCreateProject) {
                Text("Crear Proyecto")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        projectName.trimmingCharacters(in: .whitespaces).isEmpty
                        ? Theme.primary.opacity(0.5)
                        : Theme.primary
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .disabled(projectName.trimmingCharacters(in: .whitespaces).isEmpty)

            // Skip option
            Button(action: onSkip) {
                Text("Saltar por ahora")
                    .font(.system(size: 15))
                    .foregroundStyle(.secondary)
            }

            Spacer()
                .frame(height: 40)
        }
        .padding(.horizontal, 24)
        .onAppear {
            isNameFocused = true
        }
    }
}

#Preview {
    FirstProjectView(projectName: .constant(""), projectDescription: .constant(""), onCreateProject: {}, onSkip: {})
}
