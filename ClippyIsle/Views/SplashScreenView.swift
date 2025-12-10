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
    
    private let splashDuration: TimeInterval = 1.5
    private let splashLogoSize: CGFloat = 120
    private let appIconCornerRadius: CGFloat = 26.4
    
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
                Text("C Isle")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(colorScheme == .dark ? .white : .black)
            }
        }
        .onAppear {
            // Dismiss splash screen after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + splashDuration) {
                withAnimation(.easeOut(duration: 0.3)) {
                    isPresented = false
                }
            }
        }
    }
}
