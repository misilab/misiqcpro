import Foundation

/// Generic async wrapper for spawning a child process and collecting stdout/stderr.
///
/// Critical: both pipes are drained on a background queue. FFmpeg writes its
/// progress and ebur128 results to stderr; a full pipe (~64 KB on macOS) would
/// block the child process indefinitely.
enum ProcessRunner {
    struct Result {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    enum RunError: LocalizedError {
        case launchFailed(String)
        case nonZeroExit(code: Int32, stderr: String)
        var errorDescription: String? {
            switch self {
            case .launchFailed(let m): return "Échec du lancement du processus : \(m)"
            case .nonZeroExit(let c, let s):
                return "Le processus s'est terminé avec le code \(c). \(s.prefix(500))"
            }
        }
    }

    static func run(
        executable: URL,
        arguments: [String],
        throwOnNonZeroExit: Bool = true
    ) async throws -> Result {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Result, Error>) in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments

            let outPipe = Pipe()
            let errPipe = Pipe()
            process.standardOutput = outPipe
            process.standardError = errPipe

            let outBuffer = Buffer()
            let errBuffer = Buffer()
            outPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { outBuffer.append(data) }
            }
            errPipe.fileHandleForReading.readabilityHandler = { handle in
                let data = handle.availableData
                if !data.isEmpty { errBuffer.append(data) }
            }

            process.terminationHandler = { proc in
                // Drain any remaining data left in the pipes after termination.
                let outRest = outPipe.fileHandleForReading.readDataToEndOfFile()
                if !outRest.isEmpty { outBuffer.append(outRest) }
                let errRest = errPipe.fileHandleForReading.readDataToEndOfFile()
                if !errRest.isEmpty { errBuffer.append(errRest) }
                outPipe.fileHandleForReading.readabilityHandler = nil
                errPipe.fileHandleForReading.readabilityHandler = nil

                let stdout = outBuffer.string()
                let stderr = errBuffer.string()
                if throwOnNonZeroExit && proc.terminationStatus != 0 {
                    continuation.resume(throwing: RunError.nonZeroExit(code: proc.terminationStatus, stderr: stderr))
                } else {
                    continuation.resume(returning: Result(
                        exitCode: proc.terminationStatus,
                        stdout: stdout,
                        stderr: stderr
                    ))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: RunError.launchFailed(error.localizedDescription))
            }
        }
    }

    /// Thread-safe buffer for accumulating pipe output across background reads.
    private final class Buffer: @unchecked Sendable {
        nonisolated(unsafe) private var data = Data()
        private let lock = NSLock()
        nonisolated func append(_ chunk: Data) {
            lock.lock(); defer { lock.unlock() }
            data.append(chunk)
        }
        nonisolated func string() -> String {
            lock.lock(); defer { lock.unlock() }
            return String(data: data, encoding: .utf8) ?? ""
        }
    }
}
