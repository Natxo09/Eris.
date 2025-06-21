//
//  OnboardingDownloadView.swift
//  Eris.
//
//  Created by Ignacio Palacio on 19/6/25.
//

import SwiftUI
import MLXLMCommon

struct OnboardingDownloadView: View {
    @Binding var showOnboarding: Bool
    let selectedModel: ModelConfiguration
    
    @StateObject private var modelManager = ModelManager.shared
    @State private var downloadProgress: Double = 0.0
    @State private var downloadState: DownloadState = .ready
    @State private var errorMessage: String?
    @State private var showCompatibilityWarning = false
    
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
                if downloadState == .ready {
                    let compatibility = selectedModel.compatibilityForDevice()
                    if compatibility == .risky || compatibility == .notRecommended {
                        HStack(spacing: 8) {
                            Image(systemName: selectedModel.compatibilityIcon)
                                .foregroundColor(selectedModel.compatibilityColor)
                            Text(selectedModel.compatibilityDescription)
                                .font(.caption)
                                .foregroundColor(selectedModel.compatibilityColor)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selectedModel.compatibilityColor.opacity(0.1))
                        .cornerRadius(8)
                        .padding(.top, 8)
                    }
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
                        let compatibility = selectedModel.compatibilityForDevice()
                        if compatibility == .notRecommended {
                            showCompatibilityWarning = true
                        } else {
                            startDownload()
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
            let compatibility = selectedModel.compatibilityForDevice()
            if downloadState == .ready {
                if compatibility == .risky || compatibility == .notRecommended {
                    // Don't auto-start for risky models, let user decide
                } else {
                    startDownload()
                }
            }
        }
        .alert("Compatibility Warning", isPresented: $showCompatibilityWarning) {
            Button("Download Anyway", role: .destructive) {
                startDownload()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            let compatibility = selectedModel.compatibilityForDevice()
            if compatibility == .notRecommended {
                Text("⚠️ WARNING: High Crash Risk!\n\nThis model requires more memory than your \(DeviceUtils.deviceDescription) can reliably provide. The app will likely crash when trying to load this model.\n\nWe strongly recommend going back and selecting a smaller model (0.5B or 1B).")
            } else {
                Text("⚠️ This model may cause issues on your \(DeviceUtils.deviceDescription).\n\nYou might experience crashes or very slow performance. Make sure to close all other apps before proceeding.\n\nConsider selecting a smaller model for better stability.")
            }
        }
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
        let modelName = selectedModel.name
            .replacingOccurrences(of: "mlx-community/", with: "")
            .replacingOccurrences(of: "-", with: " ")
        
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
                try await modelManager.downloadModel(selectedModel) { progress in
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
                    errorMessage = error.localizedDescription
                    HapticManager.shared.error()
                }
            }
        }
    }
    
    private func completeOnboarding() {
        // Set the downloaded model as active
        modelManager.setActiveModel(selectedModel)
        
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
            selectedModel: ModelConfiguration.llama3_2_1B
        )
    }
}