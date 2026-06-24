import SwiftUI

@main
struct IOSMacsApp: App {
    @StateObject private var session = EmacsSession()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(session)
                .task {
                    session.start()
                }
        }
    }
}
