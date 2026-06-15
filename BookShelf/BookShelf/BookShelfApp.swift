import SwiftUI
import AppKit

@main
struct BookShelfApp: App {
    init() {
        if let icon = Bundle.main.image(forResource: "BookShelf") {
            NSApplication.shared.applicationIconImage = icon
        }
    }

    var body: some Scene {
        WindowGroup("BookShelf") {
            ContentView()
        }
    }
}
