// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Tuca",
    platforms: [.macOS(.v14)],
    targets: [
        // Modelo puro do mascote (estados, prioridade, mapeamento de eventos). Sem UI, testável.
        .target(name: "TucaCore", path: "Sources/TucaCore"),
        .executableTarget(name: "Tuca", dependencies: ["TucaCore"], path: "Sources/Tuca"),
        // Verificações do resolvedor de estados: `swift run TucaCoreChecks`.
        .executableTarget(name: "TucaCoreChecks", dependencies: ["TucaCore"], path: "Sources/TucaCoreChecks"),
    ]
)
