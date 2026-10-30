import SwiftUI

private struct InstalledAppInfo: Identifiable {
    let bundleId: String
    let appName: String
    let icon: NSImage

    var id: String {
        bundleId
    }
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
        if searchText.isEmpty {
            return available
        }
        return available.filter { $0.appName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            searchField
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
                appList
            }
        }
        .frame(width: 320, height: 400)
        .task {
            apps = await InstalledAppScanner.scan()
            isLoading = false
        }
    }

    private var header: some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(String(localized: "a11y.close", defaultValue: "Close"))
        }
        .padding()
    }

    private var searchField: some View {
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
    }

    private var appList: some View {
        ScrollView {
            LazyVStack(spacing: 2) {
                ForEach(filteredApps) { app in
                    Button {
                        onSelect(app.bundleId, app.appName)
                        dismiss()
                    } label: {
                        InstalledAppRow(app: app)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 8)
        }
    }
}

private struct InstalledAppRow: View {
    let app: InstalledAppInfo

    var body: some View {
        HStack(spacing: 8) {
            Image(nsImage: app.icon)
                .resizable()
                .interpolation(.high)
                .scaledToFit()
                .frame(width: 24, height: 24)
            Text(app.appName)
                .font(.body)
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

private enum InstalledAppScanner {
    static func scan() async -> [InstalledAppInfo] {
        await Task.detached {
            let fileManager = FileManager.default
            let directories = fileManager.urls(for: .applicationDirectory, in: .localDomainMask)
                + fileManager.urls(for: .applicationDirectory, in: .systemDomainMask)
                + [fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications")]

            var seen = Set<String>()
            let apps = directories.flatMap(appBundles).filter { seen.insert($0.bundleId).inserted }
            return apps.sorted {
                $0.appName.localizedCaseInsensitiveCompare($1.appName) == .orderedAscending
            }
        }.value
    }

    private static func appBundles(in directory: URL) -> [InstalledAppInfo] {
        let fileManager = FileManager.default
        let contents = (try? fileManager.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)) ?? []
        return contents.filter { $0.pathExtension == "app" }.compactMap { url in
            guard let bundleId = Bundle(url: url)?.bundleIdentifier else { return nil }
            let name = fileManager.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "")
            return InstalledAppInfo(bundleId: bundleId, appName: name, icon: NSWorkspace.shared.icon(forFile: url.path))
        }
    }
}
