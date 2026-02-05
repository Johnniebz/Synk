import Foundation
import Observation

// MARK: - Activity Model

enum ActivityType: String {
    case taskAssigned = "assigned"
    case taskCompleted = "completed"
    case taskReopened = "reopened"
    case taskCreated = "created"
    case messageSent = "message"
}

struct Activity: Identifiable {
    let id: UUID
    let type: ActivityType
    let timestamp: Date
    let actorId: UUID      // Who performed the action
    let actorName: String
    let projectId: UUID
    let projectName: String
    let taskId: UUID?
    let taskTitle: String?
    let messagePreview: String?

    init(
        id: UUID = UUID(),
        type: ActivityType,
        timestamp: Date = Date(),
        actor: User,
        project: Project,
        task: DONEOTask? = nil,
        messagePreview: String? = nil
    ) {
        self.id = id
        self.type = type
        self.timestamp = timestamp
        self.actorId = actor.id
        self.actorName = actor.name
        self.projectId = project.id
        self.projectName = project.name
        self.taskId = task?.id
        self.taskTitle = task?.title
        self.messagePreview = messagePreview
    }

    var description: String {
        let firstName = actorName.components(separatedBy: " ").first ?? actorName
        switch type {
        case .taskAssigned:
            return "\(firstName) te asigno: \(taskTitle ?? "una tarea")"
        case .taskCompleted:
            return "\(firstName) completo: \(taskTitle ?? "una tarea")"
        case .taskReopened:
            return "\(firstName) reabrio: \(taskTitle ?? "una tarea")"
        case .taskCreated:
            return "\(firstName) creo: \(taskTitle ?? "una tarea")"
        case .messageSent:
            return "\(firstName): \(messagePreview ?? "envio un mensaje")"
        }
    }

    var icon: String {
        switch type {
        case .taskAssigned: return "person.badge.plus"
        case .taskCompleted: return "checkmark.circle.fill"
        case .taskReopened: return "arrow.uturn.backward.circle"
        case .taskCreated: return "plus.circle.fill"
        case .messageSent: return "message.fill"
        }
    }

    var iconColor: String {
        switch type {
        case .taskAssigned: return "blue"
        case .taskCompleted: return "green"
        case .taskReopened: return "orange"
        case .taskCreated: return "purple"
        case .messageSent: return "blue"
        }
    }
}

// MARK: - Mock Data Service

@Observable
final class MockDataService {
    static let shared = MockDataService()

    private init() {
        _currentUser = Self.allUsers[0]
    }

    // MARK: - Mock Users

    static let allUsers: [User] = [
        User(name: "Alejandro Martinez", phoneNumber: "+34 612-345-678"),
        User(name: "Maria Garcia", phoneNumber: "+34 623-456-789"),
        User(name: "Diego Lopez", phoneNumber: "+34 634-567-890"),
        User(name: "Sara Chen", phoneNumber: "+34 645-678-901"),
        User(name: "Miguel Torres", phoneNumber: "+34 656-789-012")
    ]

    private var _currentUser: User

    var currentUser: User {
        get { _currentUser }
        set { _currentUser = newValue }
    }

    var mockUsers: [User] {
        Self.allUsers
    }

    func switchUser(to user: User) {
        _currentUser = user
    }

    var currentUserIndex: Int {
        Self.allUsers.firstIndex(where: { $0.id == currentUser.id }) ?? 0
    }

    // MARK: - Projects (shared data store)

    var projects: [Project] = []

    func loadProjects() {
        if projects.isEmpty {
            projects = createMockProjects()
        }
    }

    func updateProject(_ project: Project) {
        if let index = projects.firstIndex(where: { $0.id == project.id }) {
            projects[index] = project
        }
    }

    // MARK: - Activities (timeline)

    var activities: [Activity] = []

    func addActivity(type: ActivityType, actor: User, project: Project, task: DONEOTask? = nil, messagePreview: String? = nil) {
        let activity = Activity(
            type: type,
            actor: actor,
            project: project,
            task: task,
            messagePreview: messagePreview
        )
        activities.insert(activity, at: 0)
    }

    // Activities for current user (excludes own actions)
    var activitiesForCurrentUser: [Activity] {
        activities.filter { $0.actorId != currentUser.id }
    }

    func loadMockActivities() {
        guard activities.isEmpty else { return }
        let maria = Self.allUsers[1]
        let diego = Self.allUsers[2]
        let sara = Self.allUsers[3]

        guard let project1 = projects.first,
              let project2 = projects.dropFirst().first else { return }

        // Create some mock activities
        activities = [
            Activity(type: .messageSent, timestamp: Date().addingTimeInterval(-300), actor: maria, project: project1, messagePreview: "Puedes revisar las medidas?"),
            Activity(type: .taskCompleted, timestamp: Date().addingTimeInterval(-1800), actor: diego, project: project1, task: project1.tasks.first { $0.status == .done }),
            Activity(type: .taskAssigned, timestamp: Date().addingTimeInterval(-3600), actor: sara, project: project2, task: project2.tasks.first),
            Activity(type: .taskCreated, timestamp: Date().addingTimeInterval(-7200), actor: maria, project: project1, task: project1.tasks.first),
            Activity(type: .messageSent, timestamp: Date().addingTimeInterval(-86400), actor: diego, project: project1, messagePreview: "Terminare el azulejo manana"),
        ]
    }

    func project(withId id: UUID) -> Project? {
        projects.first { $0.id == id }
    }

    // MARK: - Mock Projects

    private func createMockProjects() -> [Project] {
        let alejandro = Self.allUsers[0]
        let maria = Self.allUsers[1]
        let diego = Self.allUsers[2]
        let sara = Self.allUsers[3]
        let miguel = Self.allUsers[4]

        let today = Date()
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: today)
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: today)
        let nextWeek = Calendar.current.date(byAdding: .day, value: 5, to: today)

        // Create sample messages for projects
        let project1Messages: [Message] = [
            Message(
                content: "Empecemos a pedir los materiales de cocina esta semana",
                sender: alejandro,
                timestamp: Calendar.current.date(byAdding: .hour, value: -5, to: today) ?? today,
                isFromCurrentUser: true
            ),
            Message(
                content: "Conseguire los presupuestos de los proveedores hoy",
                sender: maria,
                timestamp: Calendar.current.date(byAdding: .hour, value: -4, to: today) ?? today,
                isFromCurrentUser: false
            ),
            Message(
                content: "Puedes revisar las medidas?",
                sender: maria,
                timestamp: Calendar.current.date(byAdding: .minute, value: -30, to: today) ?? today,
                isFromCurrentUser: false
            )
        ]

        let project2Messages: [Message] = [
            Message(
                content: "Inspeccion final programada para manana",
                sender: alejandro,
                timestamp: Calendar.current.date(byAdding: .hour, value: -3, to: today) ?? today,
                isFromCurrentUser: true
            ),
            Message(
                content: "Preparare la lista de verificacion",
                sender: sara,
                timestamp: Calendar.current.date(byAdding: .hour, value: -2, to: today) ?? today,
                isFromCurrentUser: false
            )
        ]

        let project3Messages: [Message] = [
            Message(
                content: "Las unidades de climatizacion deben pedirse antes del viernes",
                sender: miguel,
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
                isFromCurrentUser: false
            ),
            Message(
                content: "Entendido, coordinare con el proveedor",
                sender: alejandro,
                timestamp: Calendar.current.date(byAdding: .hour, value: -6, to: today) ?? today,
                isFromCurrentUser: true
            ),
            Message(
                content: "Reunion de revision de planos manana a las 10am",
                sender: maria,
                timestamp: Calendar.current.date(byAdding: .minute, value: -45, to: today) ?? today,
                isFromCurrentUser: false
            )
        ]

        let project4Messages: [Message] = [
            Message(
                content: "Los taladros necesitan mantenimiento urgente",
                sender: diego,
                timestamp: Calendar.current.date(byAdding: .day, value: -2, to: today) ?? today,
                isFromCurrentUser: false
            ),
            Message(
                content: "Ya pedi las brocas de repuesto",
                sender: miguel,
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
                isFromCurrentUser: false
            ),
            Message(
                content: "Perfecto, las brocas llegaron hoy",
                sender: alejandro,
                timestamp: Calendar.current.date(byAdding: .hour, value: -8, to: today) ?? today,
                isFromCurrentUser: true
            )
        ]

        let project5Messages: [Message] = [
            Message(
                content: "El proyecto va muy bien, el cliente esta contento",
                sender: alejandro,
                timestamp: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
                isFromCurrentUser: true
            ),
            Message(
                content: "Necesitamos enviar la factura final esta semana",
                sender: sara,
                timestamp: Calendar.current.date(byAdding: .hour, value: -8, to: today) ?? today,
                isFromCurrentUser: false
            ),
            Message(
                content: "La factura esta lista para revision",
                sender: sara,
                timestamp: Calendar.current.date(byAdding: .hour, value: -5, to: today) ?? today,
                isFromCurrentUser: false
            )
        ]

        // Create subtasks with known IDs for message references
        let subtask1_1_1 = Subtask(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Obtener presupuestos de 3 proveedores",
            isDone: true,
            assignees: [maria],
            createdBy: diego,
            attachments: [
                Attachment(type: .document, category: .reference, fileName: "Lista_Proveedores.pdf", fileSize: 125_000, uploadedBy: diego),
                Attachment(type: .document, category: .reference, fileName: "Guia_Presupuesto.xlsx", fileSize: 89_000, uploadedBy: diego)
            ]
        )
        let subtask1_1_2 = Subtask(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Comparar precios y calidad",
            isDone: true,
            assignees: [maria, diego],
            createdBy: diego,
            attachments: [
                Attachment(type: .document, category: .reference, fileName: "Plantilla_Comparacion.xlsx", fileSize: 67_000, uploadedBy: diego)
            ]
        )
        let subtask1_1_3 = Subtask(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "Realizar pedido con el proveedor seleccionado",
            isDone: false,
            assignees: [maria],
            createdBy: diego
        )
        let subtask1_1_4 = Subtask(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "Confirmar fecha de entrega",
            isDone: false,
            createdBy: diego
        )

        // Create tasks with known IDs for notification tracking
        let task1_1 = DONEOTask(
            title: "Pedir materiales para la cocina",
            assignees: [maria],
            status: .pending,
            dueDate: today,
            subtasks: [subtask1_1_1, subtask1_1_2, subtask1_1_3, subtask1_1_4],
            attachments: [
                Attachment(
                    type: .document,
                    category: .reference,
                    fileName: "Lista_Materiales_Cocina.pdf",
                    fileSize: 245_000,
                    uploadedBy: diego
                ),
                Attachment(
                    type: .image,
                    category: .reference,
                    fileName: "Plano_Cocina.jpg",
                    fileSize: 1_200_000,
                    uploadedBy: diego
                )
            ],
            notes: """
            Contacto: HomeDepot Mostrador Pro
            Telefono: (555) 123-4567
            Numero de cuenta: PRO-2847593

            Materiales necesarios:
            - 24 pies cuadrados de azulejos ceramicos (Toscana Beige)
            - 3 bolsas de mortero adhesivo
            - Lechada (color Arena)
            - Separadores de azulejos 1/4"

            Direccion de entrega:
            Calle Arce 742, Centro
            """,
            createdBy: diego
        )
        let task1_2 = DONEOTask(
            title: "Programar inspeccion electrica",
            assignees: [alejandro],
            status: .pending,
            dueDate: tomorrow,
            subtasks: [
                Subtask(title: "Llamar a la oficina del inspector", isDone: true, assignees: [alejandro], createdBy: maria),
                Subtask(title: "Preparar documentacion", isDone: false, assignees: [diego, alejandro], createdBy: maria),
                Subtask(title: "Despejar acceso al panel electrico", isDone: false, createdBy: maria)
            ],
            notes: """
            Inspector Municipal: Roberto Martinez
            Oficina: (555) 234-5678

            Documentos requeridos:
            - Permiso #EL-2024-0847
            - Planos electricos (revisados)
            - Copia de licencia del contratista

            El inspector prefiere citas por la manana (8-10am)
            """,
            createdBy: maria,
            acknowledgedBy: [alejandro.id] // Alejandro has accepted this task
        )
        let task1_3 = DONEOTask(title: "Completar azulejos del bano", assignees: [diego], status: .done, createdBy: alejandro)

        // New task for Alejandro - painting
        let task1_4_paint = DONEOTask(
            title: "Pintar paredes de la sala",
            assignees: [alejandro, diego],
            status: .pending,
            dueDate: tomorrow,
            subtasks: [
                Subtask(title: "Comprar suministros de pintura", isDone: true, assignees: [diego], createdBy: maria),
                Subtask(title: "Preparar paredes y poner cinta", isDone: false, assignees: [alejandro], createdBy: maria),
                Subtask(title: "Aplicar primera capa", isDone: false, assignees: [alejandro, diego], createdBy: maria),
                Subtask(title: "Aplicar segunda capa", isDone: false, createdBy: maria)
            ],
            notes: "Color: Benjamin Moore Blanco Nube OC-130\nSe necesitan 2 galones",
            createdBy: maria
            // Not acknowledged by Alejandro yet - NEW task
        )

        let task1_5 = DONEOTask(
            title: "Instalar ventanas nuevas",
            assignees: [alejandro],
            status: .pending,
            dueDate: nextWeek,
            subtasks: [
                Subtask(
                    title: "Medir todos los marcos de ventanas",
                    isDone: false,
                    assignees: [diego],
                    dueDate: today,
                    createdBy: diego,
                    attachments: [
                        Attachment(type: .document, category: .reference, fileName: "Guia_Medicion.pdf", fileSize: 245_000, uploadedBy: diego),
                        Attachment(type: .image, category: .reference, fileName: "Diagrama_Ventana.jpg", fileSize: 890_000, uploadedBy: diego)
                    ]
                ),
                Subtask(
                    title: "Pedir ventanas a medida",
                    isDone: false,
                    assignees: [maria, alejandro],
                    dueDate: tomorrow,
                    createdBy: diego,
                    attachments: [
                        Attachment(type: .document, category: .reference, fileName: "Catalogo_Ventanas.pdf", fileSize: 3_200_000, uploadedBy: diego),
                        Attachment(type: .document, category: .reference, fileName: "Formulario_Pedido.pdf", fileSize: 156_000, uploadedBy: diego)
                    ]
                ),
                Subtask(title: "Quitar ventanas viejas", isDone: false, createdBy: diego),
                Subtask(
                    title: "Instalar ventanas nuevas",
                    isDone: false,
                    dueDate: nextWeek,
                    createdBy: diego,
                    attachments: [
                        Attachment(type: .document, category: .reference, fileName: "Manual_Instalacion.pdf", fileSize: 1_800_000, uploadedBy: diego),
                        Attachment(type: .image, category: .reference, fileName: "Pasos_Instalacion.jpg", fileSize: 1_200_000, uploadedBy: diego),
                        Attachment(type: .image, category: .reference, fileName: "Requisitos_Seguridad.jpg", fileSize: 780_000, uploadedBy: diego)
                    ]
                ),
                Subtask(title: "Sellar y aislar", isDone: false, createdBy: diego)
            ],
            attachments: [
                Attachment(
                    type: .document,
                    category: .reference,
                    fileName: "Especificaciones_Ventana.pdf",
                    fileSize: 890_000,
                    uploadedBy: diego
                ),
                Attachment(
                    type: .image,
                    category: .reference,
                    fileName: "Foto_Medidas_Ventana.jpg",
                    fileSize: 2_400_000,
                    uploadedBy: diego
                ),
                Attachment(
                    type: .image,
                    category: .work,
                    fileName: "Ventana_Vieja_Quitada.jpg",
                    fileSize: 1_800_000,
                    uploadedBy: alejandro,
                    caption: "Primera ventana quitada exitosamente"
                )
            ],
            notes: """
            Proveedor de ventanas: ClearView Glass Co.
            Representante de ventas: Jennifer Wong
            Telefono: (555) 345-6789

            Especificaciones: Doble vidrio, Baja emisividad, Relleno de Argon
            Color del marco: Vinilo blanco

            Tiempo de entrega: 2-3 semanas para tamanos personalizados
            """,
            createdBy: diego,
            acknowledgedBy: [alejandro.id] // Alejandro acknowledged
        )

        // More tasks for Downtown Renovation
        let task1_6 = DONEOTask(
            title: "Reparar grifo con fuga en la cocina",
            assignees: [alejandro],
            status: .pending,
            dueDate: today,
            notes: "El cliente reporto fuga debajo del fregadero. Revisar sifon y conexiones.",
            createdBy: maria,
            acknowledgedBy: [alejandro.id]
        )

        let task1_7 = DONEOTask(
            title: "Instalar herrajes de gabinetes",
            assignees: [alejandro],
            status: .pending,
            subtasks: [
                Subtask(title: "Desempacar todos los herrajes", isDone: true, assignees: [alejandro], createdBy: diego),
                Subtask(title: "Marcar posiciones de perforacion", isDone: true, assignees: [alejandro], createdBy: diego),
                Subtask(title: "Instalar manijas en gabinetes superiores", isDone: false, createdBy: diego),
                Subtask(title: "Instalar manijas en gabinetes inferiores", isDone: false, createdBy: diego),
                Subtask(title: "Instalar tiradores de cajones", isDone: false, createdBy: diego)
            ],
            createdBy: diego,
            acknowledgedBy: [alejandro.id]
        )

        let task2_1 = DONEOTask(
            title: "Inspeccion final",
            assignees: [alejandro],
            status: .pending,
            dueDate: yesterday,
            subtasks: [
                Subtask(title: "Revisar todas las habitaciones", isDone: true, assignees: [alejandro], createdBy: sara),
                Subtask(title: "Probar enchufes electricos", isDone: true, createdBy: sara),
                Subtask(title: "Probar plomeria", isDone: false, assignees: [alejandro, sara], createdBy: sara),
                Subtask(title: "Documentar cualquier problema", isDone: false, assignees: [sara], createdBy: sara)
            ],
            attachments: [
                Attachment(
                    type: .document,
                    category: .reference,
                    fileName: "Lista_Verificacion_Inspeccion.pdf",
                    fileSize: 156_000,
                    uploadedBy: sara
                ),
                Attachment(
                    type: .image,
                    category: .work,
                    fileName: "Sala_Completada.jpg",
                    fileSize: 2_100_000,
                    uploadedBy: alejandro,
                    caption: "Inspeccion de sala aprobada"
                ),
                Attachment(
                    type: .image,
                    category: .work,
                    fileName: "Prueba_Enchufes_Cocina.jpg",
                    fileSize: 1_900_000,
                    uploadedBy: alejandro,
                    caption: "Todos los enchufes de cocina funcionando"
                )
            ],
            notes: """
            Propiedad: Residencia Sanchez
            Direccion: Avenida Roble 1847, Riverside

            Contacto del cliente: Sr. y Sra. Sanchez
            Telefono: (555) 456-7890

            Codigo de entrada: 4523
            Codigo de caja de llaves: 1234

            Tomar fotos de cualquier problema encontrado!
            """,
            createdBy: sara,
            acknowledgedBy: [alejandro.id] // Alejandro has accepted this task
        )
        let task2_2 = DONEOTask(title: "Reparar puerta del garaje", assignees: [sara], status: .done, createdBy: alejandro)

        // New tasks for Smith Residence
        let task2_3 = DONEOTask(
            title: "Retocar pintura en el pasillo",
            assignees: [alejandro],
            status: .pending,
            dueDate: today,
            notes: "Pequenas marcas cerca de la puerta principal. Codigo de pintura: SW7015 Gris Reposo",
            createdBy: sara
            // NEW - not acknowledged
        )

        let task2_4 = DONEOTask(
            title: "Cambiar baterias de detectores de humo",
            assignees: [alejandro, sara],
            status: .pending,
            subtasks: [
                Subtask(title: "Revisar detectores del piso de arriba", isDone: false, assignees: [alejandro], createdBy: sara),
                Subtask(title: "Revisar detectores del piso de abajo", isDone: false, assignees: [sara], createdBy: sara),
                Subtask(title: "Probar todas las alarmas", isDone: false, createdBy: sara)
            ],
            createdBy: sara,
            acknowledgedBy: [alejandro.id, sara.id]
        )

        let task3_1 = DONEOTask(
            title: "Revisar planos",
            assignees: [miguel],
            status: .pending,
            dueDate: today,
            subtasks: [
                Subtask(
                    title: "Revisar planos estructurales",
                    isDone: true,
                    assignees: [miguel],
                    createdBy: alejandro,
                    attachments: [
                        Attachment(type: .document, category: .reference, fileName: "Planos_Estructurales_v2.pdf", fileSize: 4_500_000, uploadedBy: alejandro),
                        Attachment(type: .document, category: .reference, fileName: "Calculos_Carga.xlsx", fileSize: 890_000, uploadedBy: alejandro)
                    ]
                ),
                Subtask(
                    title: "Verificar diseno electrico",
                    isDone: false,
                    assignees: [alejandro, miguel],
                    dueDate: tomorrow,
                    createdBy: alejandro,
                    attachments: [
                        Attachment(type: .document, category: .reference, fileName: "Diseno_Electrico_v3.pdf", fileSize: 2_100_000, uploadedBy: alejandro),
                        Attachment(type: .image, category: .reference, fileName: "Ubicacion_Panel.jpg", fileSize: 1_500_000, uploadedBy: alejandro),
                        Attachment(type: .document, category: .reference, fileName: "Requisitos_Codigo.pdf", fileSize: 345_000, uploadedBy: alejandro)
                    ]
                ),
                Subtask(
                    title: "Verificar rutas de plomeria",
                    isDone: false,
                    assignees: [maria],
                    dueDate: nextWeek,
                    createdBy: alejandro,
                    attachments: [
                        Attachment(type: .document, category: .reference, fileName: "Esquema_Plomeria.pdf", fileSize: 1_800_000, uploadedBy: alejandro)
                    ]
                )
            ],
            attachments: [
                // Instruction attachments (from creator)
                Attachment(
                    type: .document,
                    category: .reference,
                    fileName: "Plano_Planta_v3.pdf",
                    fileSize: 3_500_000,
                    uploadedBy: alejandro
                ),
                Attachment(
                    type: .document,
                    category: .reference,
                    fileName: "Diseno_Electrico.pdf",
                    fileSize: 1_200_000,
                    uploadedBy: alejandro
                ),
                Attachment(
                    type: .image,
                    category: .reference,
                    fileName: "Vista_General_Sitio.jpg",
                    fileSize: 2_100_000,
                    uploadedBy: alejandro
                ),
                // Deliverable attachments (from team)
                Attachment(
                    type: .image,
                    category: .work,
                    fileName: "Foto_Revision_Estructural1.jpg",
                    fileSize: 1_800_000,
                    uploadedBy: miguel,
                    caption: "Revision estructural completada"
                ),
                Attachment(
                    type: .image,
                    category: .work,
                    fileName: "Foto_Revision_Estructural2.jpg",
                    fileSize: 2_100_000,
                    uploadedBy: miguel
                ),
                Attachment(
                    type: .document,
                    category: .work,
                    fileName: "Notas_Revision.pdf",
                    fileSize: 245_000,
                    uploadedBy: miguel,
                    caption: "Mis notas de revision y hallazgos"
                ),
                Attachment(
                    type: .contact,
                    category: .work,
                    fileName: "Juan_Arquitecto.vcf",
                    fileSize: 1_200,
                    uploadedBy: maria,
                    caption: "Contacto del arquitecto del proyecto"
                )
            ],
            notes: """
            Revisar todos los planos del nuevo proyecto de edificio de oficinas.
            Prestar especial atencion a:
            - Muros de carga en pisos 2-4
            - Rutas de salida de emergencia
            - Ubicacion de ductos de climatizacion
            """,
            createdBy: alejandro
        )
        let task3_2 = DONEOTask(
            title: "Pedir unidades de climatizacion",
            assignees: [maria, alejandro],
            status: .pending,
            dueDate: nextWeek,
            notes: """
            Proveedor: Sistemas de Control Climatico
            Contacto: Tomas Rodriguez
            Telefono: (555) 567-8901
            Correo: tomas@controlclimatico.com

            Cotizacion #: CCS-2024-1847
            2x Unidades Carrier de 5 toneladas
            Total: $12,450 (incluye instalacion)

            Requiere 50% de deposito para ordenar
            """,
            createdBy: miguel,
            acknowledgedBy: [maria.id] // Maria accepted, but Alejandro hasn't yet - NEW for Alejandro
        )
        let task3_3 = DONEOTask(
            title: "Coordinar con inspector municipal",
            assignees: [alejandro],
            status: .pending,
            notes: """
            Departamento de Construccion: (555) 678-9012
            Permiso #: BLD-2024-0293

            Inspecciones necesarias:
            1. Cimentacion (APROBADA)
            2. Estructura (APROBADA)
            3. Instalacion electrica provisional (PROGRAMADA)
            4. Instalacion de plomeria provisional (PENDIENTE)
            5. Inspeccion final

            Inspector asignado: Carlos Mendez
            """,
            createdBy: maria // Maria assigned this to Alejandro - NEW task needing acknowledgment
        )
        let task3_4 = DONEOTask(title: "Completar trabajo de cimentacion", assignees: [miguel], status: .done, createdBy: alejandro)
        let task3_5 = DONEOTask(title: "Instalar plomeria provisional", assignees: [alejandro], status: .pending, dueDate: tomorrow, createdBy: miguel)

        // More tasks for Office Building
        let task3_6 = DONEOTask(
            title: "Programar vaciado de concreto",
            assignees: [alejandro],
            status: .pending,
            dueDate: nextWeek,
            notes: "Se necesitan 15 yardas cubicas. Coordinar con camion bomba.",
            createdBy: miguel,
            acknowledgedBy: [alejandro.id]
        )

        let task3_7 = DONEOTask(
            title: "Pedir paneles electricos",
            assignees: [alejandro, maria],
            status: .pending,
            dueDate: today,
            subtasks: [
                Subtask(title: "Obtener cotizacion de ElectroPro", isDone: true, assignees: [maria], createdBy: miguel),
                Subtask(title: "Confirmar especificaciones de panel con ingeniero", isDone: false, assignees: [alejandro], createdBy: miguel),
                Subtask(title: "Realizar pedido", isDone: false, createdBy: miguel)
            ],
            createdBy: miguel
            // NEW - Alejandro hasn't acknowledged
        )

        let task3_8 = DONEOTask(
            title: "Actualizar cronograma del proyecto",
            assignees: [alejandro],
            status: .pending,
            notes: "El cliente quiere el calendario revisado para el viernes al final del dia",
            createdBy: maria
            // NEW - not acknowledged
        )

        let task4_1 = DONEOTask(title: "Dar servicio a la excavadora", assignees: [diego], status: .done, createdBy: alejandro)
        let task4_2 = DONEOTask(title: "Reemplazar brocas de taladro", assignees: [miguel], status: .done, createdBy: alejandro)

        // New tasks for Equipment Maintenance
        let task4_3 = DONEOTask(
            title: "Inspeccionar arneses de seguridad",
            assignees: [alejandro],
            status: .pending,
            dueDate: tomorrow,
            notes: "Inspeccion anual vencida. Revisar los 8 arneses.",
            createdBy: diego,
            acknowledgedBy: [alejandro.id]
        )

        let task4_4 = DONEOTask(
            title: "Pedir cuchillas de repuesto",
            assignees: [alejandro, miguel],
            status: .pending,
            subtasks: [
                Subtask(title: "Revisar inventario", isDone: true, assignees: [miguel], createdBy: diego),
                Subtask(title: "Obtener cotizaciones", isDone: false, assignees: [alejandro], createdBy: diego),
                Subtask(title: "Enviar orden de compra", isDone: false, createdBy: diego)
            ],
            createdBy: diego
            // NEW - Alejandro hasn't acknowledged
        )

        let task5_1 = DONEOTask(title: "Enviar factura", assignees: [alejandro], status: .pending, dueDate: yesterday, createdBy: sara, acknowledgedBy: [alejandro.id])
        let task5_2 = DONEOTask(title: "Programar reunion de seguimiento", assignees: [sara], status: .pending, dueDate: tomorrow, createdBy: alejandro)

        // More tasks for ABC Corp
        let task5_3 = DONEOTask(
            title: "Preparar documentos de cierre de proyecto",
            assignees: [alejandro],
            status: .pending,
            dueDate: nextWeek,
            subtasks: [
                Subtask(title: "Recopilar garantias", isDone: false, assignees: [alejandro], createdBy: sara),
                Subtask(title: "Reunir planos como se construyeron", isDone: false, createdBy: sara),
                Subtask(title: "Escribir resumen del proyecto", isDone: false, assignees: [sara], createdBy: sara)
            ],
            createdBy: sara,
            acknowledgedBy: [alejandro.id]
        )

        let task5_4 = DONEOTask(
            title: "Revisar lista final de pendientes",
            assignees: [alejandro],
            status: .pending,
            dueDate: today,
            notes: "Quedan 12 puntos. Recorrido con el cliente a las 2pm.",
            createdBy: sara
            // NEW - not acknowledged
        )

        // Create mock attachments for projects
        let project1Attachments: [ProjectAttachment] = [
            ProjectAttachment(
                type: .document,
                fileName: "Cotizacion_Materiales_Cocina.pdf",
                fileSize: 245_000,
                uploadedBy: maria,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -3, to: today) ?? today,
                linkedTaskId: task1_1.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "Comparacion_Proveedores.xlsx",
                fileSize: 128_000,
                uploadedBy: maria,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -2, to: today) ?? today,
                linkedTaskId: task1_1.id
            ),
            ProjectAttachment(
                type: .image,
                fileName: "Medidas_Cocina.jpg",
                fileSize: 3_200_000,
                uploadedBy: diego,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
                linkedTaskId: task1_1.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "Permiso_Electrico.pdf",
                fileSize: 89_000,
                uploadedBy: alejandro,
                uploadedAt: Calendar.current.date(byAdding: .hour, value: -5, to: today) ?? today,
                linkedTaskId: task1_2.id
            ),
            ProjectAttachment(
                type: .image,
                fileName: "Azulejos_Bano_Completado.jpg",
                fileSize: 2_800_000,
                uploadedBy: diego,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -4, to: today) ?? today,
                linkedTaskId: task1_3.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "Especificaciones_Ventanas.pdf",
                fileSize: 156_000,
                uploadedBy: alejandro,
                uploadedAt: Calendar.current.date(byAdding: .hour, value: -2, to: today) ?? today,
                linkedTaskId: task1_5.id
            )
        ]

        let project2Attachments: [ProjectAttachment] = [
            ProjectAttachment(
                type: .document,
                fileName: "Lista_Verificacion_Inspeccion.pdf",
                fileSize: 67_000,
                uploadedBy: sara,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
                linkedTaskId: task2_1.id
            ),
            ProjectAttachment(
                type: .image,
                fileName: "Problema_Plomeria.jpg",
                fileSize: 1_950_000,
                uploadedBy: alejandro,
                uploadedAt: Calendar.current.date(byAdding: .hour, value: -3, to: today) ?? today,
                linkedTaskId: task2_1.id
            ),
            ProjectAttachment(
                type: .image,
                fileName: "Puerta_Garaje_Reparada.jpg",
                fileSize: 2_100_000,
                uploadedBy: sara,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -2, to: today) ?? today,
                linkedTaskId: task2_2.id
            )
        ]

        let project3Attachments: [ProjectAttachment] = [
            ProjectAttachment(
                type: .document,
                fileName: "Planos_Fase2_v3.pdf",
                fileSize: 4_500_000,
                uploadedBy: miguel,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -5, to: today) ?? today,
                linkedTaskId: task3_1.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "Cotizacion_Climatizacion_ControlClimatico.pdf",
                fileSize: 312_000,
                uploadedBy: maria,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -2, to: today) ?? today,
                linkedTaskId: task3_2.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "Permiso_Municipal_BLD-2024-0293.pdf",
                fileSize: 178_000,
                uploadedBy: alejandro,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -7, to: today) ?? today,
                linkedTaskId: task3_3.id
            ),
            ProjectAttachment(
                type: .image,
                fileName: "Inspeccion_Cimentacion_Aprobada.jpg",
                fileSize: 2_400_000,
                uploadedBy: miguel,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -10, to: today) ?? today,
                linkedTaskId: task3_4.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "Diseno_Plomeria.pdf",
                fileSize: 890_000,
                uploadedBy: alejandro,
                uploadedAt: Calendar.current.date(byAdding: .hour, value: -6, to: today) ?? today,
                linkedTaskId: task3_5.id
            )
        ]

        let project5Attachments: [ProjectAttachment] = [
            ProjectAttachment(
                type: .document,
                fileName: "Factura_ABC-2024-0158.pdf",
                fileSize: 145_000,
                uploadedBy: alejandro,
                uploadedAt: Calendar.current.date(byAdding: .day, value: -1, to: today) ?? today,
                linkedTaskId: task5_1.id
            ),
            ProjectAttachment(
                type: .document,
                fileName: "Resumen_Proyecto.docx",
                fileSize: 234_000,
                uploadedBy: sara,
                uploadedAt: Calendar.current.date(byAdding: .hour, value: -8, to: today) ?? today
            )
        ]

        // Task-specific messages for notifications demo (unread by alejandro)
        let taskMessages1: [Message] = [
            Message(
                content: "He medido todos los marcos de ventanas - la mayoria son tamanos estandar",
                sender: diego,
                timestamp: Calendar.current.date(byAdding: .minute, value: -20, to: today) ?? today,
                isFromCurrentUser: false,
                referencedTask: TaskReference(taskId: task1_1.id, taskTitle: task1_1.title),
                readBy: [diego.id]
            ),
            Message(
                content: "Encontre una ventana que necesita tamano personalizado en el dormitorio principal",
                sender: diego,
                timestamp: Calendar.current.date(byAdding: .minute, value: -15, to: today) ?? today,
                isFromCurrentUser: false,
                referencedTask: TaskReference(taskId: task1_1.id, taskTitle: task1_1.title),
                readBy: [diego.id]
            ),
            Message(
                content: "Las muestras de pintura llegaron - las deje en el garaje",
                sender: maria,
                timestamp: Calendar.current.date(byAdding: .minute, value: -10, to: today) ?? today,
                isFromCurrentUser: false,
                referencedTask: TaskReference(taskId: task1_4_paint.id, taskTitle: task1_4_paint.title),
                readBy: [maria.id]
            ),
            // Subtask-specific messages (unread by alejandro)
            Message(
                content: "Obtuve cotizaciones de Home Depot, Lowes y proveedor local. Home Depot tiene los mejores precios.",
                sender: maria,
                timestamp: Calendar.current.date(byAdding: .minute, value: -45, to: today) ?? today,
                isFromCurrentUser: false,
                referencedTask: TaskReference(taskId: task1_1.id, taskTitle: task1_1.title),
                referencedSubtask: SubtaskReference(subtaskId: subtask1_1_1.id, subtaskTitle: subtask1_1_1.title),
                readBy: [maria.id]
            ),
            Message(
                content: "Subi la hoja de comparacion - aunque Lowes tiene entrega mas rapida",
                sender: diego,
                timestamp: Calendar.current.date(byAdding: .minute, value: -40, to: today) ?? today,
                isFromCurrentUser: false,
                referencedTask: TaskReference(taskId: task1_1.id, taskTitle: task1_1.title),
                referencedSubtask: SubtaskReference(subtaskId: subtask1_1_2.id, subtaskTitle: subtask1_1_2.title),
                readBy: [diego.id]
            ),
            Message(
                content: "Listo para hacer el pedido - solo necesito aprobacion final del presupuesto",
                sender: maria,
                timestamp: Calendar.current.date(byAdding: .minute, value: -5, to: today) ?? today,
                isFromCurrentUser: false,
                referencedTask: TaskReference(taskId: task1_1.id, taskTitle: task1_1.title),
                referencedSubtask: SubtaskReference(subtaskId: subtask1_1_3.id, subtaskTitle: subtask1_1_3.title),
                readBy: [maria.id]
            )
        ]

        // Combine base messages with task-specific messages
        let allProject1Messages = project1Messages + taskMessages1

        return [
            Project(
                name: "Renovacion Centro",
                members: [alejandro, maria, diego],
                tasks: [task1_1, task1_2, task1_3, task1_4_paint, task1_5, task1_6, task1_7],
                messages: allProject1Messages,
                attachments: project1Attachments,
                unreadTaskIds: [
                    alejandro.id: [task1_1.id, task1_3.id],
                    maria.id: [task1_2.id],
                    diego.id: [task1_1.id, task1_2.id]
                ],
                lastActivity: Date(),
                lastActivityPreview: "Maria: Puedes revisar las medidas?"
            ),
            Project(
                name: "Residencia Sanchez",
                members: [alejandro, sara],
                tasks: [task2_1, task2_2, task2_3, task2_4],
                messages: project2Messages,
                attachments: project2Attachments,
                unreadTaskIds: [:],
                lastActivity: Calendar.current.date(byAdding: .hour, value: -2, to: Date()),
                lastActivityPreview: "Completado: Reparar puerta del garaje"
            ),
            Project(
                name: "Edificio de Oficinas - Fase 2",
                members: [alejandro, maria, miguel],
                tasks: [task3_1, task3_2, task3_3, task3_4, task3_5, task3_6, task3_7, task3_8],
                messages: project3Messages,
                attachments: project3Attachments,
                unreadTaskIds: [
                    alejandro.id: [task3_1.id, task3_2.id, task3_4.id, task3_5.id],
                    maria.id: [task3_1.id, task3_3.id, task3_4.id],
                    miguel.id: [task3_2.id, task3_3.id, task3_5.id]
                ],
                lastActivity: Calendar.current.date(byAdding: .minute, value: -30, to: Date()),
                lastActivityPreview: "Nueva tarea: Instalar plomeria provisional"
            ),
            Project(
                name: "Mantenimiento de Equipos",
                members: [alejandro, diego, miguel],
                tasks: [task4_1, task4_2, task4_3, task4_4],
                messages: project4Messages,
                attachments: [],
                unreadTaskIds: [:],
                lastActivity: Calendar.current.date(byAdding: .day, value: -1, to: Date()),
                lastActivityPreview: "Completado: Reemplazar brocas de taladro"
            ),
            Project(
                name: "Cliente: ABC Corp",
                members: [alejandro, sara],
                tasks: [task5_1, task5_2, task5_3, task5_4],
                messages: project5Messages,
                attachments: project5Attachments,
                unreadTaskIds: [
                    alejandro.id: [task5_2.id]
                ],
                lastActivity: Calendar.current.date(byAdding: .hour, value: -5, to: Date()),
                lastActivityPreview: "Sara: La factura esta lista para revision"
            )
        ]
    }
}
