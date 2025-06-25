import Foundation

struct Novel: Identifiable, Codable {
    let id: UUID
    var title: String
    var fileURL: URL
    var lastReadPosition: Int
    var lastChunkIndex: Int
    var lastScrollPosition: Double
    
    init(title: String, fileURL: URL, lastReadPosition: Int = 0, lastChunkIndex: Int = 0, lastScrollPosition: Double = 0.0) {
        self.id = UUID()
        self.title = title
        self.fileURL = fileURL
        self.lastReadPosition = lastReadPosition
        self.lastChunkIndex = lastChunkIndex
        self.lastScrollPosition = lastScrollPosition
    }
} 