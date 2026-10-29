import SwiftUI

@MainActor
struct PermissionRow: View {
    let permission: SystemPermission
    let permissionsStore: SystemPermissionStore

    private var isGranted: Bool {
        permissionsStore.isGranted(permission)
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: permission.icon)
                .font(.title3)
                .frame(width: 28)
                .foregroundStyle(isGranted ? .green : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(permission.title)
                    .font(.subheadline.bold())
                Text(permission.description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if isGranted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.title3)
            } else {
                Button(String(localized: "setup.step1.enable", defaultValue: "Enable")) {
                    permissionsStore.request(permission)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(12)
        .background(.quaternary, in: RoundedRectangle(cornerRadius: 10))
    }
}
