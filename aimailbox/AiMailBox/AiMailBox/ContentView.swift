//
//  ContentView.swift
//  AiMailBox
//
//  Created by PD Dev on 11/21/25.
//

import SwiftUI

struct ContentView: View {
    @State private var isScanning = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            TabView {
                HomeView()
                    .tabItem {
                        Image(systemName: "envelope")
                        Text("Mails")
                    }
                
                SettingsView()
                    .tabItem {
                        Image(systemName: "gear")
                        Text("Settings")
                    }
            }
            .accentColor(.blue)
            
            // Floating scan button
            Button(action: {
                isScanning = true
            }) {
                ZStack {
                    Circle()
                        .fill(.white)
                        .frame(width: 66, height: 66)
                        .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                    
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)
                        .frame(width: 66, height: 66)
                    
                    Image(systemName: "doc.viewfinder")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.blue)
                }
            }
            .offset(y: -25)
        }
        .sheet(isPresented: $isScanning) {
            ScannerView()
        }
    }
}

#Preview {
    ContentView()
}
