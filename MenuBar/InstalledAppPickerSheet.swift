import SwiftUI

struct InstalledAppPickerSheet: View {
    @Environment(\.dismiss) var dismiss
    let title: String
    let excludedBundleIds: Set<String>
    let onSelect: (_ bundleId: String, _ appName: String) -> Void

    @State private var searchText = ""
    @State private var apps: [(name: String, bundleId: String, icon: NSImage)] = []
    @State private var isLoading = true

    private var filteredApps: [(name: String, bundleId: String, icon: NSImage)] {
        let available = apps.filter { !excludedBundleIds.contains($0.bundleId) }
        if searchText.isEmpty { return available }
        return available.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
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
                TextField(String(localized: "picker.search", defaultValue: "Szukaj aplikacji..."), text: $searchText)
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
                        ForEach(filteredApps, id: \.bundleId) { app in
                            Button {
                                onSelect(app.bundleId, app.name)
                                dismiss()
                            } label: {
                                HStack(spacing: 8) {
                                    Image(nsImage: app.icon)
                                        .resizable()
                                        .interpolation(.high)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 24, height: 24)
                                    Text(app.name)
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
        let found: [(name: String, bundleId: String, icon: NSImage)] = await Task.detached {
            let workspace = NSWorkspace.shared
            let appURLs = FileManager.default.urls(for: .applicationDirectory, in: .localDomainMask)
                + FileManager.default.urls(for: .applicationDirectory, in: .systemDomainMask)

            var result: [(name: String, bundleId: String, icon: NSImage)] = []
            var seen = Set<String>()

            for dir in appURLs {
                guard let contents = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else { continue }
                for url in contents where url.pathExtension == "app" {
                    guard let bundle = Bundle(url: url),
                          let bundleId = bundle.bundleIdentifier,
                          !seen.contains(bundleId) else { continue }
                    seen.insert(bundleId)
                    let name = FileManager.default.displayName(atPath: url.path)
                    let icon = workspace.icon(forFile: url.path)
                    icon.size = NSSize(width: 24, height: 24)
                    result.append((name: name, bundleId: bundleId, icon: icon))
                }
            }

            let userApps = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications")
            if let contents = try? FileManager.default.contentsOfDirectory(at: userApps, includingPropertiesForKeys: nil) {
                for url in contents where url.pathExtension == "app" {
                    guard let bundle = Bundle(url: url),
                          let bundleId = bundle.bundleIdentifier,
                          !seen.contains(bundleId) else { continue }
                    seen.insert(bundleId)
                    let name = FileManager.default.displayName(atPath: url.path)
                    let icon = workspace.icon(forFile: url.path)
                    icon.size = NSSize(width: 24, height: 24)
                    result.append((name: name, bundleId: bundleId, icon: icon))
                }
            }

            return result.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        }.value

        apps = found
        isLoading = false
    }
}
