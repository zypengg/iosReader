import Foundation

class NovelDataManager: ObservableObject {
    @Published var novels: [Novel] = []
    
    private let novelsKey = "SavedNovels"
    
    init() {
        loadNovels()
    }
    
    func addNovel(_ novel: Novel) {
        novels.append(novel)
        saveNovels()
    }
    
    func removeNovel(_ novel: Novel) {
        novels.removeAll { $0.id == novel.id }
        saveNovels()
    }
    
    func updateNovel(_ novel: Novel) {
        if let index = novels.firstIndex(where: { $0.id == novel.id }) {
            novels[index] = novel
            saveNovels()
        }
    }
    
    private func saveNovels() {
        if let encoded = try? JSONEncoder().encode(novels) {
            // Save to both UserDefaults and a more persistent location
            UserDefaults.standard.set(encoded, forKey: novelsKey)
            
            // Also save to app's shared container for persistence across debug sessions
            if let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.iosReader.shared") {
                let backupURL = sharedContainer.appendingPathComponent("novels_backup.json")
                try? encoded.write(to: backupURL)
            }
        }
    }
    
    private func loadNovels() {
        // Try to load from UserDefaults first
        if let data = UserDefaults.standard.data(forKey: novelsKey),
           let decoded = try? JSONDecoder().decode([Novel].self, from: data) {
            novels = decoded
        } else {
            // Try to load from backup location
            if let sharedContainer = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: "group.com.iosReader.shared") {
                let backupURL = sharedContainer.appendingPathComponent("novels_backup.json")
                if let data = try? Data(contentsOf: backupURL),
                   let decoded = try? JSONDecoder().decode([Novel].self, from: data) {
                    novels = decoded
                    // Restore to UserDefaults
                    UserDefaults.standard.set(data, forKey: novelsKey)
                }
            }
        }
        
        // Filter out novels whose files no longer exist
        novels = novels.filter { novel in
            let fileExists = FileManager.default.fileExists(atPath: novel.fileURL.path)
            if !fileExists {
                print("Removing novel with missing file: \(novel.title)")
            }
            return fileExists
        }
        
        // Save the cleaned list back to storage
        saveNovels()
    }
} 