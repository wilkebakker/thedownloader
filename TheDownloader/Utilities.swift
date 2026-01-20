// Utilities — Shared helpers for THE DOWNLOADER
// Process execution, path discovery, and common functions

import Foundation

// MARK: - Executable Path Discovery

/// Get the path to bundled binaries inside the app bundle
func bundledBinPath() -> String? {
    guard let bundlePath = Bundle.main.resourcePath else { return nil }
    let binPath = (bundlePath as NSString).appendingPathComponent("bin")
    if FileManager.default.fileExists(atPath: binPath) {
        return binPath
    }
    return nil
}

/// Known install paths for common tools
let executablePaths: [String: [String]] = [
    "yt-dlp": [
        "/opt/homebrew/bin/yt-dlp",
        "/usr/local/bin/yt-dlp",
        "/usr/bin/yt-dlp"
    ],
    "ffmpeg": [
        "/opt/homebrew/bin/ffmpeg",
        "/usr/local/bin/ffmpeg",
        "/usr/bin/ffmpeg"
    ],
    "brew": [
        "/opt/homebrew/bin/brew",
        "/usr/local/bin/brew"
    ]
]

/// Get Homebrew prefix dynamically
func homebrewPrefix() -> String? {
    for brewPath in executablePaths["brew"] ?? [] {
        if FileManager.default.isExecutableFile(atPath: brewPath) {
            if let output = try? runProcessSync(cmd: brewPath, args: ["--prefix"]) {
                let prefix = output.trimmingCharacters(in: .whitespacesAndNewlines)
                if !prefix.isEmpty { return prefix }
            }
        }
    }
    return nil
}

/// Find executable path for a given tool name
func which(_ name: String) -> String? {
    // 1. Check bundled binaries first (inside app bundle)
    if let binPath = bundledBinPath() {
        let bundledPath = (binPath as NSString).appendingPathComponent(name)
        if FileManager.default.isExecutableFile(atPath: bundledPath) {
            return bundledPath
        }
    }

    // 2. Check known system paths
    for path in executablePaths[name] ?? [] {
        if FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
    }

    // 3. Check Homebrew prefix
    if let prefix = homebrewPrefix() {
        let brewPath = "\(prefix)/bin/\(name)"
        if FileManager.default.isExecutableFile(atPath: brewPath) {
            return brewPath
        }
    }

    // 4. Fallback to system which
    if let output = try? runProcessSync(cmd: "/usr/bin/which", args: [name]) {
        let path = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if !path.isEmpty && FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
    }

    return nil
}

// MARK: - Process Execution

/// Run a process synchronously and return output
@discardableResult
func runProcessSync(cmd: String, args: [String]) throws -> String {
    let process = Process()
    process.executableURL = URL(fileURLWithPath: cmd)
    process.arguments = args

    let pipe = Pipe()
    process.standardOutput = pipe
    process.standardError = pipe

    try process.run()
    process.waitUntilExit()

    let data = pipe.fileHandleForReading.readDataToEndOfFile()
    return String(data: data, encoding: .utf8) ?? ""
}

/// Thread-safe output collector for process execution
final class OutputCollector: @unchecked Sendable {
    private var data = Data()
    private let lock = NSLock()

    func append(_ chunk: Data) {
        lock.lock()
        data.append(chunk)
        lock.unlock()
    }

    func getData() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}

/// Run a process asynchronously with streaming output
func runProcess(args: [String]) async -> (status: Int32, output: String) {
    guard let executable = args.first else {
        return (1, "No command provided")
    }

    let processArgs = Array(args.dropFirst())

    return await withCheckedContinuation { continuation in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = processArgs

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        let collector = OutputCollector()

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let chunk = handle.availableData
            if !chunk.isEmpty {
                collector.append(chunk)
            }
        }

        process.terminationHandler = { _ in
            pipe.fileHandleForReading.readabilityHandler = nil
            // Read any remaining data
            let remaining = pipe.fileHandleForReading.readDataToEndOfFile()
            if !remaining.isEmpty {
                collector.append(remaining)
            }
            let output = String(data: collector.getData(), encoding: .utf8) ?? ""
            continuation.resume(returning: (process.terminationStatus, output))
        }

        do {
            try process.run()
        } catch {
            continuation.resume(returning: (1, "Failed to start: \(error.localizedDescription)"))
        }
    }
}

/// Controller for a running process that can be cancelled
final class ProcessController: @unchecked Sendable {
    private var process: Process?
    private let lock = NSLock()

    func setProcess(_ process: Process) {
        lock.lock()
        self.process = process
        lock.unlock()
    }

    func terminate() {
        lock.lock()
        if let proc = process, proc.isRunning {
            proc.terminate()
        }
        lock.unlock()
    }
}

/// Run a process with real-time output callback and optional cancellation
func runProcessWithCallback(
    args: [String],
    controller: ProcessController? = nil,
    onOutput: @escaping (String) -> Void
) async -> Int32 {
    guard let executable = args.first else {
        onOutput("No command provided")
        return 1
    }

    let processArgs = Array(args.dropFirst())

    return await withCheckedContinuation { continuation in
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = processArgs

        // Store reference for cancellation
        controller?.setProcess(process)

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let str = String(data: data, encoding: .utf8) {
                DispatchQueue.main.async {
                    onOutput(str)
                }
            }
        }

        process.terminationHandler = { proc in
            pipe.fileHandleForReading.readabilityHandler = nil
            continuation.resume(returning: proc.terminationStatus)
        }

        do {
            try process.run()
        } catch {
            onOutput("Failed to start: \(error.localizedDescription)")
            continuation.resume(returning: 1)
        }
    }
}

// MARK: - Dependency Checking

struct DependencyStatus {
    let name: String
    let path: String?
    let isInstalled: Bool

    var statusIcon: String {
        isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill"
    }
}

func checkAllDependencies() -> [DependencyStatus] {
    let tools = ["yt-dlp", "ffmpeg", "brew"]
    return tools.map { name in
        let path = which(name)
        return DependencyStatus(
            name: name,
            path: path,
            isInstalled: path != nil
        )
    }
}

// MARK: - File Utilities

/// Get file type category from extension
enum FileCategory {
    case video
    case audio
    case image
    case unknown
}

func categorizeFile(_ url: URL) -> FileCategory {
    let ext = url.pathExtension.lowercased()

    let videoExtensions = ["mp4", "mov", "avi", "mkv", "webm", "m4v", "flv", "wmv"]
    let audioExtensions = ["mp3", "wav", "aac", "flac", "m4a", "ogg", "wma", "aiff"]
    let imageExtensions = ["png", "jpg", "jpeg", "webp", "gif", "tiff", "bmp", "heic"]

    if videoExtensions.contains(ext) { return .video }
    if audioExtensions.contains(ext) { return .audio }
    if imageExtensions.contains(ext) { return .image }
    return .unknown
}

/// Format file size for display
func formatFileSize(_ bytes: Int64) -> String {
    let formatter = ByteCountFormatter()
    formatter.allowedUnits = [.useKB, .useMB, .useGB]
    formatter.countStyle = .file
    return formatter.string(fromByteCount: bytes)
}

/// Get file size
func getFileSize(_ url: URL) -> Int64? {
    do {
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        return attrs[.size] as? Int64
    } catch {
        return nil
    }
}
