//
//  SignInView.swift
//  Macro Tracker
//

import SwiftUI

struct SignInView: View {
    @ObservedObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: Field?

    enum Field { case email, password }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero section with fitness icon
                VStack(spacing: 16) {
                    Image(systemName: "figure.run.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, Color("ProteinColor")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Macro Tracker")
                        .font(.system(size: 32, weight: .bold))
                    Text("Track your nutrition, fuel your fitness")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 40)

                if let message = authService.errorMessage {
                    Text(message)
                        .font(.subheadline)
                        .foregroundColor(.red)
                        .padding(12)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.red.opacity(0.1))
                        )
                }

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Email")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        TextField("your.email@example.com", text: $email)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.emailAddress)
                            .autocapitalization(.none)
                            .keyboardType(.emailAddress)
                            .focused($focusedField, equals: .email)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Password")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        SecureField("Enter your password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.password)
                            .focused($focusedField, equals: .password)
                    }
                }

                Button {
                    Task {
                        await authService.signIn(email: email, password: password)
                    }
                } label: {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.right.circle.fill")
                                .font(.system(size: 18))
                            Text("Sign In")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                }
                .background(
                    LinearGradient(
                        colors: (authService.isLoading || email.isEmpty || password.isEmpty) ? [Color.gray.opacity(0.3)] : [.accentColor, .accentColor.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .disabled(authService.isLoading || email.isEmpty || password.isEmpty)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView(authService: AuthService())
    }
}
