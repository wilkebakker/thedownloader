// DownloaderView — Clean, centered UI for content downloading

import SwiftUI
import AppKit

struct DownloaderView: View {
    @StateObject private var projectManager = ProjectManager.shared
    @State private var linksText: String = ""
    @State private var outputFormat: OutputFormat = .videoMP4
    @State private var destPath: String = defaultDestination()
    @State private var isDownloading: Bool = false
    @State private var progress: Double = 0
    @State private var currentItem: Int = 0
    @State private var totalItems: Int = 0
    @State private var statusMessage: String = ""
    @State private var downloadFullPlaylist: Bool = false
    @State private var downloadTask: Task<Void, Never>?
    @State private var processController: ProcessController?
    @State private var lastDownloadSucceeded = false

    var hasPlaylistURL: Bool {
        let text = linksText.lowercased()
        return text.contains("list=") || text.contains("/playlist")
    }

    var body: some View {
        VStack(spacing: 16) {
            // URL Input
            ZStack(alignment: .topLeading) {
                if linksText.isEmpty {
                    Text("Paste URLs from YouTube, TikTok and Instagram here...")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary.opacity(0.7))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                }
                TextEditor(text: $linksText)
                    .font(.system(size: 12))
                    .scrollContentBackground(.hidden)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
            }
            .frame(height: 72)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.08), lineWidth: 1)
            )

            // Playlist option - only shown when playlist URL detected
            if hasPlaylistURL {
                HStack(spacing: 6) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 10))
                        .foregroundColor(.orange)

                    Toggle(isOn: $downloadFullPlaylist) {
                        Text("Download full playlist")
                            .font(.system(size: 10))
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)

                    Spacer()
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.08))
                .cornerRadius(6)
            }

            // Format Selection - Centered
            VStack(spacing: 14) {
                // Video formats
                VStack(spacing: 8) {
                    Text("VIDEO")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1)

                    HStack(spacing: 6) {
                        ForEach(OutputFormat.videoFormats, id: \.self) { format in
                            FormatChip(format: format, isSelected: outputFormat == format) {
                                outputFormat = format
                            }
                        }
                    }
                }

                // Audio formats
                VStack(spacing: 8) {
                    Text("AUDIO")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1)

                    HStack(spacing: 6) {
                        ForEach(OutputFormat.audioFormats, id: \.self) { format in
                            FormatChip(format: format, isSelected: outputFormat == format) {
                                outputFormat = format
                            }
                        }
                    }
                }
            }

            // Save location
            HStack(spacing: 10) {
                Image(systemName: "folder.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.accentColor)

                Text(shortenPath(destPath))
                    .font(.system(size: 11))
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .truncationMode(.middle)

                Spacer()

                Button("Change") { chooseFolder() }
                    .font(.system(size: 10))
                    .buttonStyle(.borderless)
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)

            // Progress
            if isDownloading {
                VStack(spacing: 6) {
                    ProgressView(value: progress)
                        .tint(.accentColor)
                    HStack {
                        Text(statusMessage)
                            .lineLimit(1)
                        Spacer()
                        Text("\(currentItem)/\(totalItems)")
                            .fontWeight(.medium)
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
            }

            // Show in Finder (after successful download)
            if !isDownloading && lastDownloadSucceeded {
                Button {
                    showDownloadFolderInFinder()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder.badge.plus")
                            .font(.system(size: 12))
                        Text("Show in Finder")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 0)

            // Download / Cancel Buttons
            HStack(spacing: 8) {
                if isDownloading {
                    Button {
                        cancelDownload()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 13, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(Color(NSColor.controlBackgroundColor))
                            .foregroundColor(.primary)
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.primary.opacity(0.1), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    startDownload()
                } label: {
                    HStack(spacing: 6) {
                        if isDownloading {
                            ProgressView()
                                .scaleEffect(0.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.system(size: 14))
                        }
                        Text(isDownloading ? "Downloading..." : "Download")
                            .font(.system(size: 13, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(canDownload ? Color.accentColor : Color.secondary.opacity(0.15))
                    .foregroundColor(canDownload ? .white : .secondary)
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(!canDownload)
                .keyboardShortcut(.return, modifiers: .command)
            }
        }
        .padding(16)
        .onAppear {
            pasteFromClipboard()
        }
        .onReceive(projectManager.$currentProject) { newProject in
            if let project = newProject {
                destPath = project.path
            } else {
                destPath = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Downloads").path
            }
        }
    }

    // MARK: - Computed Properties

    var canDownload: Bool {
        !isDownloading && !linksText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Actions

    func pasteFromClipboard() {
        guard let str = NSPasteboard.general.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !str.isEmpty else { return }

        let urls = extractURLs(from: str)
        let newText = urls.isEmpty ? "" : urls.joined(separator: "\n")

        if !newText.isEmpty {
            if linksText.isEmpty {
                linksText = newText
            } else {
                linksText += (linksText.hasSuffix("\n") ? "" : "\n") + newText
            }
        }
    }

    func chooseFolder() {
        NotificationCenter.default.post(name: .closePopover, object: nil)

        let currentDest = destPath
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Choose"
            panel.directoryURL = URL(fileURLWithPath: currentDest)
            panel.level = .modalPanel

            NSApp.activate(ignoringOtherApps: true)

            if panel.runModal() == .OK, let url = panel.url {
                DispatchQueue.main.async {
                    self.destPath = url.path
                }
            }
        }
    }

    func shortenPath(_ path: String) -> String {
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        if path.hasPrefix(home) {
            return "~" + path.dropFirst(home.count)
        }
        return path
    }

    func cancelDownload() {
        // Terminate the actual process first
        processController?.terminate()
        processController = nil

        // Then cancel the task
        downloadTask?.cancel()
        downloadTask = nil

        isDownloading = false
        statusMessage = "Cancelled"
        progress = 0

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            if !isDownloading {
                statusMessage = ""
            }
        }
    }

    func startDownload() {
        let rawLines = linksText
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        let links = rawLines.compactMap { normalizeURL($0) }
        guard !links.isEmpty else { return }

        do {
            try FileManager.default.createDirectory(atPath: destPath, withIntermediateDirectories: true)
        } catch {
            return
        }

        lastDownloadSucceeded = false
        isDownloading = true
        totalItems = links.count
        currentItem = 0
        progress = 0
        statusMessage = "Starting..."

        let targetPath = destPath
        let format = outputFormat
        let includePlaylist = downloadFullPlaylist
        let controller = ProcessController()
        processController = controller

        var anyFailed = false

        downloadTask = Task {
            for (index, link) in links.enumerated() {
                if Task.isCancelled { break }

                await MainActor.run {
                    currentItem = index + 1
                    statusMessage = "Connecting..."
                }

                let status = await runYtDlpWithProgress(
                    for: link,
                    to: targetPath,
                    format: format,
                    fullPlaylist: includePlaylist,
                    controller: controller
                ) { prog in
                    Task { @MainActor in
                        if prog.totalVideos > 1 {
                            totalItems = prog.totalVideos
                            currentItem = prog.currentVideo
                            let completedProgress = Double(prog.currentVideo - 1) / Double(prog.totalVideos)
                            let currentProgress = (prog.downloadPercent / 100.0) / Double(prog.totalVideos)
                            progress = completedProgress + currentProgress
                        } else {
                            progress = prog.downloadPercent / 100.0
                        }
                        if !prog.videoTitle.isEmpty {
                            let shortTitle = prog.videoTitle.count > 30
                                ? String(prog.videoTitle.prefix(27)) + "..."
                                : prog.videoTitle
                            statusMessage = shortTitle
                        } else if prog.downloadPercent > 0 {
                            statusMessage = "Downloading... \(Int(prog.downloadPercent))%"
                        }
                    }
                }

                if status != 0 && !Task.isCancelled {
                    anyFailed = true
                }
            }

            await MainActor.run {
                if !Task.isCancelled {
                    isDownloading = false
                    progress = 1.0
                    statusMessage = anyFailed ? "Some failed" : "Complete!"
                    downloadTask = nil
                    lastDownloadSucceeded = !anyFailed

                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        if !isDownloading {
                            if !anyFailed { linksText = "" }
                            statusMessage = ""
                            downloadFullPlaylist = false
                        }
                    }
                }
            }
        }
    }

    func showDownloadFolderInFinder() {
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: destPath)
    }
}

// MARK: - Format Chip

struct FormatChip: View {
    let format: OutputFormat
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(format.shortLabel)
                    .font(.system(size: 11, weight: .semibold))
                Text(format.detailLabel)
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? .white.opacity(0.7) : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 10)
            .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.clear : Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Output Formats

enum OutputFormat: CaseIterable {
    case videoMP4
    case videoH265
    case videoMOV
    case audioWAV24
    case audioMP3

    static var videoFormats: [OutputFormat] {
        [.videoMP4, .videoH265, .videoMOV]
    }

    static var audioFormats: [OutputFormat] {
        [.audioWAV24, .audioMP3]
    }

    var label: String {
        switch self {
        case .videoMP4: return "MP4 (H.264)"
        case .videoH265: return "MP4 (H.265)"
        case .videoMOV: return "MOV (H.264)"
        case .audioWAV24: return "WAV 24-bit 48kHz"
        case .audioMP3: return "MP3 320kbps"
        }
    }

    var shortLabel: String {
        switch self {
        case .videoMP4: return "H.264"
        case .videoH265: return "H.265"
        case .videoMOV: return "MOV"
        case .audioWAV24: return "WAV"
        case .audioMP3: return "MP3"
        }
    }

    var detailLabel: String {
        switch self {
        case .videoMP4: return "Universal"
        case .videoH265: return "Smaller"
        case .videoMOV: return "Apple"
        case .audioWAV24: return "24-bit"
        case .audioMP3: return "320k"
        }
    }

    var icon: String {
        switch self {
        case .videoMP4, .videoH265, .videoMOV: return "film"
        case .audioWAV24, .audioMP3: return "waveform"
        }
    }
}

// MARK: - Video Platform Detection

enum VideoPlatform {
    case youtube
    case tiktok
    case instagram
    case unknown
}

func detectPlatform(url: String) -> VideoPlatform {
    let lower = url.lowercased()
    if lower.contains("youtube.com") || lower.contains("youtu.be") {
        return .youtube
    }
    if lower.contains("tiktok.com") || lower.contains("vm.tiktok.com") || lower.contains("vt.tiktok.com") {
        return .tiktok
    }
    if lower.contains("instagram.com") || lower.contains("instagr.am") {
        return .instagram
    }
    return .unknown
}

// MARK: - Helpers

func defaultDestination() -> String {
    if let project = ProjectManager.shared.currentProject {
        return project.path
    }
    return FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Downloads").path
}

func extractURLs(from text: String) -> [String] {
    var processed = text
    if let regex = try? NSRegularExpression(pattern: #"(?<=[^\s])(?=https?://)"#, options: []) {
        processed = regex.stringByReplacingMatches(
            in: processed,
            range: NSRange(processed.startIndex..., in: processed),
            withTemplate: "\n"
        )
    }

    let pattern = #"(?i)\b(?:https?://)?(?:(?:www\.)?(?:youtube\.com|youtu\.be|tiktok\.com|vm\.tiktok\.com|vt\.tiktok\.com|instagram\.com|instagr\.am)\S+)"#
    guard let rx = try? NSRegularExpression(pattern: pattern) else { return [] }
    let ns = processed as NSString
    let matches = rx.matches(in: processed, range: NSRange(location: 0, length: ns.length))
    let urls = matches.map { ns.substring(with: $0.range) }
    var seen = Set<String>()
    return urls.compactMap { normalizeURL($0) }.filter { seen.insert($0).inserted }
}

func normalizeURL(_ raw: String) -> String? {
    var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !s.isEmpty else { return nil }

    if !s.hasPrefix("http://") && !s.hasPrefix("https://") {
        s = "https://" + s
    }

    guard var comps = URLComponents(string: s) else { return s }

    if let host = comps.host, host.contains("youtu.be") {
        let path = comps.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        if !path.isEmpty {
            comps.host = "www.youtube.com"
            comps.path = "/watch"
            var q = comps.queryItems ?? []
            q.removeAll { $0.name == "v" }
            q.insert(URLQueryItem(name: "v", value: path), at: 0)
            comps.queryItems = q
        }
    }

    return comps.url?.absoluteString ?? s
}

struct DownloadProgress {
    var currentVideo: Int = 0
    var totalVideos: Int = 1
    var downloadPercent: Double = 0
    var videoTitle: String = ""
}

func runYtDlpWithProgress(
    for url: String,
    to dest: String,
    format: OutputFormat,
    fullPlaylist: Bool = false,
    controller: ProcessController? = nil,
    onProgress: @escaping (DownloadProgress) -> Void
) async -> Int32 {
    guard let ytdlp = which("yt-dlp") else {
        return 1
    }

    let platform = detectPlatform(url: url)

    let outputTemplate: String
    switch platform {
    case .tiktok, .instagram:
        outputTemplate = "%(uploader)s_%(id)s.%(ext)s"
    case .youtube, .unknown:
        outputTemplate = "%(title)s.%(ext)s"
    }

    let outDir = (dest as NSString).standardizingPath
    let outTemplate = (outDir as NSString).appendingPathComponent(outputTemplate)
    var args: [String] = [
        ytdlp,
        "--restrict-filenames",
        "--newline",
        "--progress",
        "--output", outTemplate
    ]

    if !fullPlaylist {
        args.append("--no-playlist")
    }

    // Don't use Safari cookies for TikTok — yt-dlp works better without them.

    if let ff = which("ffmpeg") {
        args += ["--ffmpeg-location", ff]
    }

    let isInstagramVideo = platform == .instagram && (format == .videoMP4 || format == .videoH265 || format == .videoMOV)
    if isInstagramVideo {
        // Instagram: separate video + audio (two files), no merge.
        args += ["-f", "bv*,ba"]
    } else {
        switch format {
        case .videoMP4:
            args += ["-f", "bv*+ba/best", "--merge-output-format", "mp4",
                     "--postprocessor-args", "ffmpeg:-c:v libx264 -preset medium -crf 18 -c:a aac -b:a 192k -pix_fmt yuv420p -movflags +faststart"]
        case .videoH265:
            args += ["-f", "bv*+ba/best", "--merge-output-format", "mp4",
                     "--postprocessor-args", "ffmpeg:-c:v libx265 -preset medium -crf 22 -c:a aac -b:a 192k -tag:v hvc1 -movflags +faststart"]
        case .videoMOV:
            args += ["-f", "bv*+ba/best", "--merge-output-format", "mov",
                     "--postprocessor-args", "ffmpeg:-c:v libx264 -preset medium -crf 18 -c:a aac -b:a 192k -pix_fmt yuv420p"]
        case .audioWAV24:
            args += ["-f", "ba/best", "--extract-audio", "--audio-format", "wav",
                     "--postprocessor-args", "ffmpeg:-ar 48000 -ac 2 -c:a pcm_s24le"]
        case .audioMP3:
            args += ["-f", "ba/best", "--extract-audio", "--audio-format", "mp3",
                     "--audio-quality", "0"]
        }
    }

    args.append(url)

    var progress = DownloadProgress()

    return await runProcessWithCallback(args: args, controller: controller) { output in
        // Parse playlist progress - multiple formats:
        // "[youtube:tab] Downloading item 1 of 119"
        // "[download] Downloading item 1 of 119"
        // "Downloading video 1 of 119"
        // "[Playlist] Playlist Title: Downloading 1 of 119"
        if let match = output.range(of: #"(\d+)\s+of\s+(\d+)"#, options: .regularExpression) {
            let text = String(output[match])
            let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted).filter { !$0.isEmpty }
            if numbers.count >= 2, let current = Int(numbers[0]), let total = Int(numbers[1]), total > 1 {
                progress.currentVideo = current
                progress.totalVideos = total
                onProgress(progress)
            }
        }

        // Parse download percent: "[download]  45.2%"
        if let match = output.range(of: #"\[download\]\s+(\d+\.?\d*)%"#, options: .regularExpression) {
            let text = String(output[match])
            let numStr = text.components(separatedBy: CharacterSet.decimalDigits.inverted.subtracting(CharacterSet(charactersIn: "."))).joined()
            if let percent = Double(numStr) {
                progress.downloadPercent = percent
                onProgress(progress)
            }
        }

        // Parse video title: "[download] Destination: VideoTitle-ID.mp4"
        if output.contains("[download] Destination:") {
            if let start = output.range(of: "Destination: ")?.upperBound {
                let title = String(output[start...]).trimmingCharacters(in: .whitespacesAndNewlines)
                let filename = (title as NSString).lastPathComponent
                progress.videoTitle = filename
                onProgress(progress)
            }
        }
    }
}
