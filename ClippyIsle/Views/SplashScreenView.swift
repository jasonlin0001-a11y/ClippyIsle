//
//  SplashScreenView.swift
//  ClippyIsle
//
//  Created for splash screen implementation
//

import SwiftUI

struct SplashScreenView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Binding var isPresented: Bool
    @Binding var isAppReady: Bool
    
    private let minimumSplashDuration: TimeInterval = 0.5  // Minimum display time for smooth UX
    private let maximumSplashDuration: TimeInterval = 2.0  // Maximum wait time as fallback
    private let splashLogoSize: CGFloat = 120
    private let appIconCornerRadius: CGFloat = 26.4
    
    @State private var minimumTimeElapsed = false
    
    var body: some View {
        ZStack {
            // Background color based on appearance mode
            (colorScheme == .dark ? Color.black : Color.white)
                .ignoresSafeArea()
            
            VStack(spacing: 20) {
                // App Icon/Logo
                Image("SplashLogo")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: splashLogoSize, height: splashLogoSize)
                    .cornerRadius(appIconCornerRadius) // iOS app icon corner radius
                    .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 5)
                
                // App Title
                Text("CC Isle")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
        }
        .onAppear {
            // Start minimum time timer
            DispatchQueue.main.asyncAfter(deadline: .now() + minimumSplashDuration) {
                minimumTimeElapsed = true
                dismissIfReady()
            }
            
            // Fallback: dismiss after maximum duration regardless
            DispatchQueue.main.asyncAfter(deadline: .now() + maximumSplashDuration) {
                LaunchLogger.log("SplashScreen - Force dismiss after max duration")
                withAnimation(.easeOut(duration: 0.3)) {
                    isPresented = false
                }
            }
        }
        .onChange(of: isAppReady) { _, ready in
            if ready {
                dismissIfReady()
            }
        }
    }
    
    private func dismissIfReady() {
        // Only dismiss if both minimum time has elapsed AND app is ready
        if minimumTimeElapsed && isAppReady {
            LaunchLogger.log("SplashScreen - Dismiss (app ready)")
            withAnimation(.easeOut(duration: 0.3)) {
                isPresented = false
            }
        }
    }
}
