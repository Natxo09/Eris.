//
//  OnboardingModelSetupView.swift
//  Eris.
//
//  Created by Ignacio Palacio on 19/6/25.
//

import SwiftUI
import MLXLMCommon

struct OnboardingModelSetupView: View {
    @Binding var showOnboarding: Bool
    @StateObject private var modelManager = ModelManager.shared
    @State private var selectedAIModel: AIModel?
    @State private var showCompatibilityWarning = false
    
    private let registry = AIModelsRegistry.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 20) {
                Image(systemName: "arrow.down.circle.dotted")
                    .font(.system(size: 60))
                    .foregroundStyle(.primary)
                
                VStack(spacing: 8) {
                    Text("Choose Your Model")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Select an AI model to download and start chatting")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 40)
                }
            }
            .padding(.top, 40)
            .padding(.bottom, 30)
            
            // Device compatibility check
            if !DeviceUtils.canRunMLX {
                DeviceCompatibilityCard()
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
            }
            
            // Models list
            ScrollView {
                VStack(spacing: 12) {
                    ForEach(sortedModels()) { aiModel in
                        ModelSelectionCard(
                            aiModel: aiModel,
                            isSelected: selectedAIModel?.id == aiModel.id,
                            isDownloaded: modelManager.isModelDownloaded(aiModel.configuration),
                            isRecommended: aiModel.id == getRecommendedModelForDevice().id && registry.compatibilityForModel(aiModel) == .recommended
                        ) {
                            HapticManager.shared.selection()
                            selectedAIModel = aiModel
                        }
                        .disabled(!DeviceUtils.canRunMLX)
                    }
                }
                .padding(.horizontal, 20)
            }
            
            Spacer()
            
            // Continue button
            if DeviceUtils.canRunMLX {
                NavigationLink(
                    destination: OnboardingDownloadView(
                        showOnboarding: $showOnboarding,
                        selectedModel: selectedAIModel?.configuration ?? registry.defaultModel.configuration
                    )
                ) {
                    Text("Download Model")
                        .font(.headline)
                        .foregroundColor(Color(UIColor.systemBackground))
                        .frame(maxWidth: .infinity)
                        .frame(height: 56)
                        .background(selectedAIModel != nil ? Color(UIColor.label) : Color.gray)
                        .cornerRadius(16)
                }
                .disabled(selectedAIModel == nil)
                .simultaneousGesture(TapGesture().onEnded { _ in
                    if selectedAIModel != nil {
                        HapticManager.shared.buttonTap()
                    }
                })
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            // Auto-select best model for device
            if selectedAIModel == nil {
                selectedAIModel = getRecommendedModelForDevice()
            }
        }
    }
    
    private func getRecommendedModelForDevice() -> AIModel {
        let recommended = registry.recommendedModelsForDevice()
        return recommended.first ?? registry.defaultModel
    }
    
    private func sortedModels() -> [AIModel] {
        let recommendedModel = getRecommendedModelForDevice()
        
        return registry.allModels.sorted { model1, model2 in
            // Put recommended model first
            if model1.id == recommendedModel.id { return true }
            if model2.id == recommendedModel.id { return false }
            
            // Then sort by compatibility
            let compat1 = registry.compatibilityForModel(model1)
            let compat2 = registry.compatibilityForModel(model2)
            
            if compat1 == .recommended && compat2 != .recommended { return true }
            if compat2 == .recommended && compat1 != .recommended { return false }
            
            if compat1 == .compatible && compat2 == .risky { return true }
            if compat1 == .compatible && compat2 == .notRecommended { return true }
            
            if compat1 == .risky && compat2 == .notRecommended { return true }
            
            // Finally sort by RAM usage
            return model1.estimatedRAMUsage < model2.estimatedRAMUsage
        }
    }
}

struct DeviceCompatibilityCard: View {
    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text("Device Compatibility")
                    .font(.headline)
                Spacer()
            }
            
            Text(DeviceUtils.compatibilityMessage)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ModelSelectionCard: View {
    let aiModel: AIModel
    let isSelected: Bool
    let isDownloaded: Bool
    let isRecommended: Bool
    let action: () -> Void
    
    private let registry = AIModelsRegistry.shared
    
    var modelSize: String {
        let sizeInGB = Double(aiModel.estimatedRAMUsage) / 1024.0
        return String(format: "%.1f GB", sizeInGB)
    }
    
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(aiModel.displayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            if isRecommended {
                                Text("RECOMMENDED")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.gray)
                                    .cornerRadius(4)
                            }
                            
                            // Category badges
                            if aiModel.category == .reasoning {
                                Text("REASONING")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.purple.opacity(0.7))
                                    .cornerRadius(4)
                            } else if aiModel.category == .code {
                                Text("CODE")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue.opacity(0.7))
                                    .cornerRadius(4)
                            }

                            // Legacy badge
                            if aiModel.isLegacy {
                                Text("LEGACY")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.7))
                                    .cornerRadius(4)
                            }
                            
                            Spacer()
                        }
                        
                        Text(aiModel.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .lineLimit(2)
                        
                        // Compatibility indicator
                        let compatibility = registry.compatibilityForModel(aiModel)
                        HStack(spacing: 4) {
                            Image(systemName: compatibility.icon)
                                .font(.caption)
                                .foregroundColor(compatibility.color)
                            Text(compatibility.description)
                                .font(.caption)
                                .foregroundColor(compatibility.color)
                            Spacer()
                        }
                        .padding(.top, 2)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        if isDownloaded {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.primary)
                        } else {
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(isSelected ? .primary : .gray)
                        }
                        
                        Text(modelSize)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                if isDownloaded {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.primary)
                            .font(.caption)
                        Text("Already downloaded")
                            .font(.caption)
                            .foregroundColor(.primary)
                        Spacer()
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 12)
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(UIColor.secondarySystemBackground))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color.primary : Color.clear, lineWidth: 2)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        OnboardingModelSetupView(showOnboarding: .constant(true))
    }
}