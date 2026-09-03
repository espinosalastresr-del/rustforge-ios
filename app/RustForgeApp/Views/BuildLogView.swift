import SwiftUI

struct BuildLogView: View {
    @ObservedObject var buildService: BuildService
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                statusBar
                Divider()
                ScrollViewReader { proxy in
                    ScrollView {
                        Text(buildService.log.isEmpty ? "Esperando…" : buildService.log)
                            .font(.system(size: 12, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding()
                            .id("log-bottom")
                    }
                    .onChange(of: buildService.log) {
                        withAnimation {
                            proxy.scrollTo("log-bottom", anchor: .bottom)
                        }
                    }
                }
                if buildService.isRunning {
                    Divider()
                    Button(role: .destructive) {
                        buildService.cancel()
                    } label: {
                        Label("Cancelar build", systemImage: "stop.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .padding()
                } else if buildService.status == .success, let ipa = buildService.lastIPAURL {
                    Divider()
                    VStack(spacing: 10) {
                        Text("IPA listo").font(.headline)
                        Text(ipa.lastPathComponent).font(.caption).foregroundStyle(.secondary)
                        Button {
                            shareIPA(ipa)
                        } label: {
                            Label("Instalar / Compartir", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding()
                }
            }
            .navigationTitle("Build")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
    }
    
    private var statusBar: some View {
        HStack(spacing: 12) {
            statusIcon
            Text(statusTitle).font(.subheadline.weight(.semibold))
            Spacer()
            if buildService.isRunning { ProgressView() }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
    }
    
    @ViewBuilder
    private var statusIcon: some View {
        switch buildService.status {
        case .idle:
            Image(systemName: "circle").foregroundStyle(.secondary)
        case .compiling, .uploading, .remoteBuild, .downloading:
            Image(systemName: "gearshape.2.fill").foregroundStyle(.orange)
        case .success:
            Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failed:
            Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }
    
    private var statusTitle: String {
        switch buildService.status {
        case .idle: return "Listo"
        case .compiling: return "Compilando Rust…"
        case .uploading: return "Subiendo artefactos…"
        case .remoteBuild: return "Build remoto en curso…"
        case .downloading: return "Descargando IPA…"
        case .success: return "Build exitoso"
        case .failed: return "Build fallido"
        }
    }
    
    private func shareIPA(_ url: URL) {
        print("Compartir IPA: \(url.path)")
    }
}
