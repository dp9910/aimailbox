import SwiftUI
import VisionKit

struct ScannerView: UIViewControllerRepresentable {
    @Environment(\.presentationMode) var presentationMode
    let onScanComplete: (() -> Void)?
    
    init(onScanComplete: (() -> Void)? = nil) {
        self.onScanComplete = onScanComplete
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let documentViewController = VNDocumentCameraViewController()
        documentViewController.delegate = context.coordinator
        return documentViewController
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {
        // No update needed
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        let parent: ScannerView

        init(_ parent: ScannerView) {
            self.parent = parent
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            // Process the first scanned page
            guard scan.pageCount > 0 else {
                parent.presentationMode.wrappedValue.dismiss()
                return
            }
            
            // 1. Get the image from the scan
            let scannedImage = scan.imageOfPage(at: 0)
            
            // 2. Use ScannerService to handle the complete workflow
            let scannerService = ScannerService()
            scannerService.handleScan(documentScan: scan) { result in
                DispatchQueue.main.async {
                    switch result {
                    case .success(_):
                        // Notify parent view to refresh
                        self.parent.onScanComplete?()
                        
                    case .failure(let error):
                        print("Failed to process scan: \(error)")
                        // TODO: Show error to user
                    }
                    self.parent.presentationMode.wrappedValue.dismiss()
                }
            }
        }
        
        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            parent.presentationMode.wrappedValue.dismiss()
        }
        
        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            print("Scanner failed with error: \(error.localizedDescription)")
            // TODO: Show an error to the user
            parent.presentationMode.wrappedValue.dismiss()
        }
    }
}
