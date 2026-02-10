//
//  AuthView.swift
//  Macro Tracker
//

import SwiftUI

struct AuthView: View {
    @ObservedObject var authService: AuthService
    @State private var showingSignUp = false

    var body: some View {
        Group {
            if showingSignUp {
                SignUpView(authService: authService)
                    .overlay(alignment: .topLeading) {
                        Button("Sign In") {
                            showingSignUp = false
                            authService.errorMessage = nil
                        }
                        .padding()
                    }
            } else {
                SignInView(authService: authService)
                    .overlay(alignment: .topLeading) {
                        Button("Sign Up") {
                            showingSignUp = true
                            authService.errorMessage = nil
                        }
                        .padding()
                    }
            }
        }
    }
}

struct AuthView_Previews: PreviewProvider {
    static var previews: some View {
        AuthView(authService: AuthService())
    }
}
