//
//  AuthView.swift
//  Macro Tracker
//

import SwiftUI

struct AuthView: View {
    @ObservedObject var authService: AuthService
    @State private var showingSignUp = false

    var body: some View {
        ZStack(alignment: .top) {
            Group {
                if showingSignUp {
                    SignUpView(authService: authService)
                } else {
                    SignInView(authService: authService)
                }
            }
            
            // Toggle button overlay
            HStack {
                Button {
                    withAnimation(.spring(response: 0.3)) {
                        showingSignUp.toggle()
                        authService.errorMessage = nil
                    }
                } label: {
                    Text(showingSignUp ? "Sign In" : "Sign Up")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(.accentColor)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 20)
                                .fill(Color.accentColor.opacity(0.12))
                        )
                }
                Spacer()
            }
            .padding()
            .padding(.top, 8)
        }
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView(authService: AuthService())
    }
}
