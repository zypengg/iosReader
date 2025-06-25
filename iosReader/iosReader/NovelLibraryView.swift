import SwiftUI
import UniformTypeIdentifiers

struct NovelLibraryView: View {
    @StateObject private var dataManager = NovelDataManager()
    @State private var showingImporter = false
    @State private var selectedNovel: Novel?
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationStack {
            Group {
                if dataManager.novels.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No Novels Yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Tap the + button to import your first .txt file")
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    List {
                        ForEach(dataManager.novels) { novel in
                            NovelRowView(novel: novel) {
                                selectedNovel = novel
                            }
                        }
                        .onDelete(perform: deleteNovels)
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(action: { toggleTheme() }) {
                        Image(systemName: themeManager.currentTheme.icon)
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingImporter = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showingImporter,
                allowedContentTypes: [UTType.plainText],
                allowsMultipleSelection: true
            ) { result in
                switch result {
                case .success(let urls):
                    for url in urls {
                        importFile(from: url)
                    }
                case .failure(let error):
                    print("Error importing files: \(error)")
                }
            }
            .sheet(item: $selectedNovel) { novel in
                ReaderView(novel: novel, dataManager: dataManager)
            }
        }
    }
    
    private func toggleTheme() {
        switch themeManager.currentTheme {
        case .light:
            themeManager.setTheme(.dark)
        case .dark:
            themeManager.setTheme(.system)
        case .system:
            themeManager.setTheme(.light)
        }
    }
    
    private func importFile(from url: URL) {
        // Start accessing the security-scoped resource
        guard url.startAccessingSecurityScopedResource() else { 
            print("Failed to access security-scoped resource")
            return 
        }
        
        defer { url.stopAccessingSecurityScopedResource() }
        
        // Copy file to app's documents directory
        guard let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            print("Failed to get documents directory")
            return
        }
        
        let destinationURL = documentsPath.appendingPathComponent(url.lastPathComponent)
        
        do {
            // Remove existing file if it exists
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                try FileManager.default.removeItem(at: destinationURL)
            }
            
            // Copy the file
            try FileManager.default.copyItem(at: url, to: destinationURL)
            
            // Verify the file was copied successfully
            guard FileManager.default.fileExists(atPath: destinationURL.path) else {
                print("File was not copied successfully")
                return
            }
            
            // Verify we can read the file
            let testData = try Data(contentsOf: destinationURL)
            guard testData.count > 0 else {
                print("File is empty")
                try? FileManager.default.removeItem(at: destinationURL)
                return
            }
            
            // Create novel object
            let novel = Novel(title: url.deletingPathExtension().lastPathComponent, fileURL: destinationURL)
            dataManager.addNovel(novel)
            
            print("Successfully imported: \(novel.title) at \(destinationURL.path)")
            
        } catch {
            print("Error copying file: \(error)")
            // Clean up failed copy
            try? FileManager.default.removeItem(at: destinationURL)
        }
    }
    
    private func deleteNovels(offsets: IndexSet) {
        for index in offsets {
            let novel = dataManager.novels[index]
            // Remove the file from documents directory
            try? FileManager.default.removeItem(at: novel.fileURL)
            dataManager.removeNovel(novel)
        }
    }
}

struct NovelRowView: View {
    let novel: Novel
    let onTap: () -> Void
    
    private var progressPercentage: Double {
        // Simple progress calculation - could be enhanced
        if novel.lastReadPosition > 0 {
            return min(1.0, Double(novel.lastReadPosition) / 1000.0) // Arbitrary divisor for demo
        }
        return 0.0
    }
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Book icon
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 50, height: 60)
                    
                    Image(systemName: "book.closed.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(novel.title)
                        .font(.headline)
                        .foregroundColor(.primary)
                        .lineLimit(2)
                    
                    if progressPercentage > 0 {
                        HStack {
                            ProgressView(value: progressPercentage)
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(width: 100)
                            
                            Text("\(Int(progressPercentage * 100))%")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        Text("Not started")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NovelLibraryView()
        .environmentObject(ThemeManager())
} 