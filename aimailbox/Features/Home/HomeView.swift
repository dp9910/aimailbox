import SwiftUI

// Mock Scan model for UI development
struct Scan: Identifiable {
    let id = UUID()
    let title: String
    let date: String
    let thumbnail: String // For system icon name
}

struct HomeView: View {
    
    // Mock data
    let scans: [Scan] = [
        Scan(title: "Electric Bill", date: "2025-11-20", thumbnail: "doc.text.fill"),
        Scan(title: "Credit Card Offer", date: "2025-11-20", thumbnail: "doc.richtext.fill"),
        Scan(title: "Insurance Policy", date: "2025-11-19", thumbnail: "doc.text.magnifyingglass")
    ]
    
    @State private var isScanning = false

    var body: some View {
        NavigationView {
            List(scans) { scan in
                HStack {
                    Image(systemName: scan.thumbnail)
                        .font(.title)
                        .foregroundColor(.blue)
                        .frame(width: 40)
                    VStack(alignment: .leading) {
                        Text(scan.title).font(.headline)
                        Text(scan.date).font(.subheadline).foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Inbox")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        isScanning = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .sheet(isPresented: $isScanning) {
                ScannerView()
            }
        }
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
    }
}
