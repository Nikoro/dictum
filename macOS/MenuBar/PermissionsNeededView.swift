import SwiftUI

@MainActor
struct PermissionsNeededView: View {
    let permissionsStore: SystemPermissionStore

    private var missingPermissions: [SystemPermission] {
        SystemPermission.allCases.filter { !permissionsStore.isGranted($0) }
    }

    var body: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "hand.raised.fill")
                .font(.system(size: 36))
                .foregroundStyle(.secondary)

            Text(String(localized: "permissions.needed.title", defaultValue: "Permissions needed"))
                .font(.headline)

            Text(
                String(
                    localized: "permissions.needed.desc",
                    defaultValue: "After the update, macOS requires you to re-enable permissions."
                )
            )
            .font(.caption)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 24)

            VStack(spacing: 10) {
                ForEach(missingPermissions) { permission in
                    PermissionRow(permission: permission, permissionsStore: permissionsStore)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }
}
