import Foundation

class TextChunkManager: ObservableObject {
    private let chunkSize = 10000 // characters per chunk
    private var fullContent: String = ""
    private var loadedChunks: [Int: String] = [:]
    private var totalChunks: Int = 0
    private var currentChunk: Int = 0
    
    @Published var currentContent: String = ""
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var currentChunkIndex: Int {
        return currentChunk
    }
    
    func loadFile(from url: URL) {
        isLoading = true
        errorMessage = nil
        loadedChunks.removeAll()
        
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                // Read the entire file
                let fullData = try Data(contentsOf: url)
                print("File size: \(fullData.count) bytes")
                
                // Try different approaches to decode
                var testContent = ""
                let encodings: [String.Encoding] = [.utf8, .utf16, .utf16LittleEndian, .utf16BigEndian, .ascii]
                
                for encoding in encodings {
                    if let content = String(data: fullData, encoding: encoding) {
                        testContent = content
                        print("Successfully decoded with \(encoding), length: \(content.count)")
                        break
                    }
                }
                
                if testContent.isEmpty {
                    // Last resort: try with replacement
                    testContent = String(data: fullData, encoding: .utf8) ?? ""
                    print("Using UTF-8 with replacement, length: \(testContent.count)")
                }
                
                // Parse and clean the full content
                let cleanedContent = self.parseAndCleanText(testContent)
                self.fullContent = cleanedContent
                
                // Calculate total chunks
                self.totalChunks = Int(ceil(Double(cleanedContent.count) / Double(self.chunkSize)))
                print("Total chunks: \(self.totalChunks)")
                
                // Load first chunk immediately
                DispatchQueue.main.async {
                    self.loadChunk(0)
                }
                
            } catch {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to open file: \(error.localizedDescription)"
                    self.isLoading = false
                }
            }
        }
    }
    
    func loadChunk(_ chunkIndex: Int) {
        guard chunkIndex >= 0, chunkIndex < totalChunks else { return }
        
        // Check if already loaded
        if let cachedContent = loadedChunks[chunkIndex] {
            DispatchQueue.main.async {
                self.currentContent = cachedContent
                self.currentChunk = chunkIndex
                self.isLoading = false
            }
            return
        }
        
        isLoading = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            // Calculate chunk boundaries
            let startIndex = chunkIndex * self.chunkSize
            let endIndex = min(startIndex + self.chunkSize, self.fullContent.count)
            
            // Extract chunk from full content
            let chunkContent = String(self.fullContent[self.fullContent.index(self.fullContent.startIndex, offsetBy: startIndex)..<self.fullContent.index(self.fullContent.startIndex, offsetBy: endIndex)])
            
            // Cache the chunk
            self.loadedChunks[chunkIndex] = chunkContent
            
            // Limit cache size
            if self.loadedChunks.count > 5 {
                let keysToRemove = self.loadedChunks.keys.sorted().dropLast(5)
                for key in keysToRemove {
                    self.loadedChunks.removeValue(forKey: key)
                }
            }
            
            DispatchQueue.main.async {
                self.currentContent = chunkContent
                self.currentChunk = chunkIndex
                self.isLoading = false
            }
        }
    }
    
    func nextChunk() {
        if currentChunk < totalChunks - 1 {
            loadChunk(currentChunk + 1)
        }
    }
    
    func previousChunk() {
        if currentChunk > 0 {
            loadChunk(currentChunk - 1)
        }
    }
    
    func getProgress() -> Double {
        guard totalChunks > 0 else { return 0.0 }
        return Double(currentChunk) / Double(totalChunks - 1)
    }
    
    func closeFile() {
        fullContent = ""
        currentContent = ""
        loadedChunks.removeAll()
    }
    
    private func parseAndCleanText(_ text: String) -> String {
        var cleanedText = text
        
        // For Chinese text, be more careful with line breaks
        cleanedText = cleanedText.replacingOccurrences(of: "\r\n", with: "\n")
        cleanedText = cleanedText.replacingOccurrences(of: "\r", with: "\n")
        
        // Remove multiple consecutive line breaks (keep max 2)
        cleanedText = cleanedText.replacingOccurrences(of: "\n\n\n+", with: "\n\n", options: .regularExpression)
        
        // Remove excessive spaces at the beginning of lines (but preserve Chinese spacing)
        cleanedText = cleanedText.replacingOccurrences(of: "^[ \t]+", with: "", options: .regularExpression, range: nil)
        
        // Remove trailing whitespace from lines
        cleanedText = cleanedText.replacingOccurrences(of: "[ \t]+$", with: "", options: .regularExpression, range: nil)
        
        // Remove excessive spaces between words (keep single space)
        cleanedText = cleanedText.replacingOccurrences(of: "[ \t]+", with: " ", options: .regularExpression)
        
        // Remove empty lines at the beginning and end
        cleanedText = cleanedText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        print("Parsed text length: \(cleanedText.count), first 50 chars: \(String(cleanedText.prefix(50)))")
        
        return cleanedText
    }
} 