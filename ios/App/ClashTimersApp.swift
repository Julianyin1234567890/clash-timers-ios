import SwiftUI

@main
@MainActor
struct ClashTimersApp: App {
    @State private var model = AppModel()
    var body: some Scene {
        WindowGroup {
            DashboardView(model: model)
                .tint(.orange)
        }
    }
}
