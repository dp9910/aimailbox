import Foundation
import UIKit

class StorageService {
    
    enum Directory: String {
        case scans = "Scans"
        case ocr = "OCR"
        case analysis = "Analysis"
    }

    // MARK: - Public Methods

    func saveImage(_ image: UIImage, with id: UUID) -> String? {
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        let fileName = "scan_\(id.uuidString).jpg"
        return save(data: data, to: .scans, with: fileName)
    }
    
    func saveOcrResult(_ ocrJson: Data, for scanId: UUID) -> String? {
        let fileName = "scan_\(scanId.uuidString)_ocr.json"
        return save(data: ocrJson, to: .ocr, with: fileName)
    }
    
    func saveAnalysisResult(_ analysisJson: Data, for scanId: UUID) -> String? {
        let fileName = "scan_\(scanId.uuidString)_analysis.json"
        return save(data: analysisJson, to: .analysis, with: fileName)
    }
    
    func getUrl(for directory: Directory) -> URL? {
        guard let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return nil
        }
        let directoryUrl = documentsDirectory.appendingPathComponent(directory.rawValue)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: directoryUrl.path) {
            do {
                try FileManager.default.createDirectory(at: directoryUrl, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Error creating directory \(directory.rawValue): \(error)")
                return nil
            }
        }
        return directoryUrl
    }

    // MARK: - Private Helper

    private func save(data: Data, to directory: Directory, with fileName: String) -> String? {
        guard let directoryUrl = getUrl(for: directory) else { return nil }
        let fileUrl = directoryUrl.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileUrl)
            return fileName
        } catch {
            print("Error saving file \(fileName): \(error)")
            return nil
        }
    }
}
