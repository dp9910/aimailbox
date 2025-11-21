# Mail Scanner iOS App - Implementation Document

## Project Overview

**App Name:** MailScan AI (placeholder)  
**Platform:** iOS 16.0+  
**Architecture:** Local-first with cloud metadata sync  
**Core Value:** Scan, organize, and intelligently manage household mail with AI

---

## 1. Core Concept

### The Problem
- US households receive ~10 pieces of mail daily (70% junk, 20% ads, 10% important)
- Important documents get buried in mailbox cabinets
- Manual organization is time-consuming
- Missing payment deadlines and important dates
- Physical clutter accumulates

### The Solution
A mobile-first app that:
1. Scans physical mail using iPhone camera
2. Extracts text using on-device OCR (free)
3. Analyzes content with AI/LLM
4. Organizes, categorizes, and filters spam
5. Extracts due dates and creates reminders
6. Stores locally with cloud metadata backup

### **🔑 KEY ARCHITECTURE PRINCIPLE: Backend-Driven Features**

**Critical Design Decision:** The app is intentionally designed as a "thin client" where the iOS app is primarily a UI layer, while ALL business logic, AI processing, categorization rules, and feature logic lives in the backend.

**Why This Matters:**
- ✅ **Add features instantly** - No waiting for App Store review (1-7 days)
- ✅ **A/B test anything** - Test new features with select users
- ✅ **Fix bugs immediately** - Backend fixes deploy in seconds
- ✅ **Iterate rapidly** - Change categorization rules, prompts, logic without app updates
- ✅ **Personalize per user** - Different features for different users/plans
- ✅ **Roll out gradually** - Feature flags control who sees what
- ✅ **Update AI prompts** - Improve accuracy without app submission

**Examples of Backend-Controlled Features:**
- Category definitions and rules
- Spam detection thresholds
- LLM prompts and analysis logic
- UI text and messaging
- Feature availability per plan
- Auto-cleanup policies
- Reminder timing logic
- New document types support

---

## 2. Technical Architecture

### 2.1 Architecture Diagram (Privacy-First with User Opt-In)

```
┌─────────────────────────────────────────────────────┐
│  iOS APP (Privacy-First, User-Controlled)          │
│  ┌─────────────────────────────────────────────┐   │
│  │  1. Document Scanner (VisionKit)            │   │
│  │     → Clean, perspective-corrected scans    │   │
│  │     → Save locally IMMEDIATELY              │   │
│  └─────────────────────────────────────────────┘   │
│                      ↓                              │
│  ┌─────────────────────────────────────────────┐   │
│  │  2. Local Storage (PRIMARY)                 │   │
│  │     /Documents/Scans/                       │   │
│  │       scan_timestamp_uuid.jpg (image)       │   │
│  │     /Documents/OCR/                         │   │
│  │       scan_uuid_ocr.json (text)             │   │
│  │     /Documents/Analysis/                    │   │
│  │       scan_uuid_analysis.json (AI results)  │   │
│  └─────────────────────────────────────────────┘   │
│                      ↓                              │
│  ┌─────────────────────────────────────────────┐   │
│  │  3. Extract Metadata → Send to Backend      │   │
│  │     POST /api/scans/create                  │   │
│  │     {                                       │   │
│  │       scanId, localFileName, timestamp,     │   │
│  │       imageSize, deviceId                   │   │
│  │     }                                       │   │
│  │     ⚠️ NEVER sends image or full text!      │   │
│  └─────────────────────────────────────────────┘   │
│                      ↓                              │
│  ┌─────────────────────────────────────────────┐   │
│  │  4. Run iOS OCR (On-Device, FREE)          │   │
│  │     → Vision Framework extracts text        │   │
│  │     → Save as JSON locally                  │   │
│  │     → Cost: $0 (on-device)                  │   │
│  │     → Time: 1-2 seconds                     │   │
│  └─────────────────────────────────────────────┘   │
│                      ↓                              │
│  ┌─────────────────────────────────────────────┐   │
│  │  5. Save OCR Metadata Only                  │   │
│  │     PATCH /api/scans/{scanId}               │   │
│  │     {                                       │   │
│  │       ocrStatus: "completed",               │   │
│  │       ocrFileName: "scan_uuid_ocr.json",    │   │
│  │       wordCount: 287,                       │   │
│  │       confidence: 0.94                      │   │
│  │     }                                       │   │
│  │     ⚠️ Text stays on device!                 │   │
│  └─────────────────────────────────────────────┘   │
│                      ↓                              │
│  ┌─────────────────────────────────────────────┐   │
│  │  6. USER DECIDES: "Analyze with AI?"        │   │
│  │     ┌─────────────────────────────────┐     │   │
│  │     │  Preview:                       │     │   │
│  │     │  "ABC Power Company             │     │   │
│  │     │   Electric Bill                 │     │   │
│  │     │   Amount: $127.43"              │     │   │
│  │     │                                 │     │   │
│  │     │  [✨ Analyze with AI]  [Skip]   │     │   │
│  │     │                                 │     │   │
│  │     │  Credits: 22/25 remaining       │     │   │
│  │     └─────────────────────────────────┘     │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘
         ↓                           ↓
    [Skip]                    [Analyze with AI]
         ↓                           ↓
┌─────────────────┐   ┌─────────────────────────────┐
│ 7a. NO LLM CALL │   │ 7b. SEND TEXT TO BACKEND    │
│                 │   │                             │
│ • View locally  │   │  POST /api/analyze          │
│ • Manual tag    │   │  {                          │
│ • Save credit   │   │    scanId: "scan_abc123",   │
│ • Cost: $0      │   │    text: "extracted text",  │
│                 │   │    userId: "user_123"       │
│ • "You saved    │   │  }                          │
│   1 credit!"    │   │                             │
└─────────────────┘   │  ⚠️ Only TEXT sent, not     │
                      │     image!                  │
                      │                             │
                      │  Cost: ~$0.003              │
                      └─────────────────────────────┘
                                  ↓
            ┌─────────────────────────────────────────┐
            │  🔥 BACKEND (Smart Processing)          │
            │                                         │
            │  8. LLM Analysis Engine                 │
            │     → Receives TEXT only                │
            │     → Categorize with AI                │
            │     → Extract due dates                 │
            │     → Generate action items             │
            │     → Return structured JSON            │
            │                                         │
            │  9. Business Rules Engine               │
            │     → Apply spam detection              │
            │     → Determine reminder timing         │
            │     → Generate iOS integration commands │
            │                                         │
            │  10. Configuration Service              │
            │     → Feature flags                     │
            │     → Category definitions              │
            │     → UI strings                        │
            └─────────────────────────────────────────┘
                                  ↓
            ┌─────────────────────────────────────────┐
            │  11. Returns Analysis to iOS            │
            │      {                                  │
            │        category: "bill",                │
            │        importance: "high",              │
            │        dueDate: "2024-12-15",           │
            │        actionItems: [...],              │
            │        iosActions: [                    │
            │          { type: "calendar_event" },    │
            │          { type: "reminder" }           │
            │        ]                                │
            │      }                                  │
            └─────────────────────────────────────────┘
                                  ↓
            ┌─────────────────────────────────────────┐
            │  12. iOS Saves Analysis Locally         │
            │      → Save as JSON on device           │
            │      → Update metadata in database      │
            │      → Create calendar events           │
            │      → Create reminders                 │
            │      → Show success to user             │
            └─────────────────────────────────────────┘

┌─────────────────────────────────────────────────────┐
│  DATABASE (Metadata ONLY - No Content)              │
│  ┌─────────────────────────────────────────────┐   │
│  │  What we STORE:                             │   │
│  │  ✓ File names (not files)                   │   │
│  │  ✓ Scan timestamps                          │   │
│  │  ✓ Categories (bill/spam/important)         │   │
│  │  ✓ Due dates extracted                      │   │
│  │  ✓ User tags & preferences                  │   │
│  │  ✓ iOS integration IDs (calendar/reminder)  │   │
│  └─────────────────────────────────────────────┘   │
│  ┌─────────────────────────────────────────────┐   │
│  │  What we NEVER STORE:                       │   │
│  │  ✗ Images                                   │   │
│  │  ✗ Full OCR text                            │   │
│  │  ✗ Personal information from documents      │   │
│  │  ✗ Account numbers, SSNs, addresses         │   │
│  └─────────────────────────────────────────────┘   │
└─────────────────────────────────────────────────────┘

🔒 PRIVACY PRINCIPLE: 
   1. Images NEVER leave device
   2. OCR text NEVER stored in database
   3. Analysis saved locally, not remotely
   4. Only metadata (categories, dates) synced
   5. User has complete control
   
💰 COST OPTIMIZATION:
   1. No image storage costs ($0)
   2. No text storage costs ($0)
   3. LLM only when user opts in
   4. 70% cost reduction vs traditional approach
   
🎯 USER CONTROL:
   1. User decides what gets analyzed
   2. Can skip junk mail (saves credits)
   3. Can analyze later (text is local)
   4. Can delete anytime (their device)
```

### 2.2 Data Flow (Privacy-First with User Opt-In)

```
1. USER SCANS MAIL
   ↓
2. VisionKit Document Scanner
   - Auto-detect edges
   - Perspective correction
   - Shadow removal
   ↓
3. Save Image Locally IMMEDIATELY
   - Filename: scan_{timestamp}_{uuid}.jpg
   - Location: /Documents/Scans/
   - Compression: 70-80% quality
   - Size: ~400-500 KB per image
   ↓
4. Extract Image Metadata
   - File size, timestamp, device ID
   - Resolution, format
   ↓
5. Send Metadata to Backend (NOT image!)
   - POST /api/scans/create
   - Payload: {
       scanId: "scan_abc123",
       localFileName: "scan_1700492400_abc.jpg",
       timestamp: "2024-11-20T14:30:00Z",
       imageSize: 450000,
       deviceId: "iPhone-14-Pro"
     }
   - Cost: ~$0.00001
   ↓
6. Run On-Device OCR (Vision Framework)
   - Extract all text
   - Calculate confidence score
   - Detect language
   - Time: ~1-2 seconds
   - Cost: $0 (on-device)
   ↓
7. Save OCR Result Locally as JSON
   - Filename: scan_{scanId}_ocr.json
   - Location: /Documents/OCR/
   - Content: {
       scanId: "scan_abc123",
       extractedText: "Full text here...",
       confidence: 0.94,
       language: "en",
       wordCount: 287,
       extractedAt: "2024-11-20T14:30:05Z"
     }
   - Size: ~2-5 KB
   ↓
8. Send OCR Metadata to Backend (NOT text!)
   - PATCH /api/scans/{scanId}
   - Payload: {
       ocrStatus: "completed",
       ocrFileName: "scan_abc123_ocr.json",
       ocrConfidence: 0.94,
       wordCount: 287,
       language: "en",
       hasLocalOcr: true
     }
   - Cost: ~$0.00001
   ↓
9. Show User Preview with Opt-In Prompt
   - Display: Image thumbnail + text preview
   - Show: "Analyze with AI?" dialog
   - Options: [Analyze with AI] [Skip] [Mark as Spam]
   - Display: Credits remaining (e.g., "22/25")
   ↓
        ┌──────────┴──────────┐
        │                     │
   [Skip/Spam]          [Analyze with AI]
        │                     │
        ↓                     ↓
   ┌─────────────┐   ┌─────────────────────┐
   │ 10a. SKIP   │   │ 10b. SEND TO LLM    │
   │             │   │                     │
   │ • Save      │   │ POST /api/analyze   │
   │   category  │   │ {                   │
   │   locally   │   │   scanId,           │
   │ • Manual    │   │   text: "...",      │
   │   tag       │   │   userId            │
   │ • Show:     │   │ }                   │
   │   "Saved    │   │                     │
   │   1 credit!"│   │ ⚠️ ONLY TEXT sent   │
   │             │   │                     │
   │ Cost: $0    │   │ Time: ~3 seconds    │
   └─────────────┘   │ Cost: ~$0.003       │
                     └─────────────────────┘
                              ↓
                     ┌─────────────────────┐
                     │ 11. LLM PROCESSES   │
                     │                     │
                     │ Backend:            │
                     │ • Load prompt       │
                     │ • Call Claude API   │
                     │ • Parse response    │
                     │ • Apply rules       │
                     │ • Generate actions  │
                     └─────────────────────┘
                              ↓
                     ┌─────────────────────┐
                     │ 12. RETURN ANALYSIS │
                     │                     │
                     │ Response:           │
                     │ {                   │
                     │   category: "bill", │
                     │   importance: "high"│
                     │   dueDate: "2024-..." │
                     │   actionItems: [...] │
                     │   iosActions: [     │
                     │     {type: "cal"}   │
                     │   ]                 │
                     │ }                   │
                     └─────────────────────┘
                              ↓
                     ┌─────────────────────┐
                     │ 13. iOS RECEIVES    │
                     │                     │
                     │ • Save analysis     │
                     │   as JSON locally   │
                     │ • Update metadata   │
                     │   in database       │
                     └─────────────────────┘
                              ↓
                     ┌─────────────────────┐
                     │ 14. SAVE LOCALLY    │
                     │                     │
                     │ File: scan_abc123_  │
                     │       analysis.json │
                     │ Location: /Analysis/│
                     │ Size: ~1-2 KB       │
                     └─────────────────────┘
                              ↓
                     ┌─────────────────────┐
                     │ 15. UPDATE DATABASE │
                     │     (Metadata Only) │
                     │                     │
                     │ PATCH /api/scans/   │
                     │ {scanId}            │
                     │ {                   │
                     │   llmAnalyzed: true │
                     │   category: "bill"  │
                     │   importance: "high"│
                     │   dueDate: "..."    │
                     │   hasLocalAnalysis: │
                     │     true            │
                     │ }                   │
                     │                     │
                     │ Cost: ~$0.00001     │
                     └─────────────────────┘
                              ↓
                     ┌─────────────────────┐
                     │ 16. iOS INTEGRATIONS│
                     │                     │
                     │ Based on iosActions:│
                     │ • Create calendar   │
                     │   event (EventKit)  │
                     │ • Create reminder   │
                     │ • Schedule notif.   │
                     │                     │
                     │ Save IDs in DB      │
                     └─────────────────────┘
                              ↓
                     ┌─────────────────────┐
                     │ 17. SHOW SUCCESS    │
                     │                     │
                     │ "✓ Bill organized   │
                     │  ✓ Due: Dec 15      │
                     │  ✓ Reminder set     │
                     │  ✓ Calendar event"  │
                     │                     │
                     │ Credits: 21/25      │
                     └─────────────────────┘
```

### **Key Privacy & Cost Principles:**

**What STAYS on Device:**
1. ✅ Images (100% local)
2. ✅ Full OCR text (100% local)
3. ✅ Complete AI analysis (100% local)
4. ✅ User has full control

**What Goes to Backend:**
1. ✅ Metadata only (file names, timestamps)
2. ✅ Extracted text ONLY when user opts in
3. ✅ Minimal data for search (categories, dates)
4. ✅ No personal information

**Cost Savings:**
- Free tier user skips 10 junk scans: **Saves $0.03**
- Free tier user analyzes 25 important scans: **Costs $0.075**
- **Total monthly cost per free user: $0.075** (vs $0.33 old approach)
- **70% cost reduction!**

---

## 3. Backend-Driven Feature System

### 3.1 Philosophy: "Smart Backend, Dumb Client"

**The iOS app should be as "dumb" as possible, with all intelligence in the backend.**

This approach enables:
- 🚀 **Instant feature rollout** - No App Store review delays
- 🔬 **A/B testing** - Test features with 10% of users
- 🐛 **Instant bug fixes** - Fix logic errors in minutes
- 🎯 **Personalization** - Different users see different features
- 📊 **Data-driven decisions** - Change based on analytics
- 💰 **Revenue optimization** - Adjust paywalls without updates

### 3.2 Feature Flag System

```javascript
// Backend: Feature flags stored in database
featureFlags: {
  // Global flags
  "spam_detection_v2": {
    enabled: true,
    rolloutPercentage: 100,
    description: "New AI spam detection model"
  },
  
  "smart_reminders": {
    enabled: true,
    rolloutPercentage: 50,  // A/B test with 50% of users
    description: "Intelligent reminder timing"
  },
  
  "batch_scanning": {
    enabled: false,  // Coming soon
    rolloutPercentage: 0,
    allowedUsers: ["beta_tester_123", "beta_tester_456"]
  },
  
  // Per-plan flags
  "cloud_backup": {
    enabled: true,
    requiredPlan: "premium",
    description: "Backup important docs to cloud"
  },
  
  "export_to_quickbooks": {
    enabled: true,
    requiredPlan: "business",
    description: "QuickBooks integration"
  }
}

// iOS app fetches on launch
GET /api/config/features
Response: {
  "features": {
    "spam_detection_v2": true,
    "smart_reminders": true,  // User is in 50% group
    "batch_scanning": false,
    "cloud_backup": true,  // User has premium
    "export_to_quickbooks": false  // User doesn't have business plan
  }
}
```

**iOS Implementation:**
```swift
class FeatureManager: ObservableObject {
    @Published var features: [String: Bool] = [:]
    
    func fetchFeatures() async {
        let config = try? await api.getConfig()
        self.features = config?.features ?? [:]
    }
    
    func isEnabled(_ feature: String) -> Bool {
        return features[feature] ?? false
    }
}

// In UI
if featureManager.isEnabled("batch_scanning") {
    Button("Batch Scan") { /* ... */ }
}
```

### 3.3 Dynamic Categories

**Categories defined entirely in backend, not hardcoded in app:**

```javascript
// Backend: categories collection
categories: {
  "bill": {
    id: "bill",
    name: "Bills",  // Can change anytime
    icon: "doc.text.fill",
    color: "#FF6B6B",
    priority: 1,
    
    // Detection rules (backend-controlled)
    detectionRules: {
      keywords: ["due", "payment", "bill", "invoice", "balance"],
      senderPatterns: [".*electric.*", ".*utility.*", ".*insurance.*"],
      requiresAmount: true,
      requiresDueDate: true,
      minConfidence: 0.7
    },
    
    // Behavior rules
    behavior: {
      defaultRetentionYears: 7,
      autoCreateCalendarEvent: true,
      reminderDaysBefore: 3,
      importanceScore: 9  // 1-10
    },
    
    // Subcategories (can add new ones without app update)
    subcategories: [
      {
        id: "utility",
        name: "Utilities",
        keywords: ["electric", "gas", "water", "internet"]
      },
      {
        id: "insurance",
        name: "Insurance",
        keywords: ["insurance", "premium", "policy"]
      }
      // Add more subcategories anytime!
    ]
  },
  
  // Can add entirely new categories without app update
  "tax_document": {
    id: "tax_document",
    name: "Tax Documents",  // NEW category added Feb 2025
    icon: "doc.text.magnifyingglass",
    color: "#9B59B6",
    priority: 10,
    detectionRules: {
      keywords: ["W-2", "1099", "tax", "IRS", "form"],
      requiresYear: true,
      minConfidence: 0.9
    },
    behavior: {
      defaultRetentionYears: null,  // Keep forever
      autoCreateCalendarEvent: false,
      reminderDaysBefore: null,
      importanceScore: 10
    }
  }
}

// iOS fetches categories on app launch
GET /api/config/categories
Response: {
  "categories": [ /* all categories */ ],
  "version": "2.1.0",  // Track category schema version
  "lastUpdated": "2024-11-20T10:00:00Z"
}
```

**iOS just displays whatever backend returns:**
```swift
struct CategoryFilterView: View {
    @State private var categories: [Category] = []
    
    var body: some View {
        ScrollView(.horizontal) {
            HStack {
                ForEach(categories) { category in
                    CategoryChip(
                        name: category.name,  // From backend
                        icon: category.icon,  // From backend
                        color: category.color  // From backend
                    )
                }
            }
        }
        .task {
            categories = await api.fetchCategories()
        }
    }
}
```

### 3.4 Backend-Controlled LLM Prompts

**Store prompts in database, not in app code:**

```javascript
// Backend: llm_prompts collection
llmPrompts: {
  "document_analysis_v3": {
    version: "3.0",
    active: true,
    prompt: `You are an AI assistant that analyzes scanned mail...
    
[Full prompt here - can edit anytime]

IMPORTANT: Respond with JSON in this exact format:
{JSON schema}

Current date: {{CURRENT_DATE}}
User timezone: {{USER_TIMEZONE}}
User preferences: {{USER_PREFERENCES}}
`,
    
    // Metadata
    createdAt: "2024-11-20T10:00:00Z",
    createdBy: "admin@mailscan.com",
    testResults: {
      accuracy: 0.94,
      avgTokens: 1847,
      avgLatency: 2.3  // seconds
    },
    
    // A/B testing
    rolloutPercentage: 100,
    
    // Can have multiple prompt versions simultaneously
    previousVersions: ["2.5", "2.4", "2.3"]
  },
  
  // Specialized prompts for different doc types
  "medical_bill_analysis": {
    version: "1.2",
    active: true,
    appliesTo: ["medical", "insurance"],
    prompt: `Specialized prompt for medical documents...`
  }
}

// Backend dynamically selects prompt
function getPromptForDocument(docType, userId) {
  // Check if user is in A/B test
  if (isInExperiment(userId, "new_prompt_test")) {
    return llmPrompts["document_analysis_v4"];  // Testing new version
  }
  
  // Check for specialized prompt
  if (docType === "medical") {
    return llmPrompts["medical_bill_analysis"];
  }
  
  // Default prompt
  return llmPrompts["document_analysis_v3"];
}
```

**Benefits:**
- Change prompts instantly (no app update)
- A/B test different prompts
- Roll back if prompt performs poorly
- Specialized prompts per document type
- Track prompt performance over time

### 3.5 Dynamic UI Text & Messaging

**All user-facing text stored in backend:**

```javascript
// Backend: ui_strings collection
uiStrings: {
  "en": {  // Language
    "home_empty_state": {
      title: "No mail scanned yet",
      message: "Tap the + button to scan your first document",
      version: "1.0"
    },
    
    "upgrade_prompt_paywall": {
      title: "Upgrade to Premium",
      message: "Scan unlimited documents and unlock smart features",
      ctaButton: "Try Premium Free for 7 Days",
      version: "2.1"  // Can A/B test different messages
    },
    
    "scan_processing": {
      title: "Analyzing your mail...",
      steps: [
        "Extracting text...",
        "Identifying document type...",
        "Finding due dates...",
        "Creating reminders..."
      ],
      version: "1.0"
    }
  },
  
  // Can add new languages without app update
  "es": {
    "home_empty_state": {
      title: "Aún no hay correo escaneado",
      message: "Toca el botón + para escanear tu primer documento",
      version: "1.0"
    }
  }
}

// iOS fetches on launch and caches
GET /api/config/strings?locale=en
Response: {
  "strings": { /* all UI strings */ },
  "version": "1.2.0"
}
```

### 3.6 Business Rules Engine

**All business logic rules stored in backend:**

```javascript
// Backend: business_rules collection
businessRules: {
  "spam_detection": {
    version: "2.0",
    rules: [
      {
        condition: "contains_keywords",
        keywords: ["limited time offer", "act now", "urgent"],
        weight: 0.3
      },
      {
        condition: "no_amount_or_date",
        weight: 0.4
      },
      {
        condition: "generic_sender",
        weight: 0.2
      }
    ],
    threshold: 0.7,  // Adjustable threshold
    
    // Actions to take
    actions: {
      autoDelete: false,  // Can enable later
      autoArchive: true,
      notifyUser: false,
      retentionDays: 7
    }
  },
  
  "reminder_timing": {
    version: "1.5",
    rules: [
      {
        category: "bill",
        importanceHigh: {
          reminderDaysBefore: [7, 3, 1],  // Multiple reminders
          reminderTime: "09:00"
        },
        importanceMedium: {
          reminderDaysBefore: [3, 1],
          reminderTime: "09:00"
        }
      },
      {
        category: "appointment",
        reminderDaysBefore: [1],
        reminderTime: "08:00"
      }
    ]
  },
  
  "auto_cleanup": {
    version: "1.0",
    rules: [
      {
        category: "spam",
        deleteAfterDays: 7,
        enabled: true
      },
      {
        category: "ad",
        deleteAfterDays: 30,
        enabled: true
      },
      {
        category: "bill",
        compressAfterDays: 90,
        deleteAfterYears: 7,
        enabled: true
      }
    ]
  },
  
  // Can add new rules without app update!
  "smart_suggestions": {
    version: "1.0",
    rules: [
      {
        condition: "recurring_bill_detected",
        suggestion: "Set up auto-reminder for future bills from {sender}",
        enabled: true
      },
      {
        condition: "amount_higher_than_usual",
        threshold: 1.4,  // 40% higher than average
        suggestion: "This {category} is unusually high. Review details?",
        enabled: true
      }
    ]
  }
}
```

### 3.7 A/B Testing Framework

**Test anything without app updates:**

```javascript
// Backend: experiments collection
experiments: {
  "reminder_timing_test": {
    id: "exp_001",
    name: "Optimal Reminder Timing",
    active: true,
    startDate: "2024-11-20",
    endDate: "2024-12-20",
    
    variants: [
      {
        name: "control",
        percentage: 50,
        config: {
          reminderDaysBefore: 3
        }
      },
      {
        name: "variant_a",
        percentage: 25,
        config: {
          reminderDaysBefore: 5
        }
      },
      {
        name: "variant_b",
        percentage: 25,
        config: {
          reminderDaysBefore: 7
        }
      }
    ],
    
    metrics: {
      primary: "payment_on_time_rate",
      secondary: ["user_satisfaction", "reminder_dismissal_rate"]
    }
  },
  
  "paywall_copy_test": {
    id: "exp_002",
    name: "Premium Upgrade Message",
    active: true,
    
    variants: [
      {
        name: "control",
        percentage: 50,
        config: {
          title: "Upgrade to Premium",
          message: "Scan unlimited documents",
          ctaButton: "Upgrade Now"
        }
      },
      {
        name: "urgency",
        percentage: 50,
        config: {
          title: "Don't Miss Important Mail!",
          message: "Premium users never miss a due date",
          ctaButton: "Try Free for 7 Days"
        }
      }
    ],
    
    metrics: {
      primary: "conversion_rate",
      secondary: ["trial_starts", "immediate_purchases"]
    }
  }
}

// iOS requests config with user context
GET /api/config?userId=user_123
Response: {
  "experiments": {
    "reminder_timing_test": "variant_b",  // User assigned to variant B
    "paywall_copy_test": "urgency"
  },
  "config": {
    reminderDaysBefore: 7,  // From variant B
    paywallTitle: "Don't Miss Important Mail!",
    paywallMessage: "Premium users never miss a due date",
    paywallCTA: "Try Free for 7 Days"
  }
}
```

### 3.8 API Response Structure

**Backend returns EVERYTHING iOS needs to know:**

```javascript
// POST /api/analyze
Response: {
  // Analysis results
  analysis: {
    category: "bill",
    subcategory: "utility",
    importance: "high",
    isSpam: false,
    summary: "Electric bill...",
    // ... all analysis fields
  },
  
  // Backend tells iOS what actions to take
  actions: [
    {
      type: "create_calendar_event",
      data: {
        title: "Pay Electric Bill",
        date: "2024-12-15",
        time: "09:00",
        alert: {
          type: "relative",
          minutes: -4320  // 3 days before
        }
      }
    },
    {
      type: "create_reminder",
      data: {
        title: "Electric bill due Dec 15",
        dueDate: "2024-12-15",
        priority: "high",
        notes: "Amount: $127.43"
      }
    },
    {
      type: "show_notification",
      data: {
        title: "Important bill detected",
        body: "We've added a reminder for your electric bill",
        schedule: "immediate"
      }
    },
    {
      type: "show_suggestion",
      data: {
        message: "This bill is 30% higher than usual. Tap to review details.",
        actionLabel: "Review",
        dismissible: true
      }
    }
  ],
  
  // Display configuration
  display: {
    badge: "IMPORTANT",
    badgeColor: "#FF6B6B",
    showAmountHighlight: true,
    showDueDateCountdown: true,
    suggestedTags: ["bills", "utilities", "high-priority"]
  },
  
  // Metadata
  meta: {
    processingTime: 2.3,  // seconds
    confidence: 0.94,
    modelVersion: "3.0",
    promptVersion: "3.0"
  }
}
```

**iOS just follows backend instructions:**
```swift
func handleAnalysisResponse(_ response: AnalysisResponse) {
    // Backend told us what to do
    for action in response.actions {
        switch action.type {
        case "create_calendar_event":
            calendarService.createEvent(action.data)
        case "create_reminder":
            reminderService.createReminder(action.data)
        case "show_notification":
            notificationService.show(action.data)
        case "show_suggestion":
            showInAppSuggestion(action.data)
        default:
            break
        }
    }
}
```

### 3.9 Gradual Feature Rollout

**Roll out features to small percentage of users first:**

```javascript
// Week 1: Beta testers only (0.1%)
POST /api/admin/features/batch_scanning
{
  enabled: true,
  rolloutPercentage: 0.1,
  allowedUsers: ["beta_tester_*"]  // Pattern match
}

// Week 2: Looking good, expand to 10%
PUT /api/admin/features/batch_scanning
{
  rolloutPercentage: 10
}

// Week 3: Expand to 50%
PUT /api/admin/features/batch_scanning
{
  rolloutPercentage: 50
}

// Week 4: Full rollout
PUT /api/admin/features/batch_scanning
{
  rolloutPercentage: 100
}

// Oh no, bug found! Instant rollback:
PUT /api/admin/features/batch_scanning
{
  enabled: false,
  rolloutPercentage: 0
}
```

### 3.10 Benefits Summary

**What this backend-driven approach enables:**

| Traditional Approach | Backend-Driven Approach |
|---------------------|------------------------|
| Change category? → App update (1-7 days) | Change category? → Edit database (instant) |
| New prompt? → App update | New prompt? → Edit database (instant) |
| Fix spam detection? → App update | Fix spam detection? → Adjust rules (instant) |
| A/B test feature? → Submit 2 app versions | A/B test feature? → Toggle flag (instant) |
| Bug in reminder logic? → App update | Bug in reminder logic? → Fix backend (instant) |
| Add new language? → App update | Add new language? → Add strings (instant) |
| User wants custom behavior? → Not possible | User wants custom? → Backend config per user |

**Real-World Example:**
```
Day 1: Launch app
Day 3: Users report spam not detected well
Day 3 (30 min later): Adjust spam detection threshold from 0.7 → 0.6
Day 3 (2 hours later): Monitor analytics - better!
Day 4: Tweak LLM prompt to better identify spam
Day 5: Roll out improved spam detection to 100% of users

Total app updates needed: ZERO
Time to iterate and improve: 2 days instead of 2 weeks
```

---

## 4. Technology Stack

### 3.1 iOS Frontend

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **UI Framework** | SwiftUI | Modern, declarative UI |
| **Language** | Swift 5.9+ | Native iOS development |
| **Document Scanning** | VisionKit | Professional document capture |
| **OCR** | Vision Framework | On-device text extraction |
| **Local Storage** | FileManager + CoreData | Images + metadata cache |
| **Networking** | URLSession / Alamofire | API communication |
| **Calendar** | EventKit | Due date reminders |
| **Notifications** | UserNotifications | Payment alerts |
| **Optional Sync** | iCloud Drive | Cross-device image sync |

### 3.2 Backend

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Server** | Node.js (Express) or Python (FastAPI) | API endpoints |
| **Database** | Firebase Firestore or PostgreSQL | Metadata storage |
| **LLM** | Claude API (Anthropic) | Document analysis |
| **Authentication** | Firebase Auth or Auth0 | User management |
| **Hosting** | Vercel / Railway / AWS Lambda | Serverless/managed |

### 3.3 Cost Structure (Per 1,000 Users)

| Service | Usage | Monthly Cost |
|---------|-------|--------------|
| **Image Storage** | 0 GB (local only) | $0.00 |
| **Metadata Storage** | ~10 GB | $0.26 (Firebase) |
| **LLM API Calls** | 100k calls @ $0.003 | $300.00 |
| **Hosting** | Serverless | $0-20.00 |
| **Total** | | **~$320/month** |
| **Per User** | | **$0.32/month** |

*Pricing assumes 100 scans/user/month average*

---

## 4. Technology Stack

### 4.1 iOS Frontend (Thin Client)

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **UI Framework** | SwiftUI | Modern, declarative UI |
| **Language** | Swift 5.9+ | Native iOS development |
| **Document Scanning** | VisionKit | Professional document capture |
| **OCR** | Vision Framework | On-device text extraction |
| **Local Storage** | FileManager + CoreData | Images + metadata cache |
| **Networking** | URLSession / Alamofire | API communication |
| **Calendar** | EventKit | Due date reminders |
| **Notifications** | UserNotifications | Payment alerts |
| **Optional Sync** | iCloud Drive | Cross-device image sync |

**Key Point:** iOS app has minimal business logic - mostly UI and hardware interfaces.

### 4.2 Backend (Where All Intelligence Lives) 🧠

| Component | Technology | Purpose |
|-----------|-----------|---------|
| **Server** | Node.js (Express) or Python (FastAPI) | API endpoints |
| **Database** | Firebase Firestore or PostgreSQL | Metadata + configuration |
| **Cache** | Redis | Feature flags, config cache |
| **LLM** | Claude API (Anthropic) | Document analysis |
| **Authentication** | Firebase Auth or Auth0 | User management |
| **Feature Flags** | LaunchDarkly / Custom | A/B testing & rollouts |
| **Analytics** | Mixpanel / Amplitude | User behavior tracking |
| **Hosting** | Vercel / Railway / AWS Lambda | Serverless/managed |
| **CDN** | Cloudflare | Fast config delivery |
| **Monitoring** | Sentry / DataDog | Error tracking |
| **Background Jobs** | Bull Queue / Celery | Async processing |

### 4.3 Backend Architecture Components

```
┌─────────────────────────────────────────────┐
│  API Gateway (Express/FastAPI)              │
│  → Rate limiting                            │
│  → Authentication                           │
│  → Request validation                       │
└─────────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────┐
│  Configuration Service                      │
│  → Feature flags (LaunchDarkly/Redis)       │
│  → App config (categories, rules)           │
│  → UI strings (internationalization)        │
│  → A/B experiment assignment                │
└─────────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────┐
│  Analysis Service (Core Logic)              │
│  → LLM prompt management                    │
│  → Document classification                  │
│  → Entity extraction (dates, amounts)       │
│  → Business rules application               │
│  → Action generation (calendar, reminders)  │
└─────────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────┐
│  Rules Engine                               │
│  → Spam detection                           │
│  → Category assignment                      │
│  → Auto-cleanup policies                    │
│  → Reminder timing logic                    │
│  → User personalization                     │
└─────────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────┐
│  Database Layer                             │
│  → User data                                │
│  → Scan metadata                            │
│  → App configuration                        │
│  → Feature flags                            │
│  → Experiments                              │
│  → Analytics events                         │
└─────────────────────────────────────────────┘
                  ↓
┌─────────────────────────────────────────────┐
│  External Services                          │
│  → Claude API (LLM)                         │
│  → Analytics (Mixpanel)                     │
│  → Payment processing (Stripe)              │
│  → Email service (SendGrid)                 │
└─────────────────────────────────────────────┘
```

### 4.4 Cost Structure (Privacy-First Architecture - Per 1,000 Users)

| Service | Usage | Monthly Cost | Notes |
|---------|-------|--------------|-------|
| **Image Storage** | 0 GB (100% local) | $0.00 | Users' devices |
| **Text Storage** | 0 GB (100% local) | $0.00 | JSON on device |
| **Metadata Storage** | ~1 GB | $0.03 (Firebase) | Tiny footprint |
| **LLM API Calls** | 30k calls @ $0.003 | $90.00 | Only opt-ins |
| **Hosting** | Serverless | $0-10.00 | Minimal load |
| **Redis Cache** | Basic tier | $10.00 | Config/flags |
| **Feature Flags** | LaunchDarkly/Custom | $0-10.00 | Optional |
| **Total** | | **~$110/month** | |
| **Per User** | | **$0.11/month** | 70% reduction! |

**Assumptions (Privacy-First Model):**
- 1,000 users × 100 scans/month = 100,000 scans
- Users skip 70% (junk mail) = 30,000 LLM calls
- Only metadata stored (not content)
- Images & text stay on device

**Cost Comparison:**

| Approach | Cost/User/Month | Why |
|----------|----------------|-----|
| **Old: Store Everything** | $0.33 | Stored images, text, analysis in cloud |
| **New: Privacy-First** | $0.11 | Only metadata in cloud, user opt-in |
| **Savings** | **70%** | Better privacy + lower costs |

**Free Tier Economics (25 scans/month):**
- User scans 100 pieces total
- Smart filter: 57 junk, 43 important
- User analyzes 25 important (free tier limit)
- Skips 18 remaining + all 57 junk
- **Your cost: 25 × $0.003 = $0.075**
- **Sustainable at scale!**

**Premium Tier Economics ($4.99/month):**
- User scans unlimited
- Analyzes ~50 important pieces/month
- Your cost: 50 × $0.003 = $0.15
- Your revenue: $4.99
- **Margin: 97%** 🎉

---

## 5. Privacy-First Data Architecture

### 5.1 Core Privacy Principle

**ALL user content stays on device. ONLY metadata syncs to backend.**

This architecture provides:
- ✅ **Maximum user privacy** - Images & text never leave device
- ✅ **70% cost reduction** - No content storage costs
- ✅ **GDPR/CCPA compliance** - User owns their data
- ✅ **User control** - Opt-in for AI analysis
- ✅ **Works offline** - View scans anytime

### 5.2 Local Storage Structure

```
iPhone Local Storage:
/Documents/
  /Scans/                                   (Images)
    scan_1700492400_abc123.jpg              400-500 KB
    scan_1700492401_def456.jpg              380-450 KB
    scan_1700492402_ghi789.jpg              420-480 KB
    
  /OCR/                                     (Extracted Text)
    scan_abc123_ocr.json                    2-5 KB
    scan_def456_ocr.json                    2-5 KB
    scan_ghi789_ocr.json                    2-5 KB
    
  /Analysis/                                (AI Results)
    scan_abc123_analysis.json               1-2 KB
    scan_def456_analysis.json               1-2 KB
    scan_ghi789_analysis.json               1-2 KB

Total per scan: ~405-510 KB
For 100 scans: ~40-50 MB (very manageable!)
```

**JSON File Formats:**

**OCR JSON:**
```json
{
  "scanId": "scan_abc123",
  "extractedText": "ABC Power Company\n123 Main St\nElectric Bill...",
  "metadata": {
    "confidence": 0.94,
    "language": "en",
    "wordCount": 287,
    "extractedAt": "2024-11-20T14:30:05Z"
  }
}
```

**Analysis JSON:**
```json
{
  "scanId": "scan_abc123",
  "analyzedAt": "2024-11-20T14:30:08Z",
  "modelVersion": "3.0",
  "classification": {
    "category": "bill",
    "subcategory": "utility",
    "importance": "high",
    "isSpam": false
  },
  "entities": {
    "sender": { "name": "ABC Power Company" },
    "amounts": [{ "type": "total_due", "amount": 127.43 }],
    "dates": [{ "type": "due_date", "date": "2024-12-15" }]
  },
  "actionItems": [
    {
      "action": "pay_bill",
      "description": "Pay $127.43 by December 15, 2024",
      "dueDate": "2024-12-15"
    }
  ]
}
```

### 5.3 What Data Goes Where

| Data Type | Stored Locally | Stored in Backend | Why |
|-----------|---------------|-------------------|-----|
| **Images** | ✅ 100% | ❌ Never | Privacy + cost |
| **OCR Text** | ✅ 100% | ❌ Never | Privacy |
| **AI Analysis** | ✅ 100% | ❌ Never | Privacy |
| **File names** | ✅ Yes | ✅ Yes (metadata) | Reference |
| **Categories** | ✅ Yes | ✅ Yes (metadata) | Filtering |
| **Due dates** | ✅ Yes | ✅ Yes (metadata) | Reminders |
| **Search keywords** | ✅ Yes | ✅ Yes (derived) | Search |
| **User tags** | ✅ Yes | ✅ Yes | Organization |

### 5.4 User Opt-In Flow

**After OCR completes, user sees:**

```
┌─────────────────────────────────────┐
│  Scan Complete                      │
├─────────────────────────────────────┤
│  [Image Preview]                    │
│                                     │
│  📄 Text Extracted (287 words)      │
│                                     │
│  Preview:                           │
│  "ABC Power Company                 │
│   Electric Bill                     │
│   Due: December 15, 2024            │
│   Amount: $127.43..."               │
│                                     │
│  ────────────────────────           │
│                                     │
│  Want AI to analyze this?           │
│                                     │
│  AI will:                           │
│  • Categorize automatically         │
│  • Extract due dates                │
│  • Create calendar reminders        │
│  • Identify action items            │
│                                     │
│  💎 Credits: 22/25 remaining        │
│                                     │
│  [✨ Analyze with AI]  [Skip]       │
│                                     │
│  [Mark as Spam]  [View Full Text]  │
└─────────────────────────────────────┘
```

**If user clicks "Skip":**
- No LLM API call ($0 cost)
- User can manually tag
- Can analyze later (text is local)
- "You saved 1 credit!" message

**If user clicks "Analyze with AI":**
- Text sent to backend (not image!)
- LLM analysis ($0.003 cost)
- Results saved locally
- Metadata updated in database
- Calendar/reminders created

### 5.5 Privacy Marketing Messages

**First Scan Onboarding:**
```
🔒 Your Privacy Matters

How MailScan AI protects your data:

✓ Images stay on YOUR device
✓ Text stays on YOUR device  
✓ Analysis stays on YOUR device

What we store online:
• File names (not files)
• Categories (bill/spam)
• Due dates you extract

What we NEVER store:
✗ Your images
✗ Full text content
✗ Personal information

You're in complete control.

[Continue]
```

**In Settings:**
```
🔒 Privacy & Data

Local Storage (This iPhone):
• 47 images (19.2 MB)
• 47 text files (235 KB)
• 32 analyses (64 KB)

Cloud Storage (Our Servers):
• File names only
• Categories & dates
• No images or text

[Export All Data]
[Delete All Cloud Data]
[View Privacy Policy]
```

### 5.6 Cost Optimization with Opt-In

**Free Tier User (25 scans/month limit):**

Scenario: User scans 100 pieces of mail in a month
- 57 junk mail → user skips analysis
- 43 important → user analyzes 25, skips 18 (over limit)

Your costs:
- Database metadata: 100 × $0.00001 = **$0.001**
- LLM analysis: 25 × $0.003 = **$0.075**
- **Total: $0.076/month per user**

**Premium User (unlimited scans):**

Scenario: User scans 100 pieces of mail in a month
- 57 junk mail → user skips analysis (smart!)
- 43 important → user analyzes all 43

Your costs:
- Database metadata: 100 × $0.00001 = **$0.001**
- LLM analysis: 43 × $0.003 = **$0.129**
- **Total: $0.130/month per user**

Your revenue: **$4.99/month**
Your margin: **$4.86** (97% margin!)

### 5.7 Data Export & Deletion

**Export All Data:**
```swift
func exportAllData() -> URL {
    let export = {
        "images": getAllImagePaths(),
        "ocr": getAllOCRJSON(),
        "analysis": getAllAnalysisJSON(),
        "metadata": downloadCloudMetadata()
    }
    
    let zipFile = createZIP(export)
    return zipFile // User can save/share
}
```

**Delete All Data:**
```swift
func deleteAllData() async {
    // 1. Delete local files
    deleteDirectory("Documents/Scans/")
    deleteDirectory("Documents/OCR/")
    deleteDirectory("Documents/Analysis/")
    
    // 2. Delete cloud metadata
    await DELETE("/api/users/{userId}/scans")
    
    // 3. Remove iOS integrations
    deleteAllCalendarEvents()
    deleteAllReminders()
    
    // User's data is completely gone
}
```

---

## 6. Database Schema

### 4.1 Users Collection

```javascript
users/{userId}
{
  userId: "user_abc123",
  email: "user@example.com",
  displayName: "John Doe",
  createdAt: "2024-11-20T10:00:00Z",
  
  // Settings
  preferences: {
    enableiCloudSync: true,
    autoDeleteSpam: true,
    spamRetentionDays: 7,
    importantRetentionYears: 7,
    notificationsEnabled: true,
    reminderDaysBefore: 3
  },
  
  // Stats
  stats: {
    totalScans: 847,
    spamFiltered: 623,
    currentStorageUsed: 342000000, // bytes
    lastScanDate: "2024-11-20T14:30:00Z"
  },
  
  // Subscription
  subscription: {
    tier: "free", // free, premium
    status: "active",
    expiresAt: null
  }
}
```

### 4.2 Scans Collection

```javascript
users/{userId}/scans/{scanId}
{
  scanId: "scan_abc123",
  userId: "user_abc123",
  
  // Local file reference
  localFileName: "scan_1700492400_abc123.jpg",
  deviceId: "iPhone-14-Pro-ABC123",
  timestamp: "2024-11-20T14:30:00Z",
  
  // File info
  hasLocalImage: true,
  imageDeletedLocally: false,
  estimatedImageSize: 450000, // bytes
  imageResolution: "2048x1536",
  
  // Extracted content
  extractedText: "Full OCR text here...",
  ocrConfidence: 0.95,
  language: "en",
  
  // LLM Analysis
  analysis: {
    category: "bill", // bill, spam, important, personal, medical, legal, ad, other
    subcategory: "utility",
    importance: "high", // high, medium, low
    isSpam: false,
    spamConfidence: 0.02,
    
    summary: "Electric bill from ABC Power Company for November 2024",
    
    // Entities extracted
    sender: {
      name: "ABC Power Company",
      address: "123 Main St, Fort Worth, TX 76102",
      phone: "1-800-555-0123",
      email: "billing@abcpower.com"
    },
    
    // Financial info
    amounts: [
      {
        type: "total_due",
        amount: 127.43,
        currency: "USD"
      }
    ],
    
    // Important dates
    dates: [
      {
        type: "due_date",
        date: "2024-12-15",
        description: "Payment due"
      },
      {
        type: "service_period",
        startDate: "2024-10-15",
        endDate: "2024-11-15"
      }
    ],
    
    // Action items
    actionItems: [
      {
        action: "pay_bill",
        description: "Pay $127.43 by December 15, 2024",
        priority: "high",
        dueDate: "2024-12-15",
        completed: false,
        calendarEventId: "event_123", // iOS Calendar event ID
        reminderIds: ["reminder_456"] // iOS Reminders IDs
      },
      {
        action: "call_if_questions",
        description: "Call 1-800-555-0123 for billing questions",
        priority: "low",
        dueDate: null,
        completed: false
      }
    ],
    
    // Search optimization
    searchKeywords: [
      "electricity", "bill", "power", "utility", 
      "abc power", "november", "payment", "december"
    ]
  },
  
  // User interactions
  userMetadata: {
    archived: false,
    favorite: false,
    tags: ["bills", "utilities", "2024"],
    notes: "",
    lastViewedAt: "2024-11-20T15:00:00Z",
    viewCount: 3
  },
  
  // Status tracking
  status: {
    processed: true,
    processedAt: "2024-11-20T14:30:05Z",
    error: null,
    calendarEventCreated: true,
    reminderCreated: true
  },
  
  // Audit
  createdAt: "2024-11-20T14:30:00Z",
  updatedAt: "2024-11-20T15:00:00Z"
}
```

### 5.3 Categories Reference

```javascript
categories/
{
  bill: {
    name: "Bills",
    icon: "doc.text.fill",
    color: "#FF6B6B",
    defaultRetention: 7, // years
    subcategories: ["utility", "phone", "internet", "insurance", "credit_card"]
  },
  spam: {
    name: "Spam/Junk",
    icon: "trash.fill",
    color: "#95A5A6",
    defaultRetention: 0.02, // 7 days
    subcategories: ["marketing", "solicitation", "scam"]
  },
  important: {
    name: "Important",
    icon: "exclamationmark.triangle.fill",
    color: "#F39C12",
    defaultRetention: null, // keep forever
    subcategories: ["legal", "tax", "government", "contract"]
  },
  medical: {
    name: "Medical",
    icon: "heart.fill",
    color: "#E74C3C",
    defaultRetention: null,
    subcategories: ["insurance", "bill", "prescription", "records"]
  },
  personal: {
    name: "Personal",
    icon: "envelope.fill",
    color: "#3498DB",
    defaultRetention: 1,
    subcategories: ["correspondence", "invitation", "greeting_card"]
  }
}
```

### 5.4 Backend Configuration Collections 🔥

**These collections enable backend-driven features without app updates:**

#### Feature Flags
```javascript
feature_flags/{flagId}
{
  flagId: "spam_detection_v2",
  name: "Improved Spam Detection",
  enabled: true,
  rolloutPercentage: 100,
  requiredPlan: null,  // or "premium", "business"
  targetedUsers: [],
  excludedUsers: [],
  createdAt: "2024-11-15T10:00:00Z"
}
```

#### LLM Prompts
```javascript
llm_prompts/{promptId}
{
  promptId: "document_analysis_v3",
  version: "3.0",
  active: true,
  template: `[FULL PROMPT STORED HERE - EDITABLE WITHOUT APP UPDATE]`,
  model: "claude-sonnet-4-20250514",
  maxTokens: 2000,
  rolloutPercentage: 100,
  metrics: {
    avgAccuracy: 0.94,
    avgLatencyMs: 2300
  }
}
```

#### Business Rules
```javascript
business_rules/spam_detection
{
  ruleId: "spam_detection_rules",
  version: "2.0",
  rules: [
    {
      condition: "contains_keywords",
      keywords: ["limited time", "act now"],
      weight: 0.3
    }
  ],
  threshold: 0.7,
  actions: {
    markAsSpam: true,
    autoArchive: true,
    retentionDays: 7
  }
}

business_rules/reminder_timing
{
  ruleId: "reminder_timing_v1",
  rules: [
    {
      category: "bill",
      importance: "high",
      reminderStrategy: {
        daysBefore: [7, 3, 1],
        reminderTime: "09:00"
      }
    }
  ]
}
```

#### App Configuration
```javascript
app_config/global
{
  configId: "global_config",
  version: "1.2.0",
  behavior: {
    maxScansPerDayFree: 5,
    autoDeleteSpamAfterDays: 7,
    ocrConfidenceThreshold: 0.7
  },
  planFeatures: {
    free: {
      scansPerMonth: 25,
      cloudBackup: false
    },
    premium: {
      scansPerMonth: null,
      cloudBackup: true
    }
  }
}
```

#### UI Strings (Internationalization)
```javascript
ui_strings/en
{
  locale: "en",
  version: "1.3.0",
  strings: {
    "home_empty_title": "No mail scanned yet",
    "paywall_title": "Upgrade to Premium",
    "paywall_cta": "Try Free for 7 Days",
    // ALL UI text stored here - update without app release!
  }
}
```

#### A/B Test Experiments
```javascript
experiments/{experimentId}
{
  experimentId: "exp_reminder_timing",
  name: "Optimal Reminder Timing",
  active: true,
  variants: [
    {
      name: "control",
      percentage: 34,
      config: { reminderDaysBefore: 3 }
    },
    {
      name: "variant_a",
      percentage: 33,
      config: { reminderDaysBefore: 7 }
    },
    {
      name: "variant_b",
      percentage: 33,
      config: { reminderDaysBefore: 1 }
    }
  ],
  metrics: {
    primary: "payment_on_time_rate"
  },
  winner: "variant_a"
}
```

---

## 6. iOS App Structure
    subcategories: ["marketing", "solicitation", "scam"]
  },
  important: {
    name: "Important",
    icon: "exclamationmark.triangle.fill",
    color: "#F39C12",
    defaultRetention: null, // keep forever
    subcategories: ["legal", "tax", "government", "contract"]
  },
  medical: {
    name: "Medical",
    icon: "heart.fill",
    color: "#E74C3C",
    defaultRetention: null,
    subcategories: ["insurance", "bill", "prescription", "records"]
  },
  personal: {
    name: "Personal",
    icon: "envelope.fill",
    color: "#3498DB",
    defaultRetention: 1,
    subcategories: ["correspondence", "invitation", "greeting_card"]
  }
}
```

---

## 5. iOS App Structure

### 5.1 Project Organization

```
MailScanApp/
├── App/
│   ├── MailScanApp.swift              // App entry point
│   └── AppDelegate.swift              // App lifecycle
│
├── Core/
│   ├── Models/
│   │   ├── Scan.swift                 // Scan data model
│   │   ├── ScanAnalysis.swift         // LLM analysis model
│   │   ├── Category.swift             // Category enum
│   │   └── User.swift                 // User model
│   │
│   ├── Services/
│   │   ├── ScannerService.swift       // Document scanning
│   │   ├── OCRService.swift           // Text extraction
│   │   ├── StorageService.swift       // Local file management
│   │   ├── NetworkService.swift       // API calls
│   │   ├── DatabaseService.swift      // CoreData operations
│   │   ├── CalendarService.swift      // EventKit integration
│   │   ├── ReminderService.swift      // Reminders integration
│   │   ├── NotificationService.swift  // Local notifications
│   │   └── iCloudService.swift        // iCloud Drive sync
│   │
│   ├── Managers/
│   │   ├── AuthManager.swift          // Authentication
│   │   ├── AnalyticsManager.swift     // Usage tracking
│   │   └── SettingsManager.swift      // User preferences
│   │
│   └── Utilities/
│       ├── Constants.swift            // App constants
│       ├── Extensions.swift           // Swift extensions
│       └── Helpers.swift              // Helper functions
│
├── Features/
│   ├── Onboarding/
│   │   ├── OnboardingView.swift
│   │   └── OnboardingViewModel.swift
│   │
│   ├── Scanner/
│   │   ├── ScannerView.swift          // Camera interface
│   │   ├── ScannerViewModel.swift
│   │   └── ProcessingView.swift       // "Analyzing..." view
│   │
│   ├── Home/
│   │   ├── HomeView.swift             // Main feed
│   │   ├── HomeViewModel.swift
│   │   ├── ScanCardView.swift         // Individual scan card
│   │   └── FilterBar.swift            // Category filters
│   │
│   ├── Detail/
│   │   ├── ScanDetailView.swift       // Full scan view
│   │   ├── DetailViewModel.swift
│   │   ├── ImageViewer.swift          // Zoomable image
│   │   └── ActionItemsView.swift      // To-do list
│   │
│   ├── Search/
│   │   ├── SearchView.swift
│   │   ├── SearchViewModel.swift
│   │   └── SearchResultsView.swift
│   │
│   ├── Settings/
│   │   ├── SettingsView.swift
│   │   ├── PreferencesView.swift
│   │   ├── StorageView.swift
│   │   └── SubscriptionView.swift
│   │
│   └── Auth/
│       ├── LoginView.swift
│       ├── SignUpView.swift
│       └── AuthViewModel.swift
│
├── Resources/
│   ├── Assets.xcassets               // Images, icons
│   ├── Colors.xcassets               // Color palette
│   ├── Localizable.strings           // Translations
│   └── Info.plist
│
└── Tests/
    ├── Unit/
    └── UI/
```

### 5.2 Key SwiftUI Views

#### Main Tab Structure
```swift
TabView {
    HomeView()
        .tabItem {
            Label("Home", systemImage: "house.fill")
        }
    
    SearchView()
        .tabItem {
            Label("Search", systemImage: "magnifyingglass")
        }
    
    ScannerView()
        .tabItem {
            Label("Scan", systemImage: "plus.circle.fill")
        }
    
    SettingsView()
        .tabItem {
            Label("Settings", systemImage: "gear")
        }
}
```

---

## 6. Core Features Implementation

### 6.1 Document Scanning Flow

```swift
// Trigger document scanner
VNDocumentCameraViewController
  ↓
// User captures multiple pages if needed
  ↓
// didFinishWith scan: VNDocumentCameraScan
  ↓
// Process each page:
for pageIndex in 0..<scan.pageCount {
    let image = scan.imageOfPage(at: pageIndex)
    
    // 1. Save locally
    let fileName = saveImageLocally(image)
    
    // 2. Extract text (on-device)
    let text = performOCR(image)
    
    // 3. Send to backend for analysis
    let analysis = await analyzeWithAI(text)
    
    // 4. Save metadata
    await saveToDatabase(fileName, text, analysis)
    
    // 5. Create reminders/calendar events
    await createiOSIntegrations(analysis)
}
```

### 6.2 OCR Implementation

```swift
import Vision
import VisionKit

class OCRService {
    func extractText(from image: UIImage) async throws -> String {
        guard let cgImage = image.cgImage else {
            throw OCRError.invalidImage
        }
        
        let requestHandler = VNImageRequestHandler(
            cgImage: cgImage,
            options: [:]
        )
        
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true
        
        try requestHandler.perform([request])
        
        guard let observations = request.results else {
            throw OCRError.noTextFound
        }
        
        let recognizedText = observations
            .compactMap { $0.topCandidates(1).first?.string }
            .joined(separator: "\n")
        
        return recognizedText
    }
}
```

### 6.3 LLM Analysis API Call

```swift
class NetworkService {
    func analyzeDocument(text: String, userId: String) async throws -> ScanAnalysis {
        let endpoint = "\(baseURL)/api/analyze"
        
        let payload: [String: Any] = [
            "text": text,
            "userId": userId,
            "timestamp": ISO8601DateFormatter().string(from: Date())
        ]
        
        let (data, response) = try await URLSession.shared.upload(
            for: URLRequest(url: URL(string: endpoint)!),
            from: JSONSerialization.data(withJSONObject: payload)
        )
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw NetworkError.serverError
        }
        
        let analysis = try JSONDecoder().decode(
            ScanAnalysis.self, 
            from: data
        )
        
        return analysis
    }
}
```

### 6.4 Local Storage Management

```swift
class StorageService {
    private let fileManager = FileManager.default
    private let scansDirectory: URL
    
    init() {
        let documentsPath = fileManager.urls(
            for: .documentDirectory,
            in: .userDomainMask
        )[0]
        
        scansDirectory = documentsPath.appendingPathComponent("Scans")
        
        // Create directory if needed
        try? fileManager.createDirectory(
            at: scansDirectory,
            withIntermediateDirectories: true
        )
    }
    
    func saveImage(_ image: UIImage) -> String? {
        let fileName = "scan_\(Date().timeIntervalSince1970)_\(UUID().uuidString).jpg"
        let fileURL = scansDirectory.appendingPathComponent(fileName)
        
        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            return nil
        }
        
        do {
            try imageData.write(to: fileURL)
            return fileName
        } catch {
            print("Error saving image: \(error)")
            return nil
        }
    }
    
    func loadImage(fileName: String) -> UIImage? {
        let fileURL = scansDirectory.appendingPathComponent(fileName)
        guard let imageData = try? Data(contentsOf: fileURL) else {
            return nil
        }
        return UIImage(data: imageData)
    }
    
    func deleteImage(fileName: String) {
        let fileURL = scansDirectory.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }
    
    func getTotalStorageUsed() -> Int64 {
        guard let files = try? fileManager.contentsOfDirectory(
            at: scansDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) else {
            return 0
        }
        
        let totalBytes = files.reduce(0) { total, url in
            let size = (try? url.resourceValues(forKeys: [.fileSizeKey]))?.fileSize ?? 0
            return total + Int64(size)
        }
        
        return totalBytes
    }
}
```

### 6.5 Calendar Integration

```swift
import EventKit

class CalendarService {
    private let eventStore = EKEventStore()
    
    func requestAccess() async -> Bool {
        do {
            return try await eventStore.requestAccess(to: .event)
        } catch {
            return false
        }
    }
    
    func createEvent(for actionItem: ActionItem) async -> String? {
        guard await requestAccess() else { return nil }
        
        let event = EKEvent(eventStore: eventStore)
        event.title = actionItem.description
        event.startDate = actionItem.dueDate
        event.endDate = actionItem.dueDate.addingTimeInterval(3600) // 1 hour
        event.calendar = eventStore.defaultCalendarForNewEvents
        
        // Add alarm 3 days before
        let alarm = EKAlarm(relativeOffset: -3 * 24 * 60 * 60)
        event.addAlarm(alarm)
        
        do {
            try eventStore.save(event, span: .thisEvent)
            return event.eventIdentifier
        } catch {
            print("Error saving event: \(error)")
            return nil
        }
    }
    
    func deleteEvent(eventId: String) {
        guard let event = eventStore.event(withIdentifier: eventId) else {
            return
        }
        
        try? eventStore.remove(event, span: .thisEvent)
    }
}
```

### 6.6 iCloud Drive Sync (Optional)

```swift
class iCloudService {
    private let fileManager = FileManager.default
    
    var iCloudAvailable: Bool {
        return fileManager.ubiquityIdentityToken != nil
    }
    
    func synciCloudDrive(localFileName: String) async -> Bool {
        guard iCloudAvailable else { return false }
        
        guard let iCloudURL = fileManager.url(
            forUbiquityContainerIdentifier: nil
        )?.appendingPathComponent("Documents/Scans") else {
            return false
        }
        
        // Create directory if needed
        try? fileManager.createDirectory(
            at: iCloudURL,
            withIntermediateDirectories: true
        )
        
        let localURL = getLocalURL(for: localFileName)
        let cloudURL = iCloudURL.appendingPathComponent(localFileName)
        
        do {
            // Copy file to iCloud
            if fileManager.fileExists(atPath: cloudURL.path) {
                try fileManager.removeItem(at: cloudURL)
            }
            try fileManager.copyItem(at: localURL, to: cloudURL)
            return true
        } catch {
            print("iCloud sync error: \(error)")
            return false
        }
    }
}
```

---

## 7. Backend API Design

### 7.1 API Endpoints

```
POST /api/auth/register
POST /api/auth/login
POST /api/auth/refresh

POST /api/analyze              // Main LLM analysis endpoint
GET  /api/scans                // Get user's scans (metadata only)
GET  /api/scans/:scanId        // Get specific scan
PUT  /api/scans/:scanId        // Update scan metadata
DELETE /api/scans/:scanId      // Delete scan metadata

GET  /api/stats                // User statistics
GET  /api/categories           // Available categories

POST /api/feedback             // User feedback
```

### 7.2 Main Analysis Endpoint (Node.js Example)

```javascript
// POST /api/analyze
app.post('/api/analyze', authenticate, async (req, res) => {
    try {
        const { text, userId, timestamp } = req.body;
        
        // Validate input
        if (!text || text.length < 10) {
            return res.status(400).json({ 
                error: 'Text too short for analysis' 
            });
        }
        
        // Call LLM (Claude API)
        const analysis = await analyzeWithClaude(text);
        
        // Generate scanId
        const scanId = `scan_${Date.now()}_${uuidv4()}`;
        
        // Save to database
        await db.collection('users').doc(userId)
            .collection('scans').doc(scanId)
            .set({
                scanId,
                userId,
                timestamp,
                extractedText: text,
                analysis,
                createdAt: admin.firestore.FieldValue.serverTimestamp()
            });
        
        // Return analysis
        res.json({
            scanId,
            analysis
        });
        
    } catch (error) {
        console.error('Analysis error:', error);
        res.status(500).json({ error: 'Analysis failed' });
    }
});
```

### 7.3 LLM Prompt Template

```javascript
async function analyzeWithClaude(text) {
    const prompt = `You are an AI assistant that analyzes scanned mail documents. 
Analyze the following document text and return a structured JSON response.

Document text:
"""
${text}
"""

Return a JSON object with this exact structure:
{
  "category": "bill|spam|important|personal|medical|legal|ad|other",
  "subcategory": "specific subcategory",
  "importance": "high|medium|low",
  "isSpam": boolean,
  "spamConfidence": number between 0-1,
  "summary": "brief 1-2 sentence summary",
  "sender": {
    "name": "sender name or null",
    "address": "physical address or null",
    "phone": "phone number or null",
    "email": "email or null"
  },
  "amounts": [
    {
      "type": "total_due|balance|payment|refund",
      "amount": number,
      "currency": "USD"
    }
  ],
  "dates": [
    {
      "type": "due_date|service_period|appointment|deadline",
      "date": "YYYY-MM-DD",
      "description": "what this date represents"
    }
  ],
  "actionItems": [
    {
      "action": "pay_bill|call|respond|schedule|file",
      "description": "clear action description",
      "priority": "high|medium|low",
      "dueDate": "YYYY-MM-DD or null"
    }
  ],
  "searchKeywords": ["array", "of", "relevant", "keywords"]
}

Important rules:
- Be thorough in extracting dates, amounts, and action items
- Mark as spam if it's clearly junk mail or unsolicited marketing
- Extract ALL due dates and amounts found
- Generate 5-10 relevant search keywords
- If information is unclear or not present, use null
- Ensure dates are in YYYY-MM-DD format`;

    const response = await anthropic.messages.create({
        model: 'claude-sonnet-4-20250514',
        max_tokens: 2000,
        messages: [
            {
                role: 'user',
                content: prompt
            }
        ]
    });
    
    // Parse JSON response
    const analysisText = response.content[0].text;
    const jsonMatch = analysisText.match(/\{[\s\S]*\}/);
    
    if (!jsonMatch) {
        throw new Error('Failed to extract JSON from response');
    }
    
    return JSON.parse(jsonMatch[0]);
}
```

---

## 8. User Interface Design

### 8.1 Home Screen (Main Feed)

```
┌─────────────────────────────────────┐
│  MailScan AI                     ⚙️ │
├─────────────────────────────────────┤
│                                     │
│  📊 This Week: 12 scans             │
│  🗑️  8 spam filtered                │
│  ⚠️  3 items need action            │
│                                     │
├─────────────────────────────────────┤
│  Filters: [All] Bills Important    │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📄 Electric Bill          ⭐ │   │
│  │ ABC Power Company           │   │
│  │ Due: Dec 15 • $127.43       │   │
│  │ 📅 Reminder set             │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 📄 Credit Card Statement     │   │
│  │ Chase Bank                   │   │
│  │ Due: Dec 20 • $2,341.89     │   │
│  │ ⚠️ No reminder yet           │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ 🗑️ Junk Mail                 │   │
│  │ "Limited Time Offer!"       │   │
│  │ Filtered • Tap to review    │   │
│  └─────────────────────────────┘   │
│                                     │
└─────────────────────────────────────┘
  [Home] [Search] [+] [Settings]
```

### 8.2 Scan Detail View

```
┌─────────────────────────────────────┐
│  ← Electric Bill              ⋮ ⭐  │
├─────────────────────────────────────┤
│                                     │
│  ┌─────────────────────────────┐   │
│  │                             │   │
│  │     [Scanned Image]         │   │
│  │     [Pinch to zoom]         │   │
│  │                             │   │
│  └─────────────────────────────┘   │
│                                     │
│  📋 Summary                         │
│  Electric bill from ABC Power       │
│  Company for November 2024          │
│                                     │
│  💰 Amount Due                      │
│  $127.43 USD                        │
│                                     │
│  📅 Due Date                        │
│  December 15, 2024 (25 days)       │
│  ✓ Calendar event created          │
│  ✓ Reminder set for Dec 12         │
│                                     │
│  📞 Contact                         │
│  ABC Power Company                  │
│  📱 1-800-555-0123                  │
│  📧 billing@abcpower.com            │
│                                     │
│  ✅ Action Items                    │
│  [ ] Pay $127.43 by Dec 15         │
│  [ ] Call if questions             │
│                                     │
│  🏷️ Tags                            │
│  bills, utilities, 2024             │
│                                     │
│  📝 Notes                           │
│  [Add personal notes...]            │
│                                     │
│  [View Full Text]  [Share]  [Delete]│
│                                     │
└─────────────────────────────────────┘
```

### 8.3 Scanner View

```
┌─────────────────────────────────────┐
│  Scan Mail                       ✕  │
├─────────────────────────────────────┤
│                                     │
│         ┌─────────────┐             │
│         │             │             │
│         │   CAMERA    │             │
│         │   PREVIEW   │             │
│         │             │             │
│         │  [Document  │             │
│         │   outline   │             │
│         │   detected] │             │
│         │             │             │
│         └─────────────┘             │
│                                     │
│     💡 Tips for best results:       │
│     • Good lighting                 │
│     • Flat surface                  │
│     • Fill the frame                │
│                                     │
│            [Capture]                │
│                                     │
│       [Manual] [Auto] [Batch]       │
│                                     │
└─────────────────────────────────────┘
```

### 8.4 Processing View

```
┌─────────────────────────────────────┐
│  Processing Your Mail...            │
├─────────────────────────────────────┤
│                                     │
│           🔄 [Animation]            │
│                                     │
│     ✓ Image captured                │
│     ✓ Text extracted (432 words)   │
│     ⏳ Analyzing with AI...         │
│     ⏳ Extracting dates...          │
│     ⏳ Creating reminders...        │
│                                     │
│     This usually takes 3-5 seconds  │
│                                     │
└─────────────────────────────────────┘
```

### 8.5 Settings View

```
┌─────────────────────────────────────┐
│  ← Settings                         │
├─────────────────────────────────────┤
│                                     │
│  👤 Profile                         │
│  John Doe                           │
│  john@example.com                   │
│  [Edit Profile]                     │
│                                     │
│  💾 Storage                         │
│  342 MB used locally                │
│  [Manage Storage]                   │
│                                     │
│  ☁️ iCloud Sync                     │
│  [●] Enable iCloud Drive sync      │
│  Last synced: 2 minutes ago         │
│                                     │
│  🔔 Notifications                   │
│  [●] Payment reminders             │
│  [ ] Weekly summary                │
│  Remind me: 3 days before due       │
│                                     │
│  🗑️ Auto-Delete                     │
│  [●] Delete spam after: 7 days     │
│  [●] Compress old scans (90+ days) │
│                                     │
│  📊 Categories                      │
│  [Customize categories & rules]     │
│                                     │
│  💳 Subscription                    │
│  Free Plan                          │
│  [Upgrade to Premium]              │
│                                     │
│  ℹ️ About                           │
│  Version 1.0.0                      │
│  [Privacy Policy] [Terms]          │
│  [Send Feedback]                   │
│                                     │
│  [Sign Out]                        │
│                                     │
└─────────────────────────────────────┘
```

---

## 9. Development Phases

### Phase 1: MVP (4-6 weeks)
**Goal:** Core functionality working end-to-end

- [x] **Week 1-2: Setup & Core Infrastructure**
  - Xcode project setup
  - Firebase/backend setup
  - Basic SwiftUI app structure
  - Authentication flow
  
- [ ] **Week 3-4: Core Features**
  - Document scanning (VisionKit)
  - OCR implementation (Vision)
  - Local storage
  - Basic LLM integration
  
- [ ] **Week 5-6: UI & Polish**
  - Home feed view
  - Detail view
  - Basic settings
  - TestFlight beta

**MVP Features:**
- ✅ Scan documents
- ✅ Extract text (OCR)
- ✅ Basic AI categorization
- ✅ Local storage
- ✅ Simple list view
- ❌ Calendar integration (Phase 2)
- ❌ Advanced filters (Phase 2)
- ❌ iCloud sync (Phase 2)

### Phase 2: Enhanced Features (4-6 weeks)

- [ ] **Calendar & Reminders**
  - EventKit integration
  - Due date reminders
  - Action items tracking
  
- [ ] **Smart Features**
  - Advanced categorization
  - Spam filtering
  - Search functionality
  - Tags & notes
  
- [ ] **Storage Options**
  - iCloud Drive sync
  - Storage management
  - Auto-cleanup rules

### Phase 3: Polish & Scale (4-6 weeks)

- [ ] **UI/UX Improvements**
  - Animations & transitions
  - Onboarding flow
  - Empty states
  - Error handling
  
- [ ] **Performance**
  - Image optimization
  - Caching strategies
  - Background processing
  
- [ ] **Premium Features**
  - Subscription system
  - Cloud backup
  - Export options
  - Web portal

### Phase 4: Launch (2-3 weeks)

- [ ] App Store submission
- [ ] Marketing materials
- [ ] Website/landing page
- [ ] Support documentation
- [ ] Analytics integration

---

## 10. Testing Strategy

### 10.1 Unit Tests

```swift
// Test OCR accuracy
func testOCRExtraction() async throws {
    let testImage = UIImage(named: "test_bill")!
    let ocrService = OCRService()
    let text = try await ocrService.extractText(from: testImage)
    
    XCTAssertTrue(text.contains("Total Due"))
    XCTAssertTrue(text.contains("$127.43"))
}

// Test local storage
func testImageStorage() {
    let storageService = StorageService()
    let testImage = UIImage(named: "test_scan")!
    
    let fileName = storageService.saveImage(testImage)
    XCTAssertNotNil(fileName)
    
    let loadedImage = storageService.loadImage(fileName: fileName!)
    XCTAssertNotNil(loadedImage)
    
    storageService.deleteImage(fileName: fileName!)
}

// Test date extraction
func testDateParsing() {
    let analysis = ScanAnalysis(mockJSON)
    XCTAssertEqual(analysis.dates.count, 2)
    XCTAssertEqual(analysis.dates[0].type, .dueDate)
}
```

### 10.2 Integration Tests

- API endpoint connectivity
- LLM response parsing
- Database read/write operations
- Calendar event creation

### 10.3 UI Tests

```swift
func testScanFlow() throws {
    let app = XCUIApplication()
    app.launch()
    
    // Tap scan button
    app.tabBars.buttons["Scan"].tap()
    
    // Wait for scanner
    XCTAssertTrue(app.otherElements["DocumentScanner"].exists)
    
    // Simulate scan completion
    // ...
    
    // Verify processing view
    XCTAssertTrue(app.staticTexts["Processing Your Mail..."].exists)
    
    // Wait for completion
    let detailView = app.otherElements["ScanDetailView"]
    XCTAssertTrue(detailView.waitForExistence(timeout: 10))
}
```

### 10.4 Test Data

Create diverse test documents:
- Utility bills (electric, gas, water)
- Credit card statements
- Medical bills
- Insurance documents
- Junk mail / spam
- Handwritten notes
- Multi-page documents
- Poor quality scans

---

## 11. Privacy & Security

### 11.1 Data Privacy

**Local-First Approach:**
- Images NEVER uploaded to servers
- Only text extracted and sent to backend
- User has full control over data

**Data Minimization:**
- Collect only necessary metadata
- Delete spam/junk automatically
- User can delete anytime

**Transparency:**
- Clear privacy policy
- Explain what data is collected
- How LLM analysis works

### 11.2 Security Measures

```swift
// Encrypt sensitive data in CoreData
let description = NSPersistentStoreDescription()
description.setOption(
    FileProtectionType.complete as NSObject,
    forKey: NSPersistentStoreFileProtectionKey
)

// Use Keychain for tokens
KeychainWrapper.standard.set(
    authToken,
    forKey: "auth_token"
)

// Secure API communication
URLSession.shared.configuration.tlsMinimumSupportedProtocolVersion = .TLSv13
```

**Backend Security:**
- HTTPS only
- JWT authentication
- Rate limiting
- Input validation
- SQL injection prevention

### 11.3 Permissions Required

```xml
<!-- Info.plist -->
<key>NSCameraUsageDescription</key>
<string>We need camera access to scan your mail documents</string>

<key>NSPhotoLibraryAddUsageDescription</key>
<string>Save scanned documents to Photos (optional)</string>

<key>NSCalendarsUsageDescription</key>
<string>Create calendar events for payment due dates</string>

<key>NSRemindersUsageDescription</key>
<string>Create reminders for important action items</string>

<key>NSUserNotificationsUsageDescription</key>
<string>Send payment reminders and alerts</string>
```

---

## 12. Monetization Strategy

### 12.1 Pricing Tiers

**Free Tier:**
- 25 scans per month
- Basic categorization
- Local storage only
- Ads (non-intrusive)
- Limited to 500 MB storage

**Premium Tier ($4.99/month or $49.99/year):**
- Unlimited scans
- Advanced AI analysis
- Cloud backup (important docs)
- Priority processing
- No ads
- Web portal access
- Export to PDF/CSV
- Family sharing (up to 5 members)
- Email receipts to app

**Business Tier ($14.99/month):**
- Everything in Premium
- Multi-user support
- QuickBooks integration
- Advanced reporting
- Tax category customization
- Priority support

### 12.2 Revenue Projections

**Year 1 Goals:**
- 10,000 downloads
- 5% conversion to Premium = 500 paid users
- Monthly recurring revenue: $2,495
- Annual revenue: ~$30,000

**Cost Structure:**
- LLM API: $160/month (500 users × 100 scans × $0.003)
- Hosting: $20/month
- Firebase: $25/month
- Apple Developer: $99/year
- **Total costs: ~$205/month = $2,460/year**
- **Profit: ~$27,500/year**

### 12.3 Growth Strategy

**Organic:**
- App Store optimization (ASO)
- Word of mouth
- Content marketing (blog about mail organization)

**Paid:**
- App Store search ads
- Facebook/Instagram ads targeting homeowners
- Partnerships with productivity apps

**Retention:**
- Push notifications for value (due date reminders)
- Regular feature updates
- Email newsletters with tips
- Referral program

---

## 13. Analytics & Metrics

### 13.1 Key Metrics to Track

**User Engagement:**
- Daily active users (DAU)
- Monthly active users (MAU)
- Scans per user per month
- Retention rate (D1, D7, D30)

**Feature Usage:**
- Most scanned categories
- Calendar integration usage
- Search query volume
- Settings changes

**Performance:**
- OCR success rate
- LLM analysis accuracy
- App crash rate
- API response times

**Business:**
- Conversion rate (free → paid)
- Churn rate
- Customer acquisition cost (CAC)
- Lifetime value (LTV)

### 13.2 Analytics Implementation

```swift
// Firebase Analytics
Analytics.logEvent("scan_completed", parameters: [
    "category": scanAnalysis.category,
    "importance": scanAnalysis.importance,
    "has_due_date": scanAnalysis.dates.isEmpty == false,
    "is_spam": scanAnalysis.isSpam
])

Analytics.logEvent("calendar_event_created", parameters: [
    "days_until_due": daysUntilDue
])

Analytics.logEvent("upgrade_to_premium", parameters: [
    "from_screen": "settings",
    "scans_in_last_30_days": scanCount
])
```

---

## 14. Future Enhancements

### 14.1 AI Features

- **Smart suggestions:** "You usually pay this bill on the 10th"
- **Anomaly detection:** "This electric bill is 40% higher than usual"
- **Auto-tagging:** Learn user's tagging patterns
- **Receipt matching:** Link receipts to bank transactions
- **Expense tracking:** Category-based spending analysis

### 14.2 Integrations

- **Accounting software:** QuickBooks, FreshBooks, Wave
- **Cloud storage:** Dropbox, Google Drive, OneDrive
- **Email:** Auto-forward receipts to app email address
- **Smart home:** "Alexa, scan my mail"
- **Apple Watch:** Payment reminders on wrist

### 14.3 Advanced Features

- **Multi-language OCR:** Support 50+ languages
- **Batch scanning:** Scan entire stack at once
- **Document editing:** Crop, rotate, adjust brightness
- **Templates:** Custom categories per user
- **Sharing:** Share specific scans with family/accountant
- **Archive search:** Full-text search across all scans
- **Tax helper:** Auto-generate tax documents

### 14.4 Platform Expansion

- **Android app:** After iOS proven
- **Web app:** Access from desktop
- **iPad optimization:** Split-view for power users
- **Mac app:** Scan with Mac webcam or import

---

## 15. Legal & Compliance

### 15.1 Required Legal Pages

- **Privacy Policy:** Data collection, usage, sharing
- **Terms of Service:** User responsibilities, liability
- **EULA:** End User License Agreement
- **Cookie Policy:** If using web portal

### 15.2 Compliance Considerations

**GDPR (if serving EU users):**
- Right to access data
- Right to deletion
- Right to data portability
- Consent management

**CCPA (California):**
- Disclosure of data collection
- Opt-out of data sale (not applicable)
- Right to deletion

**Financial Data:**
- PCI DSS compliance (if processing payments)
- Secure storage of financial information
- Regular security audits

### 15.3 Content Policy

**Prohibited Uses:**
- Scanning copyrighted materials
- Processing illegal documents
- Violating third-party rights
- Spam or abuse

---

## 16. Support & Documentation

### 16.1 User Documentation

**Getting Started Guide:**
1. Download app from App Store
2. Create account
3. Grant camera permissions
4. Scan your first document
5. Review AI analysis
6. Set up calendar reminders

**FAQs:**
- How accurate is the OCR?
- What happens to my images?
- Can I access from multiple devices?
- How do I delete my data?
- What's included in Premium?

### 16.2 Support Channels

- **In-app:** Help button in settings
- **Email:** support@mailscanai.com
- **FAQ/Knowledge base:** Website
- **Social media:** Twitter/Facebook for updates
- **Community:** Discord/Reddit (if grows)

### 16.3 Developer Documentation

- API documentation
- Integration guides
- SDK for third-party apps
- Webhook documentation

---

## 17. Launch Checklist

### Pre-Launch (2-3 weeks before)

- [ ] App Store Connect setup
- [ ] Screenshots & preview video
- [ ] App description & keywords
- [ ] Privacy policy published
- [ ] Terms of service published
- [ ] Support email setup
- [ ] Website/landing page live
- [ ] TestFlight beta testing (50+ users)
- [ ] Bug fixes from beta feedback
- [ ] Performance optimization
- [ ] Analytics configured
- [ ] Crash reporting setup

### Launch Day

- [ ] Submit to App Store
- [ ] Monitor submission status
- [ ] Prepare social media posts
- [ ] Email beta testers
- [ ] Post on Product Hunt
- [ ] Post on Reddit (r/productivity, r/apps)
- [ ] Monitor server load
- [ ] Watch for crashes/bugs

### Post-Launch (First Week)

- [ ] Respond to all reviews
- [ ] Monitor analytics daily
- [ ] Fix critical bugs immediately
- [ ] Gather user feedback
- [ ] Plan first update
- [ ] Write blog post about launch

### Post-Launch (First Month)

- [ ] Release bug fix update
- [ ] Analyze user behavior
- [ ] Optimize onboarding based on data
- [ ] Plan feature roadmap
- [ ] Start marketing campaigns
- [ ] Reach out for press coverage

---

## 18. Success Metrics

### Short-term (3 months)

- **Downloads:** 5,000+
- **Active users:** 2,000+
- **Scans:** 50,000+
- **Retention (D30):** 30%+
- **App Store rating:** 4.5+
- **Crash-free rate:** 99.5%+

### Medium-term (6 months)

- **Downloads:** 15,000+
- **Paid users:** 300+
- **MRR:** $1,500+
- **Retention (D30):** 40%+
- **User feedback:** 100+ positive reviews

### Long-term (12 months)

- **Downloads:** 50,000+
- **Paid users:** 1,000+
- **MRR:** $5,000+
- **Retention (D30):** 45%+
- **Break-even or profitable**

---

## 19. Risk Mitigation

### Technical Risks

**OCR Accuracy:**
- Risk: Poor quality scans → bad text extraction
- Mitigation: Guide users on best practices, allow manual corrections

**LLM Costs:**
- Risk: Unexpected spike in usage → high API costs
- Mitigation: Rate limiting, caching, usage caps on free tier

**Storage Growth:**
- Risk: Users accumulate too much data
- Mitigation: Auto-cleanup, compression, storage limits

### Business Risks

**Low Conversion:**
- Risk: Users don't upgrade to Premium
- Mitigation: Compelling free tier limits, clear value proposition

**Competition:**
- Risk: Larger competitor copies idea
- Mitigation: Fast iteration, superior UX, community building

**User Privacy Concerns:**
- Risk: Users worried about data security
- Mitigation: Clear privacy policy, local-first architecture, transparency

---

## 20. Next Steps

### Immediate Actions

1. **Validate the idea:**
   - Create landing page
   - Collect emails from interested users
   - Run small Facebook ads test ($50)

2. **Set up development environment:**
   - Create Xcode project
   - Set up Firebase account
   - Get Claude API key
   - Create GitHub repo

3. **Build MVP:**
   - Week 1-2: Basic scanning + OCR
   - Week 3-4: LLM integration + storage
   - Week 5-6: UI polish + TestFlight

4. **Test with real users:**
   - Friends/family beta
   - Collect feedback
   - Iterate quickly

5. **Launch:**
   - Submit to App Store
   - Soft launch to small audience
   - Gather data
   - Optimize
   - Scale marketing

---

## Conclusion

This iOS mail scanning app addresses a real pain point with a pragmatic, cost-effective architecture:

**Key Advantages:**
- ✅ **Backend-driven features** = instant updates, no App Store delays
- ✅ Local-first = privacy + zero storage costs
- ✅ On-device OCR = free text extraction
- ✅ Smart AI analysis = genuine value
- ✅ iOS integrations = seamless UX
- ✅ Low operating costs = sustainable business
- ✅ **A/B testing built-in** = data-driven optimization
- ✅ **Feature flags** = gradual rollouts & instant rollbacks

**Success Factors:**
- Simple, intuitive UX
- Fast, reliable performance
- Clear privacy promise
- Genuine AI value (not gimmick)
- Fair pricing
- **Rapid iteration without app updates** 🔥

**Backend-Driven Advantage:**
The most critical architectural decision is that **ALL business logic lives in the backend**:
- Change categorization rules → No app update needed
- Improve spam detection → No app update needed
- Adjust reminder timing → No app update needed
- Update UI text → No app update needed
- A/B test features → No app update needed
- Fix bugs in logic → No app update needed

This means you can iterate **10x faster** than competitors who hardcode logic in their apps.

**Bootstrap-Friendly:**
- MVP buildable in 4-6 weeks
- Low initial costs (~$200/month)
- No expensive infrastructure
- Can self-fund from early revenue
- **Iterate and improve without waiting for App Store reviews**

The market exists, the technology is accessible, the timing is right, and the **backend-driven architecture gives you a massive competitive advantage**. Good luck building! 🚀

---

## Appendix A: Useful Resources

### iOS Development
- [Apple Developer Documentation](https://developer.apple.com/documentation/)
- [SwiftUI Tutorials](https://developer.apple.com/tutorials/swiftui)
- [Vision Framework Guide](https://developer.apple.com/documentation/vision)
- [EventKit Programming Guide](https://developer.apple.com/documentation/eventkit)

### Backend
- [Firebase Documentation](https://firebase.google.com/docs)
- [Claude API Reference](https://docs.anthropic.com/)
- [Node.js Best Practices](https://github.com/goldbergyoni/nodebestpractices)

### Design
- [Apple Human Interface Guidelines](https://developer.apple.com/design/human-interface-guidelines/)
- [SF Symbols](https://developer.apple.com/sf-symbols/)
- [Figma iOS UI Kit](https://www.figma.com/community/file/1248375255495415511)

### Business
- [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [App Store Connect](https://appstoreconnect.apple.com/)
- [TestFlight](https://developer.apple.com/testflight/)

---

**Document Version:** 1.0  
**Last Updated:** November 20, 2024  
**Author:** Implementation Guide for MailScan AI
