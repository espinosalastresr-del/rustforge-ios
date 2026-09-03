# RustForge iOS

IDE híbrido **Rust + SwiftUI** que corre en el dispositivo (LiveContainer + StikDebug / JIT).
El linking y empaquetado del `.ipa` se hacen en **GitHub Actions**.

## Estado

| Componente | Estado |
|------------|--------|
| IDE SwiftUI (proyectos, editor, terminal, UI builder, ajustes) | Compila en CI |
| Workflow **Build RustForge IDE** | Success → artefacto `.app` |
| Workflow **Build iOS App** | Success → artefacto `.ipa` unsigned |
| Flujo app → CI → descarga IPA → compartir | Integrado |
| WAMR / rustc.wasm on-device | Stub listo para sustituir por runtime real |

## Uso rápido

1. Descarga el artefacto `rustforge-ios-build` del workflow **Build RustForge IDE**.
2. Instálalo con **LiveContainer** (no requiere firma).
3. En **Ajustes → GitHub Actions**:
   - Token con scopes `repo` + `workflow`
   - Repositorio: `espinosalastresr-del/rustforge-ios`
   - Workflow: `build.yml`
4. Crea un proyecto (plantilla hybrid Rust staticlib + SwiftUI).
5. Edita código / usa el **UI Builder** y exporta a `ios/ContentView.swift`.
6. Pulsa **Play** en el editor → se dispara CI → al terminar puedes **compartir el IPA** a LiveContainer.

## Arquitectura

```
┌─────────────────────┐     workflow_dispatch      ┌──────────────────────┐
│  RustForge IDE      │ ─────────────────────────► │  GitHub Actions      │
│  (LiveContainer)    │                            │  build.yml           │
│  - Editor / VFS     │ ◄──── artifact IPA ────────│  cargo + xcodebuild  │
│  - UI Builder       │                            │  → .ipa unsigned     │
│  - BuildService     │                            └──────────────────────┘
└─────────────────────┘
```

## Workflows

- `.github/workflows/build-ide.yml` — compila el IDE (macos-15, Xcode 16).
- `.github/workflows/build.yml` — linking de proyectos de usuario → IPA.

## Desarrollo local del IDE

```bash
brew install xcodegen
xcodegen generate
open RustForge.xcodeproj
```

O deja que Actions genere el `.app` en cada push a `main`.

## Licencia

Proyecto experimental / educativo.
