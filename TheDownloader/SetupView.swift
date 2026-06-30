// SetupView — Install Finder Quick Actions & Updates

import SwiftUI
import AppKit
import Sparkle

// MARK: - Cookie Browser (for Instagram auth)

/// Which browser yt-dlp pulls login cookies from. Instagram needs a logged-in
/// session; the raw values are exactly the names yt-dlp's --cookies-from-browser
/// expects. `none` disables cookie use entirely.
enum CookieBrowser: String, CaseIterable, Identifiable {
    case none, safari, chrome, firefox, brave, edge
    var id: String { rawValue }
    var label: String {
        switch self {
        case .none: return "None"
        case .safari: return "Safari"
        case .chrome: return "Chrome"
        case .firefox: return "Firefox"
        case .brave: return "Brave"
        case .edge: return "Edge"
        }
    }
}

// MARK: - Sparkle Updater Controller

final class UpdaterViewModel: ObservableObject {
    private let updaterController: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false
    @Published var lastUpdateCheckDate: Date?

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)

        updaterController.updater.publisher(for: \.lastUpdateCheckDate)
            .assign(to: &$lastUpdateCheckDate)
    }

    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }

    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { updaterController.updater.automaticallyDownloadsUpdates }
        set { updaterController.updater.automaticallyDownloadsUpdates = newValue }
    }
}

// MARK: - Setup View

struct SetupView: View {
    @StateObject private var updaterViewModel = UpdaterViewModel()
    @State private var quickActionsInstalled = false
    @State private var quickActionsStatus = ""
    @State private var isWorking = false
    @AppStorage("cookieBrowser") private var cookieBrowser: String = CookieBrowser.safari.rawValue

    private let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"

    var body: some View {
        VStack(spacing: 12) {
            // Updates Card
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "arrow.triangle.2.circlepath.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text("Updates")
                                .font(.system(size: 12, weight: .medium))
                            Text("v\(currentVersion)")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }

                        if let lastCheck = updaterViewModel.lastUpdateCheckDate {
                            Text("Last checked: \(lastCheck, style: .relative) ago")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Check for updates via Sparkle")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Button("Check") {
                        updaterViewModel.checkForUpdates()
                    }
                    .font(.system(size: 11))
                    .controlSize(.small)
                    .disabled(!updaterViewModel.canCheckForUpdates)
                }

                // Auto-update toggle
                HStack {
                    Toggle(isOn: Binding(
                        get: { updaterViewModel.automaticallyChecksForUpdates },
                        set: { updaterViewModel.automaticallyChecksForUpdates = $0 }
                    )) {
                        Text("Update automatically")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    .toggleStyle(.checkbox)
                    .controlSize(.small)
                    Spacer()
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )

            // TikTok Card
            HStack(spacing: 12) {
                Image(systemName: "play.rectangle.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.accentColor)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text("TikTok & YouTube")
                        .font(.system(size: 12, weight: .medium))
                    Text("Work out of the box — no login needed")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )

            // Instagram Card — needs cookies from a logged-in browser
            VStack(spacing: 10) {
                HStack(spacing: 12) {
                    Image(systemName: "camera.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                        .frame(width: 32)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Instagram Login")
                            .font(.system(size: 12, weight: .medium))
                        Text("Reels & Stories need a logged-in browser")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Picker("", selection: $cookieBrowser) {
                        ForEach(CookieBrowser.allCases) { browser in
                            Text(browser.label).tag(browser.rawValue)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.small)
                    .frame(width: 100)
                }

                // Safari cookies live in a protected folder → the app needs Full
                // Disk Access. This button registers the app in that list and opens
                // it, so the user only has to flip the switch.
                if cookieBrowser == CookieBrowser.safari.rawValue {
                    Button {
                        grantSafariAccess()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "lock.open.fill")
                                .font(.system(size: 10))
                            Text("Enable Full Disk Access (then toggle TheDownloader on)")
                                .font(.system(size: 10, weight: .medium))
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 5)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )

            // Quick Actions Card
            HStack(spacing: 12) {
                Image(systemName: "cursorarrow.click.badge.clock")
                    .font(.system(size: 20))
                    .foregroundColor(quickActionsInstalled ? .accentColor : .secondary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Finder Quick Actions")
                            .font(.system(size: 12, weight: .medium))
                        if quickActionsInstalled {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.green)
                        }
                    }

                    if !quickActionsStatus.isEmpty {
                        Text(quickActionsStatus)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Right-click files to Webify or convert")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                Button(quickActionsInstalled ? "Refresh" : "Get") {
                    installQuickActions()
                }
                .font(.system(size: 11))
                .controlSize(.small)
                .disabled(isWorking)
            }
            .padding(14)
            .background(Color(NSColor.controlBackgroundColor))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )

            Spacer()

            // Legal notice box
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.orange)
                    Text("Legal Notice")
                        .font(.system(size: 11, weight: .semibold))
                }
                Text("Only download content you have rights to use. The developer is not responsible for any copyright claims or legal issues arising from misuse of this tool.")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.orange.opacity(0.08))
            .cornerRadius(8)
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.orange.opacity(0.2), lineWidth: 1)
            )
        }
        .padding(16)
        .onAppear {
            checkInstallStatus()
        }
    }

    // MARK: - Full Disk Access (for Safari cookies)

    /// Make the app appear in the Full Disk Access list so the user only flips a
    /// toggle — no hunting with the "+" button. macOS adds an app to that list the
    /// moment it tries to read an FDA-protected path, so we touch Safari's cookie
    /// store (the exact thing yt-dlp needs) and then open the settings pane.
    func grantSafariAccess() {
        touchFullDiskAccessProtectedPaths()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles") {
            NSWorkspace.shared.open(url)
        }
    }

    // MARK: - Quick Actions Functions

    func checkInstallStatus() {
        let servicesDir = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Services")
        quickActionsInstalled = FileManager.default.fileExists(
            atPath: servicesDir.appendingPathComponent("Webify.workflow").path
        )
    }

    func installQuickActions() {
        isWorking = true
        quickActionsStatus = "Installing..."

        Task.detached {
            let servicesDir = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Library/Services")

            do {
                try FileManager.default.createDirectory(at: servicesDir, withIntermediateDirectories: true)

                if let resourceURL = Bundle.main.resourceURL {
                    let workflowsPath = resourceURL.appendingPathComponent("QuickActions")

                    for workflow in ["Webify.workflow", "Convert to WAV.workflow"] {
                        let src = workflowsPath.appendingPathComponent(workflow)
                        let dst = servicesDir.appendingPathComponent(workflow)

                        if FileManager.default.fileExists(atPath: src.path) {
                            try? FileManager.default.removeItem(at: dst)
                            try FileManager.default.copyItem(at: src, to: dst)
                        }
                    }
                }

                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/System/Library/CoreServices/pbs")
                task.arguments = ["-flush"]
                try? task.run()
                task.waitUntilExit()

                await MainActor.run {
                    quickActionsInstalled = true
                    quickActionsStatus = "Installed! Right-click in Finder."
                    isWorking = false

                    DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                        quickActionsStatus = ""
                    }
                }
            } catch {
                await MainActor.run {
                    quickActionsStatus = "Error: \(error.localizedDescription)"
                    isWorking = false
                }
            }
        }
    }
}
