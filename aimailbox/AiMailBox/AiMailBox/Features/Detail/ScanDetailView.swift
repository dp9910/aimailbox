import SwiftUI

struct ScanDetailView: View {
    let scan: Scan
    @State private var displayedImage: UIImage?
    
    private let storageService = StorageService()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Scanned image
                if let displayedImage = displayedImage {
                    Image(uiImage: displayedImage)
                        .resizable()
                        .scaledToFit()
                        .frame(maxHeight: 400)
                        .cornerRadius(12)
                        .padding(.horizontal)
                } else {
                    Image(systemName: "photo.fill")
                        .resizable()
                        .scaledToFit()
                        .frame(height: 400)
                        .foregroundColor(.gray.opacity(0.1))
                        .overlay(
                            Text("Loading Image...")
                                .font(.title)
                                .foregroundColor(.gray)
                        )
                        .padding(.horizontal)
                }

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
                    
                    Text(scan.ocrText ?? "No OCR text available")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
        .navigationTitle(scan.title ?? "Scan Detail")
        .onAppear {
            loadImage()
        }
    }
    
    private func loadImage() {
        guard let imageFileName = scan.localImageFileName else { return }
        displayedImage = storageService.loadImage(fileName: imageFileName)
    }
}

struct ScanDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ScanDetailView(scan: Scan())
        }
    }
}
