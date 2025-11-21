# MailScan AI - Design & Development Plan

This document outlines the phased development plan for the MailScan AI iOS application. The approach is structured to deliver functionality incrementally, starting with a robust local-first client and progressively integrating backend services and AI features.

---

## Phase 1: iOS Client - Core Scanning & Local Processing

**Goal:** Build a standalone iOS application that can scan documents, perform on-device OCR, and store all data locally. This phase focuses on delivering the core user experience without any backend dependency.

**Key Components:**
- **UI:** SwiftUI
- **Scanning:** VisionKit
- **OCR:** Vision Framework
- **Storage:** FileManager (for images/JSON), CoreData/SwiftData (for metadata)

### Steps:

1.  **Project Setup:**
    -   Initialize a new Xcode project using SwiftUI and the Swift language.
    -   Establish the folder structure as defined in the implementation document (`Core/Services`, `Features/Scanner`, etc.).

2.  **Document Scanning UI:**
    -   Implement a `ScannerView` that integrates `VisionKit`'s document camera.
    -   Ensure it provides a clean, perspective-corrected image output.

3.  **Local Storage Layer:**
    -   Create a `StorageService` to handle all local file operations.
    -   **Image Persistence:** Upon a successful scan, save the captured image directly to the device in a `/Documents/Scans/` directory.
    -   **OCR & Analysis Persistence:** Create directories for `/Documents/OCR/` and `/Documents/Analysis/`.

4.  **On-Device OCR Service:**
    -   Develop an `OCRService` that uses the `Vision` framework.
    -   This service will take a local image path, extract the text content, and calculate a confidence score.
    -   The extracted text will be saved as a structured JSON file in the `/Documents/OCR/` directory.

5.  **Core UI Implementation:**
    -   **Home View:** Build a `HomeView` to display a grid or list of all locally scanned documents by reading from the `/Documents/Scans/` directory.
    -   **Detail View:** Create a `ScanDetailView` that displays the full-sized image and the corresponding OCR text read from the local JSON file.

---

## Phase 2: Backend & Database - Metadata Sync

**Goal:** Establish the backend infrastructure and database to sync non-sensitive metadata from the iOS client. This phase prepares the foundation for AI analysis and multi-device capabilities.

**Key Components:**
- **Server:** Python (FastAPI)
- **Database:** PostgreSQL
- **Architecture:** RESTful API

### Steps:

1.  **Backend Project Setup:**
    -   Initialize a new FastAPI project.
    -   Structure the project with clear separation for API routes, services, and database models.

2.  **Database Schema Definition:**
    -   Implement the database schema in PostgreSQL based on the `Users` and `Scans` collections defined in the implementation document.
    -   Crucially, the `scans` table will only contain metadata fields (`scanId`, `userId`, `localFileName`, `timestamp`, `category`, `dueDate`, etc.) and **will not** store images or full OCR text.

3.  **API Endpoint Development:**
    -   **`POST /api/scans/create`**: This endpoint will be called by the iOS app immediately after a scan is saved locally. It will receive and store the initial scan metadata.
    -   **`PATCH /api/scans/{scanId}`**: This endpoint will be used to update the scan record with metadata from the on-device OCR process (e.g., `wordCount`, `ocrConfidence`).

4.  **iOS Client Integration:**
    -   Implement a `NetworkService` in the iOS app.
    -   Integrate this service to call the backend endpoints after local scan and OCR operations are successfully completed.

---

## Phase 3: LLM Integration & AI Analysis

**Goal:** Implement the core AI feature, allowing users to optionally send extracted text to the backend for analysis by an LLM.

**Key Components:**
- **LLM:** Claude API
- **Backend:** New `Analysis Service` and business rules engine.
- **iOS:** UI for AI opt-in and display of analysis results.

### Steps:

1.  **iOS - AI Opt-In UI:**
    -   In the `ScanDetailView`, add the "Analyze with AI" user interface as specified in the architecture diagrams.
    -   This includes showing a text preview, the cost in credits, and clear user choices.

2.  **Backend - Analysis Endpoint (`POST /api/analyze`):**
    -   Create the endpoint to receive the `scanId` and the full `extractedText` from the client.
    -   Develop an `Analysis Service` that:
        -   Loads dynamic LLM prompts from the database.
        -   Constructs the request and calls the Claude API.
        -   Parses the structured JSON response from the LLM.
        -   Applies business rules (e.g., spam detection) to the results.
        -   Returns a final, structured analysis object to the iOS client, including `actions` to be performed on the client.

3.  **iOS - Handling Analysis Results:**
    -   Upon receiving the analysis from the backend, save it as a JSON file in the local `/Documents/Analysis/` directory.
    -   Update the `ScanDetailView` to display the new, rich information (category, importance, summary, due dates).

4.  **iOS - Client-Side Actions:**
    -   Implement handlers for the `actions` array returned by the backend.
    -   Create a `CalendarService` and `ReminderService` using `EventKit` to create calendar events and reminders as instructed by the backend.

5.  **Backend - Final Metadata Update:**
    -   After a successful analysis, update the `scans` record in the database with the new metadata (`category`, `dueDate`, `importance`, `llmAnalyzed: true`).

---

## Phase 4: Settings & Feature Control

**Goal:** Build the settings section and implement the backend-driven feature control system, which is a cornerstone of the app's architecture.

**Key Components:**
- **Backend:** Configuration service and feature flag system.
- **iOS:** Settings UI and a `FeatureManager` to consume the backend configuration.

### Steps:

1.  **Backend - Configuration Service:**
    -   Create a `GET /api/config` endpoint that returns all necessary configuration data to the client.
    -   **Feature Flags:** Store feature flags in the database and serve them through the config endpoint.
    -   **Dynamic Categories:** Store category definitions (name, icon, color, rules) in the database and serve them.
    -   **UI Strings:** Store UI text in the database for dynamic updates and A/B testing.

2.  **iOS - Settings UI:**
    -   Develop the `SettingsView` in SwiftUI.
    -   Include sections for account management, preferences, privacy, and subscription status.

3.  **iOS - Dynamic Configuration Integration:**
    -   Create a `FeatureManager` that fetches the remote config on app launch.
    -   Refactor UI components (e.g., the home screen filter bar) to be built dynamically from the fetched category data instead of being hardcoded.
    -   Use the `FeatureManager` to conditionally render features and UI elements throughout the app.

4.  **Privacy Features:**
    -   Implement the "Export All Data" function, which will zip the local `Scans`, `OCR`, and `Analysis` directories along with a metadata summary from the backend.
    -   Implement the "Delete All Data" function, which will wipe all local files and call a backend endpoint to delete all user-related metadata.
