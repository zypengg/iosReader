import SwiftUI

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct ReaderView: View {
    let novel: Novel
    let dataManager: NovelDataManager
    
    @StateObject private var chunkManager = TextChunkManager()
    @State private var fontSize: CGFloat = 18
    @State private var showingSettings = false
    @State private var showingControls = false
    @State private var currentScrollPosition: CGFloat = 0
    @State private var scrollViewHeight: CGFloat = 0
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        ZStack {
            // Main reading content
            VStack(spacing: 0) {
                if chunkManager.isLoading {
                    VStack {
                        ProgressView("Loading...")
                            .padding()
                        Text("Reading \(novel.title)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let error = chunkManager.errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.largeTitle)
                            .foregroundColor(.red)
                        Text("Error loading file")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                        
                        Button("Try Again") {
                            chunkManager.loadFile(from: novel.fileURL)
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    // Reading content
                    ScrollViewReader { proxy in
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                Text(chunkManager.currentContent)
                                    .font(.system(size: fontSize))
                                    .lineSpacing(fontSize * 0.3)
                                    .padding(.horizontal, 20)
                                    .padding(.vertical, 16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id("content")
                            }
                            .background(
                                GeometryReader { geometry in
                                    Color.clear
                                        .preference(key: ScrollOffsetPreferenceKey.self, value: geometry.frame(in: .named("scroll")).minY)
                                }
                            )
                        }
                        .coordinateSpace(name: "scroll")
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            currentScrollPosition = value
                        }
                        .onAppear {
                            // Restore reading position
                            if novel.lastChunkIndex > 0 {
                                chunkManager.loadChunk(novel.lastChunkIndex)
                            }
                            
                            // Restore scroll position after a short delay
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                withAnimation(.easeInOut(duration: 0.5)) {
                                    proxy.scrollTo("content", anchor: .top)
                                }
                            }
                        }
                        .onChange(of: currentScrollPosition) { _ in
                            saveReadingProgress()
                        }
                        .gesture(
                            DragGesture()
                                .onEnded { value in
                                    if value.translation.width > 100 {
                                        // Swipe right - previous chunk
                                        chunkManager.previousChunk()
                                    } else if value.translation.width < -100 {
                                        // Swipe left - next chunk
                                        chunkManager.nextChunk()
                                    }
                                }
                        )
                    }
                    .background(Color(.systemBackground))
                }
            }
            .onTapGesture {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showingControls.toggle()
                }
            }
            
            // Overlay controls
            if showingControls {
                VStack {
                    // Top bar
                    HStack {
                        Button(action: { dismiss() }) {
                            HStack {
                                Image(systemName: "chevron.left")
                                Text("Library")
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial)
                            .cornerRadius(8)
                        }
                        
                        Spacer()
                        
                        Button(action: { showingSettings = true }) {
                            Image(systemName: "textformat.size")
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(.ultraThinMaterial)
                                .cornerRadius(8)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    
                    Spacer()
                    
                    // Bottom progress
                    VStack(spacing: 8) {
                        HStack(spacing: 20) {
                            Button(action: { chunkManager.previousChunk() }) {
                                Image(systemName: "chevron.left")
                                    .font(.title2)
                            }
                            .disabled(chunkManager.getProgress() <= 0)
                            
                            ProgressView(value: chunkManager.getProgress())
                                .progressViewStyle(LinearProgressViewStyle())
                                .frame(width: 150)
                            
                            Button(action: { chunkManager.nextChunk() }) {
                                Image(systemName: "chevron.right")
                                    .font(.title2)
                            }
                            .disabled(chunkManager.getProgress() >= 1.0)
                        }
                        
                        Text("\(Int(chunkManager.getProgress() * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(.ultraThinMaterial)
                    .cornerRadius(12)
                    .padding(.bottom, 20)
                }
                .transition(.opacity)
            }
        }
        .navigationBarHidden(true)
        .sheet(isPresented: $showingSettings) {
            ReadingSettingsView(fontSize: $fontSize)
        }
        .onAppear {
            chunkManager.loadFile(from: novel.fileURL)
        }
        .onDisappear {
            chunkManager.closeFile()
            saveReadingProgress()
        }
    }
    
    private func saveReadingProgress() {
        var updatedNovel = novel
        updatedNovel.lastReadPosition = Int(chunkManager.getProgress() * 1000) + Int(currentScrollPosition)
        updatedNovel.lastChunkIndex = chunkManager.currentChunkIndex
        updatedNovel.lastScrollPosition = Double(currentScrollPosition)
        dataManager.updateNovel(updatedNovel)
    }
}

struct ReadingSettingsView: View {
    @Binding var fontSize: CGFloat
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var themeManager: ThemeManager
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Font Size")
                        .font(.headline)
                    
                    HStack {
                        Button(action: { fontSize = max(12, fontSize - 2) }) {
                            Image(systemName: "minus.circle.fill")
                                .font(.title2)
                        }
                        
                        Spacer()
                        
                        Text("\(Int(fontSize))")
                            .font(.title2)
                            .fontWeight(.medium)
                        
                        Spacer()
                        
                        Button(action: { fontSize = min(32, fontSize + 2) }) {
                            Image(systemName: "plus.circle.fill")
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal)
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Theme")
                        .font(.headline)
                    
                    HStack(spacing: 12) {
                        ForEach(AppTheme.allCases, id: \.self) { theme in
                            Button(action: { themeManager.setTheme(theme) }) {
                                VStack(spacing: 8) {
                                    Image(systemName: theme.icon)
                                        .font(.title2)
                                    Text(theme.rawValue)
                                        .font(.caption)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(themeManager.currentTheme == theme ? Color.blue.opacity(0.2) : Color(.systemGray6))
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                }
                
                VStack(alignment: .leading, spacing: 16) {
                    Text("Preview")
                        .font(.headline)
                    
                    Text("This is how your text will appear with the current font size and theme. You can adjust it to your preference for comfortable reading.")
                        .font(.system(size: fontSize))
                        .lineSpacing(fontSize * 0.3)
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
                
                Spacer()
            }
            .padding()
            .navigationTitle("Reading Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    ReaderView(
        novel: Novel(title: "Sample Novel", fileURL: URL(fileURLWithPath: "/path/to/sample.txt")),
        dataManager: NovelDataManager()
    )
    .environmentObject(ThemeManager())
} 