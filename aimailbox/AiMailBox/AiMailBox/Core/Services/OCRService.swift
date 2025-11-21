import Foundation
import Vision
import UIKit

class OCRService {
    
    enum OCRError: Error {
        case imageProcessingFailed
        case textRecognitionFailed
    }
    
    typealias OCRResultHandler = (Result<String, OCRError>) -> Void

    func performOCR(on image: UIImage, completion: @escaping OCRResultHandler) {
        guard let cgImage = image.cgImage else {
            completion(.failure(.imageProcessingFailed))
            return
        }

        let requestHandler = VNImageRequestHandler(cgImage: cgImage)
        let request = VNRecognizeTextRequest { (request, error) in
            if let error = error {
                print("OCR Error: \(error.localizedDescription)")
                completion(.failure(.textRecognitionFailed))
                return
            }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                completion(.success("")) // No text found is not an error
                return
            }
            
            let recognizedStrings = observations.compactMap {
                // Return the most likely candidate
                $0.topCandidates(1).first?.string
            }
            
            completion(.success(recognizedStrings.joined(separator: "\n")))
        }
        
        // To improve accuracy, you can set recognition level and language
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["en-US"]

        do {
            try requestHandler.perform([request])
        } catch {
            print("Failed to perform OCR request: \(error)")
            completion(.failure(.textRecognitionFailed))
        }
    }
}
