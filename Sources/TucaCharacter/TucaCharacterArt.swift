import AppKit
import Foundation

/// Camadas do rig, todas derivadas do master aprovado (Resources/TucaCharacterArt).
public struct TucaCharacterArt {
    public let full: CGImage
    public let body: CGImage
    public let socket: CGImage
    public let iris: CGImage
    public let rim: CGImage
    public let attention: CGImage?
    public let file: CGImage?
    public let spark: CGImage?
    public let zzz: CGImage?
    /// Tamanho da arte em pixels.
    public let size: CGSize
    /// Caixa do olho em coordenadas da imagem (origem no topo).
    public let eyeBox: CGRect
    public let blinkPivotY: Double

    public static let shared: TucaCharacterArt? = load()

    private struct RigJSON: Decodable {
        let size: [Double]
        let eyeBox: [Double]
        let blinkPivotY: Double
    }

    static func directory() -> URL? {
        if let u = Bundle.main.resourceURL?.appendingPathComponent("TucaCharacterArt"),
           FileManager.default.fileExists(atPath: u.appendingPathComponent("rig.json").path) {
            return u
        }
        var dir = URL(fileURLWithPath: CommandLine.arguments[0]).resolvingSymlinksInPath().deletingLastPathComponent()
        for _ in 0..<6 {
            let u = dir.appendingPathComponent("Resources/TucaCharacterArt")
            if FileManager.default.fileExists(atPath: u.appendingPathComponent("rig.json").path) { return u }
            dir = dir.deletingLastPathComponent()
        }
        return nil
    }

    static func load() -> TucaCharacterArt? {
        guard let dir = directory(),
              let data = try? Data(contentsOf: dir.appendingPathComponent("rig.json")),
              let rig = try? JSONDecoder().decode(RigJSON.self, from: data) else {
            NSLog("TucaCharacter: arte do rig não encontrada")
            return nil
        }
        func img(_ n: String) -> CGImage? {
            let u = dir.appendingPathComponent(n + ".png")
            guard let src = CGImageSourceCreateWithURL(u as CFURL, nil) else { return nil }
            return CGImageSourceCreateImageAtIndex(src, 0, nil)
        }
        guard let full = img("full"), let body = img("body"), let socket = img("eye_socket"),
              let iris = img("eye_iris"), let rim = img("eye_rim") else { return nil }
        return TucaCharacterArt(full: full, body: body, socket: socket, iris: iris, rim: rim,
                                attention: img("attention"), file: img("file"), spark: img("spark"), zzz: img("zzz"),
                                size: CGSize(width: rig.size[0], height: rig.size[1]),
                                eyeBox: CGRect(x: rig.eyeBox[0], y: rig.eyeBox[1], width: rig.eyeBox[2], height: rig.eyeBox[3]),
                                blinkPivotY: rig.blinkPivotY)
    }
}
