import SwiftUI
import UIKit

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
                            .textSelection(.enabled)
                            .id("log-bottom")
                    }
                    .onChange(of: buildService.log) {
                        withAnimation { proxy.scrollTo("log-bottom", anchor: .bottom) }
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
                    VStack(spacing: 12) {
                        Label("IPA listo para LiveContainer", systemImage: "checkmark.seal.fill")
                            .font(.headline)
                            .foregroundStyle(.green)
                        Text(ipa.lastPathComponent)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let runURL = buildService.lastRunURL {
                            Link("Ver run en GitHub", destination: URL(string: runURL)!)
                                .font(.caption)
                        }
                        Button {
                            share(url: ipa)
                        } label: {
                            Label("Compartir / Guardar IPA", systemImage: "square.and.arrow.up")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.orange)
                    }
                    .padding()
                } else if buildService.status == .failed {
                    Divider()
                    Text("El build falló. Revisa el log y la configuración de GitHub en Ajustes.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        case .uploading: return "Disparando CI…"
        case .remoteBuild: return "Build remoto en curso…"
        case .downloading: return "Descargando IPA…"
        case .success: return "Build exitoso"
        case .failed: return "Build fallido"
        }
    }

    private func share(url: URL) {
        let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene
        let root = scene?.windows.first?.rootViewController
        let ac = UIActivityViewController(activityItems: [url], applicationActivities: nil)
        if let pop = ac.popoverPresentationController {
            pop.sourceView = root?.view
            pop.sourceRect = CGRect(x: UIScreen.main.bounds.midX, y: UIScreen.main.bounds.midY, width: 0, height: 0)
            pop.permittedArrowDirections = []
        }
        root?.present(ac, animated: true)
    }
}
