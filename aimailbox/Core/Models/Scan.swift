import Foundation

// This model represents the comprehensive data for a single scanned document.
// It aligns with the data structure described in the implementation documents.

struct Scan: Identifiable {
    let id: UUID
    var timestamp: Date
    
    // --- Local File References ---
    var localImageFileName: String?
    var localOcrJsonFileName: String?
    var localAnalysisJsonFileName: String?
    
    // --- Core Data ---
    var ocrText: String?
    var analysis: Analysis?
    
    // --- Metadata Synced with Backend ---
    var category: String?
    var importance: String?
    var isSpam: Bool = false
    var dueDate: Date?
    var userTags: [String] = []
    
    // --- Status ---
    var needsOcr: Bool = true
    var needsAnalysis: Bool = false // Set to true by user action
    var needsSync: Bool = true

    init(id: UUID = UUID(), timestamp: Date = Date()) {
        self.id = id
        self.timestamp = timestamp
    }
}

// Represents the structured analysis from the LLM
struct Analysis: Codable {
    var category: String
    var subcategory: String?
    var importance: String
    var summary: String?
    var sender: String?
    var amounts: [Double]?
    var dates: [Date]?
    var actionItems: [String]?
}
