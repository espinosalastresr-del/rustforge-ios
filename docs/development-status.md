# Estado de desarrollo — RustForge iOS

## Fases

| Fase | Nombre | Estado |
|------|--------|--------|
| 0 | Auditoría | Pendiente |
| 1 | Runtime WASM | Parcial (bridge + stub) |
| 2 | rustc.wasm | Simulado |
| 3 | Cargo | Simulado |
| 4 | Dependencias | Base (CargoCache) |
| 6 | rust-analyzer | Stub |
| 8 | UI Builder | Básico |
| 10 | GitHub Actions | Cliente listo |

## Próximos hitos

1. Compilar WAMR en CI y linkar.
2. Toolchain WASM real.
3. Sustituir simulación por ejecución real.
4. Subida/descarga real de artefactos IPA.
