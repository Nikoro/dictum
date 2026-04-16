import SwiftUI

private struct InstalledAppInfo: Identifiable {
    let bundleId: String
    let appName: String
    let icon: NSImage

    var id: String { bundleId }
}

struct InstalledAppPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let excludedBundleIds: Set<String>
    let onSelect: (_ bundleId: String, _ appName: String) -> Void

    @State private var searchText = ""
    @State private var apps: [InstalledAppInfo] = []
    @State private var isLoading = true

    private var filteredApps: [InstalledAppInfo] {
        let available = apps.filter { !excludedBundleIds.contains($0.bundleId) }
        if searchText.isEmpty { return available }
        return available.filter { $0.appName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(String(localized: "picker.search", defaultValue: "Search apps..."), text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(.quaternary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal)

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, minHeight: 100)
            } else if filteredApps.isEmpty {
                Text(searchText.isEmpty
                    ? String(localized: "picker.empty", defaultValue: "No apps found")
                    : String(localized: "picker.noResults", defaultValue: "No results"))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 60)
            } else {
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(filteredApps) { app in
                            Button {
                                onSelect(app.bundleId, app.appName)
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(nsImage: app.icon)
                                        .resizable()
                                        .interpolation(.high)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                    Text(app.appName)
                                        .font(.body)
                                    Spacer()
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .frame(width: 320, height: 400)
        .task { await loadInstalledApps() }
    }

    private func loadInstalledApps() async {
        let found: [InstalledAppInfo] = await Task.detached {
            let workspace = NSWorkspace.shared
            var result: [InstalledAppInfo] = []
            var seen = Set<String>()

            func scanApps(in directory: URL) {
                guard let contents = try? FileManager.default.contentsOfDirectory(
                    at: directory,
                    includingPropertiesForKeys: nil
                ) else { return }
                for url in contents where url.pathExtension == "app" {
                    guard let bundle = Bundle(url: url),
                          let bundleId = bundle.bundleIdentifier,
                          !seen.contains(bundleId) else { continue }
                    seen.insert(bundleId)
                    let name = FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
                    let icon = workspace.icon(forFile: url.path)
                    result.append(InstalledAppInfo(bundleId: bundleId, appName: name, icon: icon))
                }
            }

            let appDirs = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
                + FileManager.default.urls(for: .applicationDirectory, in: .systemDomainMask)
            for dir in appDirs { scanApps(in: dir) }

            let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            scanApps(in: userApps)

            return result.sorted {
                $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
            }
        }.value

        apps = found
        isLoading = false
    }
}
