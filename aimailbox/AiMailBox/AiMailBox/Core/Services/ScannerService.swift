import Foundation
import VisionKit
import UIKit

class ScannerService {
    
    private let storageService = StorageService()
    private let ocrService = OCRService()
    
    enum ScanError: Error {
        case imageConversionFailed
        case ocrFailed(Error)
        case storageFailed
    }
    
    func handleScan(documentScan: VNDocumentCameraScan, completion: @escaping (Result<Scan, ScanError>) -> Void) {
        guard documentScan.pageCount > 0 else {
            // No pages scanned, not necessarily an error, but nothing to process.
            // Depending on desired behavior, this could be handled differently.
            return
        }
        
        // For simplicity, we'll process the first page.
        // In a real app, you might loop through all pages.
        let image = documentScan.imageOfPage(at: 0)
        
        // 1. Create a new Scan model
        var newScan = Scan()
        
        // 2. Save the image locally
        guard let imageName = storageService.saveImage(image, with: newScan.id) else {
            completion(.failure(.storageFailed))
            return
        }
        newScan.localImageFileName = imageName
        
        // 3. Perform OCR
        ocrService.performOCR(on: image) { ocrResult in
            switch ocrResult {
            case .success(let text):
                newScan.ocrText = text
                newScan.needsOcr = false
                
                // 4. Save OCR result to a JSON file (as an example)
                let ocrData = try? JSONEncoder().encode(["text": text])
                if let ocrData = ocrData {
                    newScan.localOcrJsonFileName = self.storageService.saveOcrResult(ocrData, for: newScan.id)
                }
                
                // 5. Save scan metadata
                _ = self.storageService.saveScanMetadata(newScan)
                
                // 6. Return the completed Scan object
                completion(.success(newScan))
                
            case .failure(let error):
                completion(.failure(ScanError.ocrFailed(error)))
            }
        }
    }
}
