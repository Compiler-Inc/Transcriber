//  Copyright 2025 Compiler, Inc. All rights reserved.

import Speech

/// Manages custom language model preparation and configuration
public actor LanguageModelManager {
    private var hasBuiltLm = false
    private var customLmTask: Task<Void, Error>?
    private var lmConfiguration: SFSpeechLanguageModel.Configuration?
    
    public init(modelInfo: LanguageModelInfo?) {
        if let modelInfo = modelInfo {
            self.lmConfiguration = SFSpeechLanguageModel.Configuration(languageModel: modelInfo.url)
            Task {
                await self.prepareCustomModel(modelURL: modelInfo.url, appIdentifier: modelInfo.appIdentifier)
            }
        }
    }
    
    private func prepareCustomModel(modelURL: URL, appIdentifier: String) async {
        guard let lmConfiguration = lmConfiguration else { return }
        
        customLmTask = Task.detached {
            do {
                try await SFSpeechLanguageModel.prepareCustomLanguageModel(
                    for: modelURL,
                    clientIdentifier: appIdentifier,
                    configuration: lmConfiguration
                )
                await self.markModelAsBuilt()
            } catch {
                throw TranscriberError.customLanguageModelFailure(error)
            }
        }
    }

    private func markModelAsBuilt() {
        hasBuiltLm = true
    }
    
    /// Wait for model preparation to complete if needed
    public func waitForModel() async throws {
        if let customLmTask = customLmTask, !hasBuiltLm {
            try await customLmTask.value
        }
    }
    
    /// Get the current language model configuration
    /// - Returns: The prepared language model configuration, if available
    public func getConfiguration() -> SFSpeechLanguageModel.Configuration? {
        return lmConfiguration
    }
}
