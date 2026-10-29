import SwiftUI

@MainActor
struct SetupPermissionStep: View {
    let permissionsStore: SystemPermissionStore

    var body: some View {
        SetupStepContent(
            stepNumber: 1,
            title: String(localized: "setup.step1.title", defaultValue: "Permissions"),
            isDone: permissionsStore.allGranted
        ) {
            VStack(spacing: 10) {
                ForEach(SystemPermission.allCases) { permission in
                    PermissionRow(permission: permission, permissionsStore: permissionsStore)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
    }
}
