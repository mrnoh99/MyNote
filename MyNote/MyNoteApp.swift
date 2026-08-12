import SwiftUI
import SwiftData

@main
struct MyNoteApp: App {
    let modelContainer: ModelContainer

    init() {
        let schema = Schema([Folder.self, Notebook.self, Note.self, PDFPageAnnotation.self])
        let configuration = ModelConfiguration(
            schema: schema,
            cloudKitDatabase: .automatic
        )
        do {
            modelContainer = try ModelContainer(for: schema, configurations: [configuration])
        } catch {
            fatalError("ModelContainer 생성에 실패했습니다: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
