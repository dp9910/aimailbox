import SwiftUI

struct ScanDetailView: View {
    // This view will be passed a Scan object
    // For now, we use mock data.
    let scan: Scan = Scan(title: "Electric Bill", date: "2025-11-20", thumbnail: "doc.text.fill")

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Placeholder for the scanned image
                Image(systemName: "photo.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 400)
                    .foregroundColor(.gray.opacity(0.1))
                    .overlay(
                        Text("Scanned Image")
                            .font(.title)
                            .foregroundColor(.gray)
                    )
                    .padding(.horizontal)

                // AI Analysis Opt-In
                VStack {
                    Text("Want AI to analyze this?")
                        .font(.headline)
                        .padding(.bottom, 2)
                    Text("AI will categorize, extract due dates, and create reminders.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.bottom, 10)
                    
                    Button(action: {
                        // TODO: Trigger AI Analysis
                    }) {
                        Text("✨ Analyze with AI")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                    }
                    Text("25/25 credits remaining")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal)


                Divider()

                // Extracted Text Section
                VStack(alignment: .leading) {
                    Text("Extracted Text")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("""
                        ABC Power Company
                        123 Main St
                        Electric Bill
                        Due: December 15, 2025
                        Amount: $127.43...
                        (Full OCR text would appear here)
                        """)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(scan.title)
    }
}

struct ScanDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ScanDetailView()
        }
    }
}
