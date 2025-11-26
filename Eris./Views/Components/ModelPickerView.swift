//
//  ModelPickerView.swift
//  Eris.
//
//  Created by Ignacio Palacio on 19/6/25.
//

import SwiftUI
import MLXLMCommon

struct ModelPickerView: View {
    @StateObject private var modelManager = ModelManager.shared
    let selectedModel: MLXLMCommon.ModelConfiguration?
    let onSelect: (MLXLMCommon.ModelConfiguration) -> Void
    
    private let registry = AIModelsRegistry.shared
    
    var body: some View {
        List {
            ForEach(ModelCategory.allCases, id: \.self) { category in
                let downloadedModelsInCategory = registry.modelsForCategory(category)
                    .filter { modelManager.isModelDownloaded($0.configuration) }
                
                if !downloadedModelsInCategory.isEmpty {
                    Section {
                        ForEach(downloadedModelsInCategory) { aiModel in
                            ModelPickerRow(
                                aiModel: aiModel,
                                isSelected: selectedModel?.name == aiModel.configuration.name,
                                onTap: {
                                    HapticManager.shared.selection()
                                    onSelect(aiModel.configuration)
                                }
                            )
                        }
                    } header: {
                        Label(category.rawValue, systemImage: category.icon)
                    }
                }
            }
            
            if modelManager.downloadedModels.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "arrow.down.circle.dotted")
                            .font(.largeTitle)
                            .foregroundStyle(.tertiary)
                        
                        Text("No models downloaded")
                            .font(.headline)
                        
                        Text("Go to Settings to download models")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 40)
                }
            }
        }
        .listStyle(.insetGrouped)
    }
}

struct ModelPickerRow: View {
    let aiModel: AIModel
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 4) {
                        Text(aiModel.displayName)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        
                        Text("• \(aiModel.parameterCount)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text(aiModel.quantization)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)

                        if aiModel.isLegacy {
                            Text("LEGACY")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange)
                                .cornerRadius(4)
                        }
                    }
                    
                    Text(aiModel.description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.primary)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    NavigationStack {
        ModelPickerView(selectedModel: nil) { _ in }
    }
}