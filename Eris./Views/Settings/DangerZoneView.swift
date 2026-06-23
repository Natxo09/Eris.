//
//  DangerZoneView.swift
//  Eris.
//
//  Created by Ignacio Palacio on 19/6/25.
//

import SwiftUI
import SwiftData

struct DangerZoneView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var modelManager = ModelManager.shared
    
    @State private var showDeleteChatsAlert = false
    @State private var showDeleteModelsAlert = false
    @State private var showDeleteEverythingAlert = false
    @State private var isDeleting = false
    @State private var deletionMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Warning Header
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 50))
                            .foregroundStyle(.red)
                            .padding(.top, 20)
                        
                        Text("Danger Zone")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("These actions are permanent and cannot be undone")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.horizontal, 20)
                    
                    // Actions
                    VStack(spacing: 16) {
                        // Delete All Chats
                        DangerActionCard(
                            icon: "message.badge.filled.fill",
                            title: "Delete All Chats",
                            description: "Remove all conversations and messages",
                            destructive: true
                        ) {
                            showDeleteChatsAlert = true
                        }
                        
                        // Delete All Models
                        DangerActionCard(
                            icon: "cpu",
                            title: "Delete All Models",
                            description: "Remove all downloaded AI models",
                            destructive: true
                        ) {
                            showDeleteModelsAlert = true
                        }
                        
                        // Delete Everything
                        DangerActionCard(
                            icon: "trash.fill",
                            title: "Delete Everything",
                            description: "Remove all data including chats, models, and settings",
                            destructive: true,
                            isUltimate: true
                        ) {
                            showDeleteEverythingAlert = true
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // Info Text
                    VStack(alignment: .leading, spacing: 8) {
                        Label("This complies with Apple's requirement to allow users to delete all app data", systemImage: "info.circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 40)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Danger Zone")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .alert("Delete All Chats?", isPresented: $showDeleteChatsAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All Chats", role: .destructive) {
                    deleteAllChats()
                }
            } message: {
                Text("This will permanently delete all your conversations. This action cannot be undone.")
            }
            .alert("Delete All Models?", isPresented: $showDeleteModelsAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete All Models", role: .destructive) {
                    deleteAllModels()
                }
            } message: {
                Text("This will remove all downloaded AI models. You'll need to download a model again to use the app. This action cannot be undone.")
            }
            .alert("Delete Everything?", isPresented: $showDeleteEverythingAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete Everything", role: .destructive) {
                    deleteEverything()
                }
            } message: {
                Text("This will permanently delete ALL app data including chats, models, and settings. The app will reset to its initial state. This action cannot be undone.")
            }
            .overlay {
                if isDeleting {
                    ZStack {
                        Color.black.opacity(0.5)
                            .ignoresSafeArea()
                        
                        VStack(spacing: 20) {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle())
                                .scaleEffect(1.5)
                            
                            Text(deletionMessage)
                                .font(.headline)
                                .foregroundStyle(.white)
                        }
                        .padding(40)
                        .background(Color(UIColor.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }
    
    private func deleteAllChats() {
        isDeleting = true
        deletionMessage = "Deleting all chats..."
        HapticManager.shared.notification(.warning)
        
        Task {
            do {
                // Fetch all threads
                let descriptor = FetchDescriptor<Thread>()
                let threads = try modelContext.fetch(descriptor)
                
                // Delete all threads (messages will cascade delete)
                for thread in threads {
                    modelContext.delete(thread)
                }
                
                // Save changes
                try modelContext.save()
                
                await MainActor.run {
                    isDeleting = false
                    HapticManager.shared.notification(.success)
                    dismiss()
                }
            } catch {
                print("Error deleting chats: \(error)")
                await MainActor.run {
                    isDeleting = false
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }
    
    private func deleteAllModels() {
        isDeleting = true
        deletionMessage = "Deleting all models..."
        HapticManager.shared.notification(.warning)
        
        Task {
            // Clear all models from ModelManager
            for aiModel in AIModelsRegistry.shared.allModels {
                modelManager.delete(aiModel)
            }

            // Try to clear cache directories
            clearModelCaches()
            
            await MainActor.run {
                isDeleting = false
                HapticManager.shared.notification(.success)
                dismiss()
            }
        }
    }
    
    private func deleteEverything() {
        isDeleting = true
        deletionMessage = "Deleting everything..."
        HapticManager.shared.notification(.warning)
        
        Task {
            do {
                // Delete all chats
                let descriptor = FetchDescriptor<Thread>()
                let threads = try modelContext.fetch(descriptor)
                for thread in threads {
                    modelContext.delete(thread)
                }
                try modelContext.save()
                
                // Delete all models
                for aiModel in AIModelsRegistry.shared.allModels {
                    modelManager.delete(aiModel)
                }
                
                // Clear all UserDefaults
                if let bundleID = Bundle.main.bundleIdentifier {
                    UserDefaults.standard.removePersistentDomain(forName: bundleID)
                }
                
                // Clear cache directories
                clearModelCaches()
                
                // Reset onboarding
                UserDefaults.standard.set(false, forKey: "hasCompletedOnboarding")
                
                await MainActor.run {
                    isDeleting = false
                    HapticManager.shared.notification(.success)
                    
                    // Force quit the app after a delay
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        exit(0)
                    }
                }
            } catch {
                print("Error deleting everything: \(error)")
                await MainActor.run {
                    isDeleting = false
                    HapticManager.shared.notification(.error)
                }
            }
        }
    }
    
    private func clearModelCaches() {
        // Clear Hugging Face cache
        let fileManager = FileManager.default
        
        // Get app's document directory
        if let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            let huggingFacePath = documentsPath.appendingPathComponent("huggingface")
            try? fileManager.removeItem(at: huggingFacePath)
        }
        
        // Clear caches directory
        if let cachesPath = fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first {
            // Remove any MLX related caches
            do {
                let cacheContents = try fileManager.contentsOfDirectory(at: cachesPath, includingPropertiesForKeys: nil)
                for item in cacheContents {
                    if item.lastPathComponent.contains("mlx") || 
                       item.lastPathComponent.contains("model") ||
                       item.lastPathComponent.contains("huggingface") {
                        try? fileManager.removeItem(at: item)
                    }
                }
            } catch {
                print("Error clearing caches: \(error)")
            }
        }
    }
}

struct DangerActionCard: View {
    let icon: String
    let title: String
    let description: String
    let destructive: Bool
    let isUltimate: Bool
    let action: () -> Void
    
    init(icon: String, title: String, description: String, destructive: Bool, isUltimate: Bool = false, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.description = description
        self.destructive = destructive
        self.isUltimate = isUltimate
        self.action = action
    }
    
    var body: some View {
        Button(action: {
            HapticManager.shared.impact(.medium)
            action()
        }) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(destructive ? .red : .primary)
                    .frame(width: 40, height: 40)
                    .background(destructive ? Color.red.opacity(0.1) : Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(16)
            .background(isUltimate ? Color.red.opacity(0.05) : Color(UIColor.secondarySystemGroupedBackground))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isUltimate ? Color.red.opacity(0.3) : Color.clear, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    DangerZoneView()
}