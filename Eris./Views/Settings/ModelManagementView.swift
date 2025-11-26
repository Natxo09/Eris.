//
//  ModelManagementView.swift
//  Eris.
//
//  Created by Ignacio Palacio on 19/6/25.
//

import SwiftUI
import MLXLMCommon

struct ModelManagementView: View {
    @StateObject private var modelManager = ModelManager.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var selectedModel: ModelConfiguration?
    @State private var showCompatibilityWarning = false
    @State private var modelToDownload: AIModel?
    @State private var showCellularWarning = false
    @State private var cellularDownloadModel: AIModel?
    
    private let registry = AIModelsRegistry.shared
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                VStack(spacing: 20) {
                    Image(systemName: "cpu")
                        .font(.system(size: 60))
                        .foregroundStyle(.primary)
                    
                    VStack(spacing: 8) {
                        Text("AI Models")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Download and manage AI models for offline use")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                }
                .padding(.top, 20)
                .padding(.bottom, 10)
                
                // Network status indicator
                if networkMonitor.isConnected {
                    HStack(spacing: 8) {
                        Image(systemName: networkMonitor.connectionType.icon)
                            .foregroundColor(networkMonitor.connectionType.color)
                        Text("Connected via \(networkMonitor.connectionType.displayName)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.tertiarySystemBackground))
                    .cornerRadius(8)
                }
                
                // Device compatibility check
                if DeviceUtils.isSimulator {
                    DeviceCompatibilityWarning()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                } else if !DeviceUtils.canRunMLX {
                    DeviceCompatibilityCard()
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                }
                
                // Models list by category
                VStack(spacing: 20) {
                    ForEach(ModelCategory.allCases, id: \.self) { category in
                        VStack(alignment: .leading, spacing: 12) {
                            // Category header
                            HStack(spacing: 8) {
                                Image(systemName: category.icon)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text(category.rawValue)
                                    .font(.headline)
                                    .foregroundColor(.primary)
                            }
                            .padding(.horizontal, 20)
                            
                            Text(category.description)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .padding(.horizontal, 20)
                            
                            // Models in category
                            ForEach(registry.modelsForCategory(category)) { aiModel in
                                ModelCard(
                                    aiModel: aiModel,
                                    isSelected: modelManager.activeModel?.name == aiModel.configuration.name,
                                    isDownloaded: modelManager.isModelDownloaded(aiModel.configuration),
                                    isDownloading: modelManager.downloadingModels.contains(aiModel.configuration.name),
                                    downloadProgress: modelManager.downloadProgress[aiModel.configuration.name] ?? 0.0,
                                    hasActiveDownload: !modelManager.downloadingModels.isEmpty,
                                    onSelect: {
                                        HapticManager.shared.selection()
                                        if modelManager.isModelDownloaded(aiModel.configuration) {
                                            modelManager.setActiveModel(aiModel.configuration)
                                        }
                                    },
                                    onDownload: {
                                        // Don't allow download if another is in progress
                                        guard modelManager.downloadingModels.isEmpty else {
                                            HapticManager.shared.warning()
                                            return
                                        }
                                        
                                        HapticManager.shared.buttonTap()
                                        
                                        // Check for cellular warning first
                                        if networkMonitor.connectionType == .cellular {
                                            cellularDownloadModel = aiModel
                                            showCellularWarning = true
                                        } else {
                                            // Then check device compatibility
                                            let compatibility = registry.compatibilityForModel(aiModel)
                                            if compatibility == .risky || compatibility == .notRecommended {
                                                modelToDownload = aiModel
                                                showCompatibilityWarning = true
                                            } else {
                                                downloadModel(aiModel.configuration)
                                            }
                                        }
                                    },
                                    onDelete: {
                                        HapticManager.shared.warning()
                                        deleteModel(aiModel.configuration)
                                    }
                                )
                                .disabled(DeviceUtils.isSimulator || !DeviceUtils.canRunMLX)
                                .padding(.horizontal, 20)
                            }
                        }
                    }
                }
                .padding(.bottom, 30)
            }
        }
        .background(Color(UIColor.systemGroupedBackground))
        .navigationTitle("Model Management")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            selectedModel = modelManager.activeModel
        }
        .alert("Compatibility Warning", isPresented: $showCompatibilityWarning) {
            Button("Download Anyway", role: .destructive) {
                if let aiModel = modelToDownload {
                    downloadModel(aiModel.configuration)
                }
            }
            Button("Cancel", role: .cancel) {
                modelToDownload = nil
            }
        } message: {
            if let aiModel = modelToDownload {
                let compatibility = registry.compatibilityForModel(aiModel)
                if compatibility == .notRecommended {
                    Text("⚠️ This model has a HIGH RISK of crashing on your \(DeviceUtils.deviceDescription).\n\nIt requires more memory (~\(aiModel.estimatedRAMUsage)MB) than your device typically has available. We strongly recommend choosing a smaller model.\n\nIf you proceed, the app will likely crash when trying to use this model.")
                } else {
                    Text("⚠️ This model may experience issues on your \(DeviceUtils.deviceDescription).\n\nIt requires ~\(aiModel.estimatedRAMUsage)MB of RAM. You might encounter crashes or slow performance. For best results, close all other apps before using.\n\nConsider trying a smaller model if you experience problems.")
                }
            }
        }
        .alert("Wi-Fi Required", isPresented: $showCellularWarning) {
            Button("OK") {
                cellularDownloadModel = nil
            }
        } message: {
            Text("⚠️ Important: Model downloads require Wi-Fi\n\nThe MLX framework used by this app doesn't support downloading models over cellular connections. This is a limitation of the framework, not the app.\n\nPlease connect to Wi-Fi to download models. Once downloaded, you can use the app with cellular data (4G/5G) or completely offline.")
        }
    }
    
    
    private func downloadModel(_ model: ModelConfiguration) {
        Task {
            do {
                try await modelManager.downloadModel(model) { progress in
                    // Progress is already being tracked in ModelManager
                }
                
                await MainActor.run {
                    HapticManager.shared.modelDownloadComplete()
                }
            } catch {
                await MainActor.run {
                    HapticManager.shared.error()
                }
                print("Download failed: \(error.localizedDescription)")
                
                // Show specific error message to user
                Task { @MainActor in
                    var errorMessage = "Download failed"
                    if let modelError = error as? ModelDownloadError {
                        errorMessage = modelError.localizedDescription
                    }
                    // You might want to show an alert here with the error message
                }
            }
        }
    }
    
    private func deleteModel(_ model: ModelConfiguration) {
        modelManager.deleteModel(model)
        if modelManager.activeModel?.name == model.name {
            // If deleting the active model, try to set another downloaded model as active
            if let firstAvailableModel = registry.allModels.first(where: { 
                $0.configuration.name != model.name && modelManager.isModelDownloaded($0.configuration) 
            }) {
                modelManager.setActiveModel(firstAvailableModel.configuration)
            }
            // If no other models are downloaded, activeModel will be cleared automatically
        }
    }
}

struct DeviceCompatibilityWarning: View {
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
                Text("Simulator Detected")
                    .font(.headline)
                Spacer()
            }
            
            Text("MLX models require real Apple Silicon hardware. Please run this app on a physical device.")
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                
            VStack(alignment: .leading, spacing: 8) {
                Label("iPhone 11 or later", systemImage: "iphone")
                    .font(.caption)
                Label("iPad with A12 chip or later", systemImage: "ipad")
                    .font(.caption)
                Label("Mac with Apple Silicon", systemImage: "macbook")
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
}

struct ModelCard: View {
    let aiModel: AIModel
    let isSelected: Bool
    let isDownloaded: Bool
    let isDownloading: Bool
    let downloadProgress: Double
    let hasActiveDownload: Bool
    let onSelect: () -> Void
    let onDownload: () -> Void
    let onDelete: () -> Void
    
    private let registry = AIModelsRegistry.shared
    
    private var modelSize: String {
        let sizeInGB = Double(aiModel.estimatedRAMUsage) / 1024.0
        return String(format: "%.1f GB", sizeInGB)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            Button(action: onSelect) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 8) {
                            Text(aiModel.displayName)
                                .font(.headline)
                                .foregroundColor(.primary)
                            
                            // Parameters badge
                            Text(aiModel.parameterCount)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.secondary)
                            
                            // Quantization badge
                            Text(aiModel.quantization)
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.5))
                                .cornerRadius(4)
                            
                            if aiModel.id == registry.defaultModel.id {
                                Text("DEFAULT")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.blue)
                                    .cornerRadius(4)
                            }

                            if aiModel.isLegacy {
                                Text("LEGACY")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(Color.orange)
                                    .cornerRadius(4)
                            }
                        }
                        
                        Text(aiModel.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        
                        HStack(spacing: 12) {
                            // Storage size
                            HStack(spacing: 4) {
                                Image(systemName: "internaldrive")
                                    .font(.caption)
                                Text(modelSize)
                                    .font(.caption)
                            }
                            
                            // RAM usage
                            HStack(spacing: 4) {
                                Image(systemName: "memorychip")
                                    .font(.caption)
                                Text("~\(String(format: "%.1f", Double(aiModel.estimatedRAMUsage) / 1024.0))GB RAM")
                                    .font(.caption)
                            }
                        }
                        .foregroundColor(.secondary)
                        
                        // Warning for large models on iPhone
                        if aiModel.parameterCount.contains("7B") && UIDevice.current.userInterfaceIdiom == .phone {
                            HStack(spacing: 4) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.caption2)
                                Text("May run slowly on iPhone")
                                    .font(.caption2)
                            }
                            .foregroundColor(.orange)
                        }
                    }
                    
                    Spacer()
                    
                    if isDownloading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle())
                            .scaleEffect(0.8)
                    } else if isDownloaded {
                        HStack(spacing: 12) {
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.title2)
                                    .foregroundColor(.primary)
                            }
                            
                            Menu {
                                if !isSelected {
                                    Button(action: onSelect) {
                                        Label("Set as Active", systemImage: "checkmark.circle")
                                    }
                                }
                                Button(role: .destructive, action: onDelete) {
                                    Label("Delete Model", systemImage: "trash")
                                }
                            } label: {
                                Image(systemName: "ellipsis.circle")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                        }
                    } else {
                        Button(action: onDownload) {
                            Image(systemName: "arrow.down.circle.fill")
                                .font(.title2)
                                .foregroundColor(hasActiveDownload ? Color.gray : Color(UIColor.label))
                        }
                        .disabled(hasActiveDownload)
                    }
                }
                .padding()
                .contentShape(.rect)
            }
            .buttonStyle(PlainButtonStyle())
            .geometryGroup()

            if isDownloading && downloadProgress > 0 {
                VStack(spacing: 8) {
                    ProgressView(value: downloadProgress)
                        .progressViewStyle(LinearProgressViewStyle(tint: Color(UIColor.label)))
                    
                    HStack {
                        Text("Downloading...")
                            .font(.caption)
                        Spacer()
                        Text("\(Int(downloadProgress * 100))%")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.bottom, 12)
            }
            
            if isDownloaded && !isSelected {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.caption)
                    Text("Downloaded • Tap to activate")
                        .font(.caption)
                        .foregroundColor(.secondary)
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
                        .stroke(isSelected ? Color(UIColor.label) : Color.clear, lineWidth: 2)
                )
        )
    }
}

#Preview {
    NavigationStack {
        ModelManagementView()
    }
}