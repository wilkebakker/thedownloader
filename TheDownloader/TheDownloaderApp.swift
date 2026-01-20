// THE DOWNLOADER — Unified Media Downloader & Converter
// Menu bar app for downloading from YouTube, TikTok, Instagram
// and converting media files via drag & drop on the menu bar icon
// Dependencies: brew install yt-dlp ffmpeg

import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Shared State for Drag & Drop

enum DropAction {
    case none
    case convert
    case addToProject
    case convertAndAdd
}

class DropCoordinator: ObservableObject {
    static let shared = DropCoordinator()
    @Published var droppedFiles: [URL] = []
    @Published var pendingFiles: [URL] = []  // Files waiting for action choice
    @Published var shouldShowConverter: Bool = false
    @Published var shouldShowDropChoice: Bool = false
    @Published var dropAction: DropAction = .none
}

// MARK: - Project Manager

class ProjectManager: ObservableObject {
    static let shared = ProjectManager()

    @Published var currentProject: URL? {
        didSet {
            if let url = currentProject {
                UserDefaults.standard.set(url.path, forKey: "currentProjectPath")
            } else {
                UserDefaults.standard.removeObject(forKey: "currentProjectPath")
            }
        }
    }

    init() {
        // Load saved project
        if let path = UserDefaults.standard.string(forKey: "currentProjectPath") {
            let url = URL(fileURLWithPath: path)
            if FileManager.default.fileExists(atPath: url.path) {
                currentProject = url
            }
        }
    }

    func setProject(_ url: URL) {
        currentProject = url
    }

    func selectProject() {
        // Close popover first to avoid sidebar click issues
        NotificationCenter.default.post(name: .closePopover, object: nil)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let panel = NSOpenPanel()
            panel.canChooseFiles = false
            panel.canChooseDirectories = true
            panel.allowsMultipleSelection = false
            panel.prompt = "Set Project"
            panel.message = "Select your project folder"
            panel.level = .modalPanel

            NSApp.activate(ignoringOtherApps: true)

            if panel.runModal() == .OK, let url = panel.url {
                self.setProject(url)
            }
        }
    }

    func addFilesToProject(_ files: [URL]) {
        guard let dest = currentProject else { return }

        for file in files {
            let target = dest.appendingPathComponent(file.lastPathComponent)
            try? FileManager.default.copyItem(at: file, to: target)
        }

        // Open in Finder
        if let firstFile = files.first {
            let targetPath = dest.appendingPathComponent(firstFile.lastPathComponent).path
            NSWorkspace.shared.selectFile(targetPath, inFileViewerRootedAtPath: dest.path)
        } else {
            NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: dest.path)
        }
    }

    func unlinkProject() {
        currentProject = nil
    }

    func openInFinder() {
        guard let project = currentProject else { return }
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: project.path)
    }
}

// MARK: - App Entry Point

@main
struct TheDownloaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let closePopover = Notification.Name("closePopover")
}

// MARK: - App Delegate with Custom Status Item

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem!
    var popover: NSPopover!
    var dropZoneWindow: NSWindow?
    var eventMonitor: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Listen for close popover notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(closePopover),
            name: .closePopover,
            object: nil
        )
        // Create status item with drag & drop support
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "arrow.down.circle.fill", accessibilityDescription: "THE DOWNLOADER")
            button.action = #selector(handleStatusItemClick)
            button.sendAction(on: [.leftMouseUp, .leftMouseDown])
            button.target = self

            // Register for drag & drop
            button.window?.registerForDraggedTypes([.fileURL])
        }

        // Create popover
        popover = NSPopover()
        popover.contentSize = NSSize(width: 380, height: 540)
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: MainView())

        // Setup drag & drop view covering the status item
        setupDragDropView()

        // Check dependencies
        if !UserDefaults.standard.bool(forKey: "dependenciesChecked") {
            checkDependencies()
        }
    }

    func setupDragDropView() {
        guard let button = statusItem.button, button.window != nil else { return }

        let dropView = StatusItemDropView(frame: button.bounds)
        dropView.onDrop = { [weak self] urls in
            self?.handleDroppedFiles(urls)
        }
        dropView.autoresizingMask = [.width, .height]

        // Add drop view as overlay
        button.addSubview(dropView)
    }

    func handleDroppedFiles(_ urls: [URL]) {
        DropCoordinator.shared.pendingFiles = urls
        DropCoordinator.shared.shouldShowDropChoice = true

        // Show popover with drop choice
        if let button = statusItem.button {
            if !popover.isShown {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    @objc func handleStatusItemClick() {
        guard let event = NSApp.currentEvent else {
            togglePopover()
            return
        }

        // Only act on mouse up
        if event.type == .leftMouseDown {
            return
        }

        // Double-click: open project or Downloads folder in Finder
        if event.clickCount == 2 {
            popover.performClose(nil)
            if ProjectManager.shared.currentProject != nil {
                ProjectManager.shared.openInFinder()
            } else {
                // Open Downloads folder
                let downloadsPath = FileManager.default.homeDirectoryForCurrentUser
                    .appendingPathComponent("Downloads")
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: downloadsPath.path)
            }
        } else {
            // Single click: toggle popover
            togglePopover()
        }
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            }
        }
    }

    @objc func closePopover() {
        popover.performClose(nil)
    }

    func checkDependencies() {
        let hasYtDlp = which("yt-dlp") != nil
        let hasFFmpeg = which("ffmpeg") != nil

        if !hasYtDlp || !hasFFmpeg {
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Missing Dependencies"
                alert.informativeText = """
                THE DOWNLOADER requires:
                \(hasYtDlp ? "✓" : "✗") yt-dlp
                \(hasFFmpeg ? "✓" : "✗") ffmpeg

                Run the installer script or install manually:
                brew install yt-dlp ffmpeg
                """
                alert.alertStyle = .warning
                alert.addButton(withTitle: "OK")
                alert.runModal()
            }
        } else {
            UserDefaults.standard.set(true, forKey: "dependenciesChecked")
        }
    }
}

// MARK: - Drop View for Status Item

class StatusItemDropView: NSView {
    var onDrop: (([URL]) -> Void)?
    var isDragging = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        registerForDraggedTypes([.fileURL])
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        registerForDraggedTypes([.fileURL])
    }

    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        isDragging = true
        needsDisplay = true
        return .copy
    }

    override func draggingExited(_ sender: NSDraggingInfo?) {
        isDragging = false
        needsDisplay = true
    }

    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        isDragging = false
        needsDisplay = true

        guard let items = sender.draggingPasteboard.pasteboardItems else { return false }

        var urls: [URL] = []
        for item in items {
            if let urlString = item.string(forType: .fileURL),
               let url = URL(string: urlString) {
                urls.append(url)
            }
        }

        if !urls.isEmpty {
            onDrop?(urls)
            return true
        }
        return false
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        // Highlight when dragging
        if isDragging {
            NSColor.controlAccentColor.withAlphaComponent(0.3).setFill()
            dirtyRect.fill()
        }
    }
}

// MARK: - Main View

// MARK: - Tooltip Manager

class TooltipManager: ObservableObject {
    static let shared = TooltipManager()
    @Published var currentTooltip: String = ""
}

struct MainView: View {
    @StateObject private var dropCoordinator = DropCoordinator.shared
    @StateObject private var projectManager = ProjectManager.shared
    @StateObject private var tooltipManager = TooltipManager.shared
    @State private var selectedTab: AppTab = .download

    var body: some View {
        ZStack {
            VStack(spacing: 0) {
                // Project bar
                ProjectBar()

                // Clean tab bar
                HStack(spacing: 2) {
                    TabPill(title: "Download", icon: "arrow.down.circle.fill", tab: .download, selected: $selectedTab)
                    TabPill(title: "Convert", icon: "arrow.triangle.2.circlepath", tab: .convert, selected: $selectedTab)
                    TabPill(title: "Setup", icon: "gearshape.fill", tab: .setup, selected: $selectedTab)
                }
                .padding(4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(10)
                .padding(.horizontal, 16)
                .padding(.top, 8)
                .padding(.bottom, 4)

                // Content with smooth transitions
                ZStack {
                    DownloaderView()
                        .opacity(selectedTab == .download ? 1 : 0)
                        .offset(y: selectedTab == .download ? 0 : 10)
                        .allowsHitTesting(selectedTab == .download)

                    ConverterView()
                        .opacity(selectedTab == .convert ? 1 : 0)
                        .offset(y: selectedTab == .convert ? 0 : 10)
                        .allowsHitTesting(selectedTab == .convert)

                    SetupView()
                        .opacity(selectedTab == .setup ? 1 : 0)
                        .offset(y: selectedTab == .setup ? 0 : 10)
                        .allowsHitTesting(selectedTab == .setup)
                }
                .frame(maxWidth: .infinity)
                .animation(.easeOut(duration: 0.15), value: selectedTab)
            }
            .background(Color(NSColor.windowBackgroundColor))

            // Drop choice overlay
            if dropCoordinator.shouldShowDropChoice {
                DropChoiceView(selectedTab: $selectedTab)
            }
        }
        .frame(width: 380, height: 540)
        .onReceive(dropCoordinator.$shouldShowConverter) { shouldShow in
            if shouldShow {
                selectedTab = .convert
                dropCoordinator.shouldShowConverter = false
            }
        }
    }
}

// MARK: - Tooltip Modifier

struct TooltipOnHover: ViewModifier {
    let tooltip: String
    @StateObject private var tooltipManager = TooltipManager.shared

    func body(content: Content) -> some View {
        content
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.15)) {
                    tooltipManager.currentTooltip = hovering ? tooltip : ""
                }
            }
    }
}

extension View {
    func tooltip(_ text: String) -> some View {
        modifier(TooltipOnHover(tooltip: text))
    }
}

// MARK: - Project Bar

struct ProjectBar: View {
    @StateObject private var projectManager = ProjectManager.shared

    var hasProject: Bool {
        projectManager.currentProject != nil
    }

    var projectName: String {
        projectManager.currentProject?.lastPathComponent ?? "No project"
    }

    var body: some View {
        HStack(spacing: 10) {
            Button {
                if hasProject {
                    projectManager.openInFinder()
                } else {
                    projectManager.selectProject()
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "folder.fill")
                        .font(.system(size: 15))
                        .foregroundColor(hasProject ? .accentColor : .secondary)

                    Text(projectName)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(hasProject ? .primary : .secondary)
                        .lineLimit(1)
                        .truncationMode(.middle)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if hasProject {
                Button("Open") {
                    projectManager.openInFinder()
                }
                .font(.system(size: 11))
                .controlSize(.small)

                Button("Change") {
                    projectManager.selectProject()
                }
                .font(.system(size: 11))
                .controlSize(.small)

                Button {
                    projectManager.unlinkProject()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .tooltip("Unlink project")
            } else {
                Button("Select Folder") {
                    projectManager.selectProject()
                }
                .font(.system(size: 11))
                .controlSize(.small)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    }
}

// MARK: - Drop Choice View

struct DropChoiceView: View {
    @StateObject private var dropCoordinator = DropCoordinator.shared
    @StateObject private var projectManager = ProjectManager.shared
    @Binding var selectedTab: AppTab

    var fileCount: Int { dropCoordinator.pendingFiles.count }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 4) {
                Image(systemName: "doc.on.doc.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.accentColor)

                Text("\(fileCount) file\(fileCount == 1 ? "" : "s") dropped")
                    .font(.system(size: 14, weight: .semibold))

                Text("What would you like to do?")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.top, 20)

            // Action buttons
            VStack(spacing: 10) {
                DropActionButton(
                    title: "Convert",
                    subtitle: "Change format (MP4, WAV, WebP...)",
                    icon: "arrow.triangle.2.circlepath",
                    color: .accentColor
                ) {
                    dropCoordinator.droppedFiles = dropCoordinator.pendingFiles
                    dropCoordinator.pendingFiles = []
                    dropCoordinator.shouldShowDropChoice = false
                    selectedTab = .convert
                }

                DropActionButton(
                    title: "Add to Project",
                    subtitle: projectManager.currentProject != nil
                        ? "Copy to \(projectManager.currentProject!.lastPathComponent)"
                        : "Set a project first",
                    icon: "folder.badge.plus",
                    color: .green,
                    disabled: projectManager.currentProject == nil
                ) {
                    projectManager.addFilesToProject(dropCoordinator.pendingFiles)
                    dropCoordinator.pendingFiles = []
                    dropCoordinator.shouldShowDropChoice = false
                    // Close popover after adding to project
                    NotificationCenter.default.post(name: .closePopover, object: nil)
                }

                DropActionButton(
                    title: "Convert & Add",
                    subtitle: "Convert then copy to project",
                    icon: "arrow.triangle.2.circlepath.doc.on.clipboard",
                    color: .orange,
                    disabled: projectManager.currentProject == nil
                ) {
                    dropCoordinator.droppedFiles = dropCoordinator.pendingFiles
                    dropCoordinator.dropAction = .convertAndAdd
                    dropCoordinator.pendingFiles = []
                    dropCoordinator.shouldShowDropChoice = false
                    selectedTab = .convert
                }
            }
            .padding(.horizontal, 24)

            // Cancel
            Button("Cancel") {
                dropCoordinator.pendingFiles = []
                dropCoordinator.shouldShowDropChoice = false
                NotificationCenter.default.post(name: .closePopover, object: nil)
            }
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.ultraThinMaterial)
    }
}

struct DropActionButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(disabled ? .secondary : color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(disabled ? .secondary : .primary)

                    Text(subtitle)
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(12)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(disabled ? Color.clear : color.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.6 : 1)
    }
}

struct TabPill: View {
    let title: String
    let icon: String
    let tab: AppTab
    @Binding var selected: AppTab

    var isSelected: Bool { selected == tab }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selected = tab
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 11))
                Text(title)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
            }
            .foregroundColor(isSelected ? .white : .secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(isSelected ? Color.accentColor : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

enum AppTab {
    case download
    case convert
    case setup
}
