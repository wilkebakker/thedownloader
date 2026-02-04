// SetupView — Install Finder Quick Actions & Updates

import SwiftUI
import AppKit
import Sparkle

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
                    Text("TikTok")
                        .font(.system(size: 12, weight: .medium))
                    Text("Downloads work without Safari cookies")
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
