//
//  AuthService.swift
//  Macro Tracker
//

import Foundation
import FirebaseAuth
import Combine

@MainActor
final class AuthService: ObservableObject {
    @Published private(set) var currentUser: User?
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    private var authStateHandler: AuthStateDidChangeListenerHandle?

    init() {
        authStateHandler = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                self?.currentUser = user
            }
        }
    }

    deinit {
        if let handler = authStateHandler {
            Auth.auth().removeStateDidChangeListener(handler)
        }
    }

    var isSignedIn: Bool {
        currentUser != nil
    }

    var userId: String? {
        currentUser?.uid
    }

    func signIn(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signUp(email: String, password: String) async {
        isLoading = true
        errorMessage = nil
        do {
            _ = try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func signOut() throws {
        try Auth.auth().signOut()
        errorMessage = nil
    }
}
