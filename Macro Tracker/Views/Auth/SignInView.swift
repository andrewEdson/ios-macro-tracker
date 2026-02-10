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
            VStack(spacing: 24) {
                Text("Sign In")
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
                        .textContentType(.password)
                        .focused($focusedField, equals: .password)
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
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(authService.isLoading || email.isEmpty || password.isEmpty)

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

struct SignInView_Previews: PreviewProvider {
    static var previews: some View {
        SignInView(authService: AuthService())
    }
}
