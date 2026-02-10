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
            VStack(spacing: 24) {
                Text("Create Account")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                if let message = authService.errorMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    TextField("Email", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)
                        .focused($focusedField, equals: .email)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    SecureField("Password", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .password)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Confirm Password")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    SecureField("Confirm Password", text: $confirmPassword)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.newPassword)
                        .focused($focusedField, equals: .confirmPassword)
                    if !confirmPassword.isEmpty && !passwordsMatch {
                        Text("Passwords do not match")
                            .font(.caption)
                            .foregroundColor(.red)
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
                    } else {
                        Text("Sign Up")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(authService.isLoading || email.isEmpty || password.isEmpty || !passwordsMatch)

                if let _ = authService.errorMessage {
                    Button("Clear error") {
                        authService.errorMessage = nil
                    }
                    .font(.caption)
                }
            }
            .padding(24)
        }
    }
}

struct SignUpView_Previews: PreviewProvider {
    static var previews: some View {
        SignUpView(authService: AuthService())
    }
}
