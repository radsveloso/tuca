// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Tuca",
    platforms: [.macOS(.v14)],
    targets: [
        // Modelo puro do mascote (estados, prioridade, mapeamento de eventos). Sem UI, testável.
        .target(name: "TucaCore", path: "Sources/TucaCore"),
        .executableTarget(name: "Tuca", dependencies: ["TucaCore", "TucaCharacter"], path: "Sources/Tuca"),
        // Character Engine 3.0: rig do Tuca em Core Animation (ainda fora do notch).
        .target(name: "TucaCharacter", dependencies: ["TucaCore"], path: "Sources/TucaCharacter"),
        // Playground para aprovar o personagem: `swift run TucaPlayground` ou ./build-playground.sh
        .executableTarget(name: "TucaPlayground", dependencies: ["TucaCharacter", "TucaCore"], path: "Sources/TucaPlayground"),
        // Verificações do resolvedor de estados: `swift run TucaCoreChecks`.
        .executableTarget(name: "TucaCoreChecks", dependencies: ["TucaCore"], path: "Sources/TucaCoreChecks"),
    ]
)
