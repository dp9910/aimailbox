import SwiftUI

// Extension to provide view-specific computed properties
extension Scan {
    var senderInitial: String {
        if let title = title, !title.isEmpty {
            return String(title.prefix(1)).uppercased()
        }
        return "?"
    }
    
    var senderName: String {
        // Try to extract sender from OCR text first, fallback to title, then default
        if let ocrText = ocrText, !ocrText.isEmpty {
            let lines = ocrText.components(separatedBy: .newlines)
            if let firstLine = lines.first, !firstLine.trimmingCharacters(in: .whitespaces).isEmpty {
                return firstLine.trimmingCharacters(in: .whitespaces)
            }
        }
        return title ?? "Document Scan"
    }
    
    var preview: String {
        if let ocrText = ocrText, !ocrText.isEmpty {
            let cleanText = ocrText.replacingOccurrences(of: "\n", with: " ")
            return String(cleanText.prefix(50)) + (cleanText.count > 50 ? "..." : "")
        }
        return "Document scanned"
    }
    
    var displayTime: String {
        let calendar = Calendar.current
        let now = Date()
        
        if calendar.isDateInToday(timestamp) {
            return timestamp.formatted(date: .omitted, time: .shortened)
        } else if calendar.isDateInYesterday(timestamp) {
            return "Yesterday"
        } else {
            let daysDiff = calendar.dateComponents([.day], from: timestamp, to: now).day ?? 0
            if daysDiff < 30 {
                return timestamp.formatted(.dateTime.month(.abbreviated).day())
            } else {
                return timestamp.formatted(.dateTime.month(.abbreviated).day())
            }
        }
    }
    
    var avatarColor: Color {
        let colors: [Color] = [.pink, .green, .blue, .orange, .purple, .red]
        let hash = abs(senderName.hashValue)
        return colors[hash % colors.count]
    }
}

struct HomeView: View {
    @State private var scans: [Scan] = []
    @State private var selectedFilter = "All"
    
    private let storageService = StorageService()
    
    let filters = ["All", "Unread", "Sort"]

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with filters
                HStack {
                    ForEach(filters, id: \.self) { filter in
                        Button(action: {
                            selectedFilter = filter
                        }) {
                            Text(filter)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(selectedFilter == filter ? .white : .primary)
                                .padding(.horizontal, 20)
                                .padding(.vertical, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 20)
                                        .fill(selectedFilter == filter ? .blue : Color.gray.opacity(0.2))
                                )
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Mail list
                List {
                    ForEach(scans) { scan in
                        NavigationLink(destination: ScanDetailView(scan: scan)) {
                            MailRowView(scan: scan)
                        }
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
                .listStyle(PlainListStyle())
                .refreshable {
                    loadScans()
                }
            }
            .navigationTitle("Mail")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        // Search functionality
                    }) {
                        Image(systemName: "magnifyingglass")
                            .font(.title2)
                    }
                }
            }
        }
        .onAppear {
            loadScans()
        }
    }
    
    private func loadScans() {
        scans = storageService.loadAllScans()
    }
}

struct MailRowView: View {
    let scan: Scan
    
    var body: some View {
        HStack(spacing: 12) {
            // Avatar circle
            ZStack {
                Circle()
                    .fill(scan.avatarColor)
                    .frame(width: 50, height: 50)
                
                Text(scan.senderInitial)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white)
            }
            
            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(scan.senderName)
                        .font(.system(size: 17, weight: .medium))
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    HStack(spacing: 4) {
                        Text(scan.displayTime)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                        
                        // Unread indicator
                        Circle()
                            .fill(.blue)
                            .frame(width: 8, height: 8)
                    }
                }
                
                Text(scan.preview)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 4)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
