// ConverterView — Clean drag & drop media converter

import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ConverterView: View {
    @StateObject private var dropCoordinator = DropCoordinator.shared
    @State private var droppedFiles: [URL] = []
    @State private var selectedFormats: Set<ConvertFormat> = [.wav24]
    @State private var proresProfile: ProResProfile = .hq
    @State private var rescaleOption: RescaleOption = .none
    @State private var isConverting: Bool = false
    @State private var progress: Double = 0
    @State private var currentItem: Int = 0
    @State private var statusMessage: String = ""
    @State private var isTargeted: Bool = false

    var fileTypes: FileTypes {
        var types = FileTypes()
        for file in droppedFiles {
            let ext = file.pathExtension.lowercased()
            if ["mp4", "mov", "avi", "mkv", "webm", "m4v", "flv"].contains(ext) {
                types.hasVideo = true
            } else if ["mp3", "wav", "aac", "flac", "m4a", "ogg", "aiff"].contains(ext) {
                types.hasAudio = true
            } else if ["png", "jpg", "jpeg", "webp", "gif", "tiff", "bmp", "heic"].contains(ext) {
                types.hasImage = true
            }
        }
        return types
    }

    var body: some View {
        VStack(spacing: 14) {
            // Drop Zone
            DropArea(files: $droppedFiles, isTargeted: $isTargeted, isConverting: isConverting)

            // Format Selection - Centered with labels
            VStack(spacing: 12) {
                // Audio
                VStack(spacing: 6) {
                    Text("AUDIO")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1)
                    HStack(spacing: 6) {
                        FormatToggle(format: .wav24, selected: $selectedFormats)
                        FormatToggle(format: .mp3, selected: $selectedFormats)
                    }
                }

                // Video
                VStack(spacing: 6) {
                    Text("VIDEO")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1)
                    HStack(spacing: 6) {
                        FormatToggle(format: .mp4H264, selected: $selectedFormats)
                        FormatToggle(format: .mp4H265, selected: $selectedFormats)
                        FormatToggle(format: .webm, selected: $selectedFormats)
                    }
                }

                // Image
                VStack(spacing: 6) {
                    Text("IMAGE")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(1)
                    HStack(spacing: 6) {
                        FormatToggle(format: .webp, selected: $selectedFormats)
                        FormatToggle(format: .png, selected: $selectedFormats)
                        FormatToggle(format: .jpg, selected: $selectedFormats)
                    }
                }
            }

            // Progress
            if isConverting {
                VStack(spacing: 4) {
                    ProgressView(value: progress)
                        .tint(.accentColor)
                    HStack {
                        Text(statusMessage)
                            .lineLimit(1)
                        Spacer()
                        Text("\(currentItem)/\(totalConversions)")
                            .fontWeight(.medium)
                    }
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                }
            }

            Spacer(minLength: 0)

            // Action Buttons
            HStack(spacing: 8) {
                Button { webifyFiles() } label: {
                    Text("Webify")
                        .font(.system(size: 12, weight: .medium))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(droppedFiles.isEmpty ? Color.secondary.opacity(0.15) : Color.accentColor)
                        .foregroundColor(droppedFiles.isEmpty ? .secondary : .white)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
                .disabled(droppedFiles.isEmpty || isConverting)

                Button { startConversion() } label: {
                    HStack(spacing: 4) {
                        if isConverting {
                            ProgressView()
                                .scaleEffect(0.5)
                                .progressViewStyle(CircularProgressViewStyle(tint: .primary))
                        }
                        Text(isConverting ? "Converting..." : "Convert")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(canConvert ? Color(NSColor.controlBackgroundColor) : Color.secondary.opacity(0.15))
                    .foregroundColor(canConvert ? .primary : .secondary)
                    .cornerRadius(8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .disabled(!canConvert)
            }
        }
        .padding(16)
        .onReceive(dropCoordinator.$droppedFiles) { files in
            if !files.isEmpty {
                droppedFiles.append(contentsOf: files)
                dropCoordinator.droppedFiles = []
                autoSelectFormats()
            }
        }
    }

    // MARK: - Computed Properties

    var canConvert: Bool {
        !isConverting && !droppedFiles.isEmpty && !selectedFormats.isEmpty
    }

    var totalConversions: Int {
        droppedFiles.count * selectedFormats.count
    }

    // MARK: - Actions

    func autoSelectFormats() {
        if fileTypes.hasVideo && selectedFormats.isEmpty {
            selectedFormats = [.mp4H264]
        } else if fileTypes.hasAudio && selectedFormats.isEmpty {
            selectedFormats = [.wav24]
        } else if fileTypes.hasImage && selectedFormats.isEmpty {
            selectedFormats = [.webp]
        }
    }

    func webifyFiles() {
        selectedFormats.removeAll()

        if fileTypes.hasVideo {
            selectedFormats.insert(.webm)
        }
        if fileTypes.hasImage {
            selectedFormats.insert(.webp)
        }
        if fileTypes.hasAudio {
            selectedFormats.insert(.mp3)
        }

        startConversion()
    }

    func startConversion() {
        guard !droppedFiles.isEmpty && !selectedFormats.isEmpty else { return }

        isConverting = true
        currentItem = 0
        progress = 0
        statusMessage = "Starting..."

        let files = droppedFiles
        let formats = Array(selectedFormats)
        let profile = proresProfile
        let scale = rescaleOption
        let shouldAddToProject = dropCoordinator.dropAction == .convertAndAdd

        let total = files.count * formats.count
        var outputFiles: [URL] = []

        Task.detached {
            for (fileIndex, file) in files.enumerated() {
                for (formatIndex, format) in formats.enumerated() {
                    let completed = fileIndex * formats.count + formatIndex + 1
                    await MainActor.run {
                        currentItem = completed
                        progress = Double(completed - 1) / Double(total)
                        statusMessage = "\(file.lastPathComponent) → \(format.label)"
                    }

                    let outputDir = file.deletingLastPathComponent().path
                    let result = await convertFile(file, to: format, proresProfile: profile, rescale: scale, outputDir: outputDir)

                    if result.status == 0 {
                        let baseName = file.deletingPathExtension().lastPathComponent
                        let outputName = "\(baseName)\(format.suffix).\(format.ext)"
                        let outputURL = URL(fileURLWithPath: outputDir).appendingPathComponent(outputName)
                        outputFiles.append(outputURL)
                    }
                }
            }

            if shouldAddToProject {
                await MainActor.run {
                    statusMessage = "Adding to project..."
                }
                ProjectManager.shared.addFilesToProject(outputFiles)
            }

            await MainActor.run {
                isConverting = false
                progress = 1.0
                statusMessage = shouldAddToProject ? "Added to project!" : "Complete!"
                dropCoordinator.dropAction = .none

                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    if !isConverting {
                        droppedFiles.removeAll()
                        statusMessage = ""
                        rescaleOption = .none
                    }
                }
            }
        }
    }
}

// MARK: - File Types

struct FileTypes {
    var hasVideo = false
    var hasAudio = false
    var hasImage = false

    var isEmpty: Bool { !hasVideo && !hasAudio && !hasImage }
}

// MARK: - Drop Area

struct DropArea: View {
    @Binding var files: [URL]
    @Binding var isTargeted: Bool
    let isConverting: Bool

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(NSColor.textBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(
                            isTargeted ? Color.accentColor : Color.primary.opacity(0.08),
                            style: StrokeStyle(lineWidth: isTargeted ? 2 : 1)
                        )
                )

            if files.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 20))
                        .foregroundColor(.secondary.opacity(0.5))
                    Text("Drop files here")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 0) {
                    HStack {
                        Text("\(files.count) file\(files.count == 1 ? "" : "s")")
                            .font(.system(size: 11, weight: .medium))
                        Spacer()
                        Button("Clear") { files.removeAll() }
                            .font(.system(size: 10))
                            .buttonStyle(.borderless)
                            .foregroundColor(.accentColor)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)

                    Divider()

                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(files, id: \.self) { file in
                                HStack {
                                    Text(file.lastPathComponent)
                                        .font(.system(size: 10))
                                        .lineLimit(1)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Button { files.removeAll { $0 == file } } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 8))
                                            .foregroundColor(.secondary.opacity(0.6))
                                    }
                                    .buttonStyle(.borderless)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 4)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: 80)
        .onDrop(of: [.fileURL], isTargeted: $isTargeted) { providers in
            for provider in providers {
                provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, _ in
                    guard let data = item as? Data,
                          let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                    DispatchQueue.main.async {
                        if !files.contains(url) { files.append(url) }
                    }
                }
            }
            return true
        }
        .onTapGesture {
            if !isConverting && files.isEmpty { browseFiles() }
        }
    }

    func browseFiles() {
        NotificationCenter.default.post(name: .closePopover, object: nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let panel = NSOpenPanel()
            panel.canChooseFiles = true
            panel.canChooseDirectories = false
            panel.allowsMultipleSelection = true
            panel.level = .modalPanel
            NSApp.activate(ignoringOtherApps: true)
            if panel.runModal() == .OK {
                DispatchQueue.main.async {
                    for url in panel.urls where !self.files.contains(url) {
                        self.files.append(url)
                    }
                }
            }
        }
    }
}


// MARK: - Format Toggle

struct FormatToggle: View {
    let format: ConvertFormat
    @Binding var selected: Set<ConvertFormat>

    var isSelected: Bool { selected.contains(format) }

    var body: some View {
        Button {
            if isSelected {
                selected.remove(format)
            } else {
                selected.insert(format)
            }
        } label: {
            Text(format.label)
                .font(.system(size: 10, weight: .medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color(NSColor.controlBackgroundColor))
                .foregroundColor(isSelected ? .white : .primary)
                .cornerRadius(6)
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isSelected ? Color.clear : Color.primary.opacity(0.06), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}


// MARK: - ProRes Profiles

enum ProResProfile: CaseIterable {
    case proxy, lt, standard, hq, fourFourFourFour, fourFourFourFourXQ

    var label: String {
        switch self {
        case .proxy: return "422 Proxy"
        case .lt: return "422 LT"
        case .standard: return "422"
        case .hq: return "422 HQ"
        case .fourFourFourFour: return "4444"
        case .fourFourFourFourXQ: return "4444 XQ"
        }
    }

    var shortLabel: String {
        switch self {
        case .proxy: return "Proxy"
        case .lt: return "LT"
        case .standard: return "422"
        case .hq: return "HQ"
        case .fourFourFourFour: return "4444"
        case .fourFourFourFourXQ: return "XQ"
        }
    }

    var ffmpegProfile: String {
        switch self {
        case .proxy: return "0"
        case .lt: return "1"
        case .standard: return "2"
        case .hq: return "3"
        case .fourFourFourFour: return "4"
        case .fourFourFourFourXQ: return "5"
        }
    }
}

// MARK: - Rescale Options

enum RescaleOption: CaseIterable {
    case none, hd720, hd1080, uhd4k, half, quarter

    var label: String {
        switch self {
        case .none: return "Original"
        case .hd720: return "720p (1280×720)"
        case .hd1080: return "1080p (1920×1080)"
        case .uhd4k: return "4K (3840×2160)"
        case .half: return "50%"
        case .quarter: return "25%"
        }
    }

    var shortLabel: String {
        switch self {
        case .none: return "Original"
        case .hd720: return "720p"
        case .hd1080: return "1080p"
        case .uhd4k: return "4K"
        case .half: return "50%"
        case .quarter: return "25%"
        }
    }

    var ffmpegScale: String? {
        switch self {
        case .none: return nil
        case .hd720: return "1280:720"
        case .hd1080: return "1920:1080"
        case .uhd4k: return "3840:2160"
        case .half: return "iw/2:ih/2"
        case .quarter: return "iw/4:ih/4"
        }
    }
}

// MARK: - Conversion Formats

enum ConvertFormat: Hashable, CaseIterable {
    case wav24, mp3
    case mp4H264, mp4H265, webm, prores
    case webp, png, jpg

    var label: String {
        switch self {
        case .wav24: return "WAV"
        case .mp3: return "MP3"
        case .mp4H264: return "H.264"
        case .mp4H265: return "H.265"
        case .webm: return "WebM"
        case .prores: return "ProRes"
        case .webp: return "WebP"
        case .png: return "PNG"
        case .jpg: return "JPG"
        }
    }

    var ext: String {
        switch self {
        case .wav24: return "wav"
        case .mp3: return "mp3"
        case .mp4H264, .mp4H265: return "mp4"
        case .webm: return "webm"
        case .prores: return "mov"
        case .webp: return "webp"
        case .png: return "png"
        case .jpg: return "jpg"
        }
    }

    var suffix: String {
        switch self {
        case .wav24: return "_24bit"
        case .mp3: return ""
        case .mp4H264: return "_h264"
        case .mp4H265: return "_h265"
        case .webm: return "_web"
        case .prores: return "_prores"
        case .webp: return ""
        case .png: return ""
        case .jpg: return ""
        }
    }

    var tooltip: String {
        switch self {
        case .wav24: return "48kHz 24-bit PCM"
        case .mp3: return "320kbps MP3"
        case .mp4H264: return "Universal playback"
        case .mp4H265: return "50% smaller files"
        case .webm: return "Optimized for web"
        case .prores: return "Professional editing"
        case .webp: return "Smaller than PNG/JPG"
        case .png: return "Lossless with alpha"
        case .jpg: return "High-quality JPEG"
        }
    }
}

// MARK: - Conversion Function

func convertFile(_ input: URL, to format: ConvertFormat, proresProfile: ProResProfile, rescale: RescaleOption, outputDir: String) async -> (status: Int32, output: String) {
    guard let ffmpeg = which("ffmpeg") else {
        return (1, "ffmpeg not found")
    }

    let baseName = input.deletingPathExtension().lastPathComponent
    let outputName = "\(baseName)\(format.suffix).\(format.ext)"
    let outputPath = URL(fileURLWithPath: outputDir).appendingPathComponent(outputName).path

    var args: [String] = [ffmpeg, "-i", input.path, "-y"]

    var filters: [String] = []
    if let scale = rescale.ffmpegScale {
        filters.append("scale=\(scale):flags=lanczos")
    }

    switch format {
    case .wav24:
        args += ["-ar", "48000", "-ac", "2", "-c:a", "pcm_s24le"]

    case .mp3:
        args += ["-c:a", "libmp3lame", "-q:a", "0"]

    case .mp4H264:
        if !filters.isEmpty {
            args += ["-vf", filters.joined(separator: ",")]
        }
        args += ["-c:v", "libx264", "-preset", "medium", "-crf", "18", "-c:a", "aac", "-b:a", "192k", "-pix_fmt", "yuv420p", "-movflags", "+faststart"]

    case .mp4H265:
        if !filters.isEmpty {
            args += ["-vf", filters.joined(separator: ",")]
        }
        args += ["-c:v", "libx265", "-preset", "medium", "-crf", "22", "-c:a", "aac", "-b:a", "192k", "-tag:v", "hvc1"]

    case .webm:
        if !filters.isEmpty {
            args += ["-vf", filters.joined(separator: ",")]
        }
        args += ["-c:v", "libvpx-vp9", "-crf", "30", "-b:v", "0", "-c:a", "libopus", "-b:a", "128k"]

    case .prores:
        if !filters.isEmpty {
            args += ["-vf", filters.joined(separator: ",")]
        }
        args += ["-c:v", "prores_ks", "-profile:v", proresProfile.ffmpegProfile, "-c:a", "pcm_s24le"]

    case .webp:
        if !filters.isEmpty {
            args += ["-vf", filters.joined(separator: ",")]
        }
        args += ["-c:v", "libwebp", "-lossless", "0", "-quality", "90", "-pix_fmt", "yuva420p"]

    case .png:
        if !filters.isEmpty {
            args += ["-vf", filters.joined(separator: ",")]
        }
        args += ["-c:v", "png"]

    case .jpg:
        if !filters.isEmpty {
            args += ["-vf", filters.joined(separator: ",")]
        }
        args += ["-q:v", "2"]
    }

    args.append(outputPath)
    return await runProcess(args: args)
}
