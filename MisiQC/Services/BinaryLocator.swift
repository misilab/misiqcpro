import Foundation

/// Resolves paths to the bundled `ffmpeg` / `ffprobe` binaries.
///
/// Search order:
///   1. `Contents/Resources/bin/{name}` inside the app bundle (production).
///   2. Common Homebrew locations (`/opt/homebrew/bin`, `/usr/local/bin`) — convenience for
///      development before the binaries are bundled.
enum BinaryLocator {
    enum BinaryError: LocalizedError {
        case notFound(String)
        var errorDescription: String? {
            switch self {
            case .notFound(let name):
                return "Binaire \(name) introuvable. Place ffmpeg et ffprobe LGPL dans MisiQC Pro.app/Contents/Resources/bin/ ou installe-les via Homebrew."
            }
        }
    }

    static func locate(_ name: String) throws -> URL {
        if let bundled = Bundle.main.url(forResource: name, withExtension: nil, subdirectory: "bin") {
            return bundled
        }
        if let bundled = Bundle.main.url(forResource: name, withExtension: nil) {
            return bundled
        }
        let fallbacks = [
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "/usr/bin/\(name)"
        ]
        for candidate in fallbacks where FileManager.default.isExecutableFile(atPath: candidate) {
            return URL(fileURLWithPath: candidate)
        }
        throw BinaryError.notFound(name)
    }

    static func ffmpegURL() throws -> URL { try locate("ffmpeg") }
    static func ffprobeURL() throws -> URL { try locate("ffprobe") }
}
