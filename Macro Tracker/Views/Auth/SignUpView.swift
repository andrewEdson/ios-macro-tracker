//
//  SignUpView.swift
//  Macro Tracker
//

import SwiftUI

struct SignUpView: View {
    @ObservedObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @FocusState private var focusedField: Field?

    enum Field { case email, password, confirmPassword }

    private var passwordsMatch: Bool {
        password.isEmpty && confirmPassword.isEmpty || password == confirmPassword
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Hero section with fitness icon
                VStack(spacing: 16) {
                    Image(systemName: "figure.strengthtraining.traditional")
                        .font(.system(size: 80))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [Color("ProteinColor"), .accentColor],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    Text("Join Macro Tracker")
                        .font(.system(size: 32, weight: .bold))
                    Text("Start your fitness journey today")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
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
                        SecureField("Create a password", text: $password)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .password)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Confirm Password")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.secondary)
                        SecureField("Confirm your password", text: $confirmPassword)
                            .textFieldStyle(.roundedBorder)
                            .textContentType(.newPassword)
                            .focused($focusedField, equals: .confirmPassword)
                        if !confirmPassword.isEmpty && !passwordsMatch {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.circle.fill")
                                Text("Passwords do not match")
                            }
                            .font(.caption)
                            .foregroundColor(.red)
                        }
                    }
                }

                Button {
                    Task {
                        await authService.signUp(email: email, password: password)
                    }
                } label: {
                    if authService.isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    } else {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 18))
                            Text("Create Account")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                    }
                }
                .background(
                    LinearGradient(
                        colors: (authService.isLoading || email.isEmpty || password.isEmpty || !passwordsMatch) ? [Color.gray.opacity(0.3)] : [Color("ProteinColor"), Color("ProteinColor").opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundColor(.white)
                .cornerRadius(16)
                .disabled(authService.isLoading || email.isEmpty || password.isEmpty || !passwordsMatch)
            }
            .padding(.horizontal, 24)
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView(authService: AuthService())
    }
}
