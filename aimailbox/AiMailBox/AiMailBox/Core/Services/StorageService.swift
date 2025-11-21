import Foundation
import UIKit

class StorageService {
    
    enum Directory: String {
        case scans = "Scans"
        case ocr = "OCR"
        case analysis = "Analysis"
        case metadata = "Metadata"
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
    
    func saveScanMetadata(_ scan: Scan) -> Bool {
        let fileName = "scan_\(scan.id.uuidString)_metadata.json"
        do {
            let data = try JSONEncoder().encode(scan)
            return save(data: data, to: .metadata, with: fileName) != nil
        } catch {
            print("Error encoding scan metadata: \(error)")
            return false
        }
    }
    
    func loadAllScans() -> [Scan] {
        guard let metadataUrl = getUrl(for: .metadata) else { return [] }
        
        do {
            let files = try FileManager.default.contentsOfDirectory(at: metadataUrl, includingPropertiesForKeys: nil)
            let metadataFiles = files.filter { $0.pathExtension == "json" && $0.lastPathComponent.contains("metadata") }
            
            var scans: [Scan] = []
            for file in metadataFiles {
                do {
                    let data = try Data(contentsOf: file)
                    let scan = try JSONDecoder().decode(Scan.self, from: data)
                    scans.append(scan)
                } catch {
                    print("Error loading scan from \(file.lastPathComponent): \(error)")
                }
            }
            
            return scans.sorted { $0.timestamp > $1.timestamp }
        } catch {
            print("Error loading scans directory: \(error)")
            return []
        }
    }
    
    func loadImage(fileName: String) -> UIImage? {
        guard let scansUrl = getUrl(for: .scans) else { return nil }
        
        let fullPath = scansUrl.appendingPathComponent(fileName)
        
        guard FileManager.default.fileExists(atPath: fullPath.path) else { return nil }
        
        do {
            let data = try Data(contentsOf: fullPath)
            return UIImage(data: data)
        } catch {
            print("Error loading image data: \(error)")
            return nil
        }
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
