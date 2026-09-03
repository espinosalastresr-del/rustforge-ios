import SwiftUI

struct UIBuilderView: View {
    @EnvironmentObject var appState: AppState
    @State private var components: [UIComponent] = []
    @State private var selectedComponentId: UUID?
    @State private var generatedCode: String = ""
    @State private var showCode = false
    
    var body: some View {
        NavigationStack {
            HStack(spacing: 0) {
                componentPalette
                    .frame(width: 200)
                Divider()
                canvas
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                Divider()
                inspector
                    .frame(width: 260)
            }
            .navigationTitle("UI Builder")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        generateSwiftUICode()
                        showCode = true
                    } label: {
                        Label("Generar código", systemImage: "doc.text")
                    }
                }
            }
            .sheet(isPresented: $showCode) {
                NavigationStack {
                    ScrollView {
                        Text(generatedCode)
                            .font(.system(size: 13, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .navigationTitle("SwiftUI generado")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cerrar") { showCode = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Copiar") { UIPasteboard.general.string = generatedCode }
                        }
                    }
                }
            }
        }
    }
    
    private var componentPalette: some View {
        List {
            Section("Contenedores") {
                Button("VStack") { addComponent(.vStack) }
                Button("HStack") { addComponent(.hStack) }
            }
            Section("Controles") {
                Button("Texto") { addComponent(.text) }
                Button("Botón") { addComponent(.button) }
                Button("Imagen") { addComponent(.image) }
            }
        }
        .listStyle(.sidebar)
    }
    
    private var canvas: some View {
        ZStack {
            Color(.systemGroupedBackground)
            if components.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "rectangle.3.group").font(.system(size: 48)).foregroundStyle(.secondary)
                    Text("Añade componentes desde la paleta").foregroundStyle(.secondary)
                }
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(components) { component in
                            Text(component.type.rawValue)
                                .padding(8)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                                .onTapGesture { selectedComponentId = component.id }
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(selectedComponentId == component.id ? Color.orange : Color.clear, lineWidth: 2)
                                )
                        }
                    }.padding()
                }
            }
        }
    }
    
    private var inspector: some View {
        Form {
            if let id = selectedComponentId,
               let index = components.firstIndex(where: { $0.id == id }) {
                Section("Propiedades") {
                    Text(components[index].type.rawValue).font(.headline)
                    if components[index].type == .text {
                        TextField("Texto", text: binding(for: index, key: "text"))
                    }
                    if components[index].type == .button {
                        TextField("Título", text: binding(for: index, key: "title"))
                    }
                }
                Section {
                    Button("Eliminar", role: .destructive) {
                        components.remove(at: index)
                        selectedComponentId = nil
                    }
                }
            } else {
                ContentUnavailableView("Sin selección", systemImage: "cursorarrow.rays",
                    description: Text("Selecciona un componente"))
            }
        }
    }
    
    private func binding(for index: Int, key: String) -> Binding<String> {
        Binding(
            get: { components[index].properties[key] ?? "" },
            set: { components[index].properties[key] = $0 }
        )
    }
    
    private func addComponent(_ type: UIComponentType) {
        var props: [String: String] = [:]
        switch type {
        case .text: props["text"] = "Nuevo texto"
        case .button: props["title"] = "Botón"
        case .image: props["systemName"] = "star.fill"
        default: break
        }
        let c = UIComponent(type: type, properties: props)
        components.append(c)
        selectedComponentId = c.id
    }
    
    private func generateSwiftUICode() {
        var code = "import SwiftUI\n\nstruct ContentView: View {\n    var body: some View {\n        VStack(spacing: 16) {\n"
        for c in components {
            switch c.type {
            case .text: code += "            Text(\"\(c.properties["text"] ?? "Texto")\")\n"
            case .button: code += "            Button(\"\(c.properties["title"] ?? "Botón")\") { }\n"
            case .image: code += "            Image(systemName: \"\(c.properties["systemName"] ?? "photo")\")\n"
            case .vStack: code += "            VStack { }\n"
            case .hStack: code += "            HStack { }\n"
            default: break
            }
        }
        code += "        }\n        .padding()\n    }\n}\n"
        generatedCode = code
    }
}

struct UIComponent: Identifiable {
    let id = UUID()
    var type: UIComponentType
    var properties: [String: String]
}

enum UIComponentType: String {
    case vStack = "VStack"
    case hStack = "HStack"
    case text = "Text"
    case button = "Button"
    case image = "Image"
}
