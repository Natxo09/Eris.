//
//  OnboardingDownloadView.swift
//  Eris.
//
//  Created by Ignacio Palacio on 19/6/25.
//

import SwiftUI

struct OnboardingDownloadView: View {
    @Binding var showOnboarding: Bool
    let selectedModel: AIModel

    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var downloadProgress: Double = 0.0
    @State private var downloadState: DownloadState = .ready
    @State private var errorMessage: String?
    @State private var showCompatibilityWarning = false
    @State private var showCellularWarning = false

    private var selectedAIModel: AIModel? {
        selectedModel
    }
    
    enum DownloadState {
        case ready
        case downloading
        case completed
        case failed
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            
            // Progress animation
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 150, height: 150)
                
                Circle()
                    .trim(from: 0, to: downloadProgress)
                    .stroke(
                        Color.primary,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 150, height: 150)
                    .rotationEffect(Angle(degrees: -90))
                    .animation(.easeInOut, value: downloadProgress)
                
                VStack(spacing: 8) {
                    switch downloadState {
                    case .ready:
                        Image(systemName: "arrow.down.circle")
                            .font(.system(size: 40))
                            .foregroundColor(.primary)
                    case .downloading:
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.title)
                            .fontWeight(.bold)
                    case .completed:
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)
                    case .failed:
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.red)
                    }
                }
            }
            .padding(.bottom, 40)
            
            // Status text
            VStack(spacing: 12) {
                Text(statusTitle)
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text(statusDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
                
                // Compatibility warning
                if downloadState == .ready, let aiModel = selectedAIModel {
                    let compatibility = AIModelsRegistry.shared.compatibilityForModel(aiModel)
                    if compatibility == .risky || compatibility == .notRecommended {
                        HStack(spacing: 8) {
                            Image(systemName: compatibility.icon)
                                .foregroundColor(compatibility.color)
                            Text(compatibility.description)
                                .font(.caption)
                                .foregroundColor(compatibility.color)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(compatibility.color.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.top, 8)
                    }
                }
                
                // Show network status if on cellular
                if downloadState == .ready && networkMonitor.connectionType == .cellular {
                    HStack(spacing: 8) {
                        Image(systemName: "antenna.radiowaves.left.and.right")
                            .foregroundColor(.orange)
                        Text("Cellular connection detected")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.top, 8)
                }
                
                if let error = errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                        .padding(.horizontal, 40)
                        .padding(.top, 8)
                }
            }
            
            Spacer()
            
            // Action button
            VStack {
                switch downloadState {
                case .ready:
                    Button(action: {
                        HapticManager.shared.buttonTap()
                        
                        // Check cellular first
                        if networkMonitor.connectionType == .cellular {
                            showCellularWarning = true
                        } else {
                            // Then check compatibility
                            if let aiModel = selectedAIModel {
                                let compatibility = AIModelsRegistry.shared.compatibilityForModel(aiModel)
                                if compatibility == .notRecommended {
                                    showCompatibilityWarning = true
                                } else {
                                    startDownload()
                                }
                            } else {
                                startDownload()
                            }
                        }
                    }) {
                        Text("Start Download")
                            .font(.headline)
                            .foregroundColor(Color(UIColor.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(UIColor.label))
                            .cornerRadius(16)
                    }
                    
                case .downloading:
                    Button(action: {}) {
                        HStack {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: Color(UIColor.systemBackground)))
                                .scaleEffect(0.8)
                            Text("Downloading...")
                                .font(.headline)
                                .foregroundColor(Color(UIColor.systemBackground))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(Color.gray)
                        .cornerRadius(16)
                    }
                    .disabled(true)
                    
                case .completed:
                    Button(action: {
                        HapticManager.shared.modelDownloadComplete()
                        completeOnboarding()
                    }) {
                        Text("Start Chatting")
                            .font(.headline)
                            .foregroundColor(Color(UIColor.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color(UIColor.label))
                            .cornerRadius(16)
                    }
                    
                case .failed:
                    Button(action: {
                        HapticManager.shared.warning()
                        startDownload()
                    }) {
                        Text("Retry Download")
                            .font(.headline)
                            .foregroundColor(Color(UIColor.systemBackground))
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(Color.gray)
                            .cornerRadius(16)
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 30)
        }
        .navigationBarBackButtonHidden(downloadState == .downloading || downloadState == .completed)
        .onAppear {
            // Check compatibility before auto-starting
            if let aiModel = selectedAIModel {
                let compatibility = AIModelsRegistry.shared.compatibilityForModel(aiModel)
                if downloadState == .ready {
                    if compatibility == .risky || compatibility == .notRecommended {
                        // Don't auto-start for risky models, let user decide
                    } else {
                        startDownload()
                    }
                }
            }
        }
        .alert("Compatibility Warning", isPresented: $showCompatibilityWarning) {
            Button("Download Anyway", role: .destructive) {
                startDownload()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            if let aiModel = selectedAIModel {
                let compatibility = AIModelsRegistry.shared.compatibilityForModel(aiModel)
                if compatibility == .notRecommended {
                    Text("⚠️ WARNING: High Crash Risk!\n\nThis model requires more memory (~\(aiModel.estimatedRAMUsage)MB) than your \(DeviceUtils.deviceDescription) can reliably provide. The app will likely crash when trying to load this model.\n\nWe strongly recommend going back and selecting a smaller model (0.5B or 1B).")
                } else {
                    Text("⚠️ This model may cause issues on your \(DeviceUtils.deviceDescription).\n\nIt requires ~\(aiModel.estimatedRAMUsage)MB of RAM. You might experience crashes or very slow performance. Make sure to close all other apps before proceeding.\n\nConsider selecting a smaller model for better stability.")
                }
            }
        }
        .alert("Wi-Fi Required", isPresented: $showCellularWarning) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("⚠️ Wi-Fi Required for Downloads\n\nThe MLX framework doesn't support downloading models over cellular connections. This is a technical limitation of the framework.\n\nPlease connect to Wi-Fi to download the model. After downloading, you can use Eris with 4G, 5G, or even offline - you only need Wi-Fi for the initial download.")
        }
    }
    
    private var modelSize: String {
        if let aiModel = selectedAIModel {
            let sizeInGB = Double(aiModel.estimatedRAMUsage) / 1024.0
            return String(format: "%.1f GB", sizeInGB)
        }
        return "Size unknown"
    }
    
    private var statusTitle: String {
        switch downloadState {
        case .ready:
            return "Ready to Download"
        case .downloading:
            return "Downloading Model"
        case .completed:
            return "Download Complete!"
        case .failed:
            return "Download Failed"
        }
    }
    
    private var statusDescription: String {
        let modelName = selectedAIModel?.displayName ?? "model"
        
        switch downloadState {
        case .ready:
            return "You're about to download \(modelName)"
        case .downloading:
            return "Please wait while we download \(modelName). This may take a few minutes."
        case .completed:
            return "Successfully downloaded \(modelName). You're ready to start chatting!"
        case .failed:
            return "Failed to download \(modelName). Please check your connection and try again."
        }
    }
    
    private func startDownload() {
        downloadState = .downloading
        downloadProgress = 0.0
        errorMessage = nil
        
        Task {
            do {
                try await modelManager.download(selectedModel) { progress in
                    Task { @MainActor in
                        self.downloadProgress = progress.fractionCompleted
                    }
                }
                
                await MainActor.run {
                    downloadState = .completed
                    // Vibrate on completion
                    HapticManager.shared.modelDownloadComplete()
                }
            } catch {
                await MainActor.run {
                    downloadState = .failed
                    
                    // Provide more specific error messages
                    if let modelError = error as? ModelDownloadError {
                        errorMessage = modelError.localizedDescription
                    } else {
                        errorMessage = error.localizedDescription
                    }
                    
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func completeOnboarding() {
        // Set the downloaded model as active
        modelManager.setActive(selectedModel)
        
        // Mark onboarding as complete
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        
        // Dismiss onboarding
        showOnboarding = false
    }
}

#Preview {
    NavigationStack {
        OnboardingDownloadView(
            showOnboarding: .constant(true),
            selectedModel: AIModelsRegistry.shared.defaultModel
        )
    }
}