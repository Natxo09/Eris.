//
//  AboutDeveloperView.swift
//  Eris.
//
//  Created by Ignacio Palacio on 19/6/25.
//

import SwiftUI

struct AboutDeveloperView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showSafari = false
    @State private var selectedURL: URL?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 30) {
                    // Developer Profile
                    VStack(spacing: 16) {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 80))
                            .foregroundStyle(.gray)
                            .padding(.top, 20)
                        
                        VStack(spacing: 4) {
                            Text("Ignacio Palacio")
                                .font(.title2)
                                .fontWeight(.bold)

                            Text("Full Stack Developer")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Bio Section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("About")
                            .font(.headline)

                        Text("Full stack developer building apps across web and mobile platforms. Currently focused on iOS development with Swift and on-device machine learning using Apple's MLX framework.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 20)
                    
                    // Contact Links
                    VStack(spacing: 0) {
                        DeveloperLinkRow(
                            icon: "globe",
                            title: "Website",
                            subtitle: "Visit my portfolio",
                            url: "https://natxo.dev"
                        ) { url in
                            selectedURL = url
                            showSafari = true
                        }
                        
                        Divider()
                            .padding(.leading, 64)
                        
                        DeveloperLinkRow(
                            icon: "envelope",
                            title: "Email",
                            subtitle: "Get in touch",
                            url: "mailto:contact@northernbytes.dev"
                        ) { url in
                            if UIApplication.shared.canOpenURL(url) {
                                UIApplication.shared.open(url)
                            }
                        }
                        
                        Divider()
                            .padding(.leading, 64)
                        
                        DeveloperLinkRow(
                            icon: "chevron.left.forwardslash.chevron.right",
                            title: "GitHub",
                            subtitle: "View my projects",
                            url: "https://github.com/Natxo09"
                        ) { url in
                            selectedURL = url
                            showSafari = true
                        }
                        
                    }
                    .background(Color(UIColor.secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .padding(.horizontal, 20)

                    // Footer
                    VStack(spacing: 8) {
                        Text("Made with ❤️ in Spain")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        
                        Text("© 2025 Ignacio Palacio")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.bottom, 40)
                }
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("About Developer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showSafari) {
                if let url = selectedURL {
                    SafariView(url: url)
                }
            }
        }
    }
}

struct DeveloperLinkRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let url: String
    let action: (URL) -> Void
    
    var body: some View {
        Button(action: {
            if let url = URL(string: url) {
                HapticManager.shared.impact(.light)
                action(url)
            }
        }) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.body)
                    .foregroundStyle(.primary)
                    .frame(width: 28, height: 28)
                    .background(Color.gray.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.primary)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right.square")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AboutDeveloperView()
}