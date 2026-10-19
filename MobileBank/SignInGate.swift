//
//  SignInGate.swift
//  MobileBank
//

import SwiftUI
import AuthenticationServices
import CryptoKit

// MARK: - Local account storage

struct LocalAccount: Codable {
    var name: String
    var email: String
    var passwordHash: String
}

enum AccountStore {
    private static let key = "localAccount"

    static var account: LocalAccount? {
        get {
            guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
            return try? JSONDecoder().decode(LocalAccount.self, from: data)
        }
        set {
            if let newValue,
               let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: key)
            } else {
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    static func hash(_ password: String) -> String {
        SHA256.hash(data: Data(password.utf8))
            .map { String(format: "%02x", $0) }
            .joined()
    }

    static func create(name: String, email: String, password: String) -> Bool {
        guard account == nil else { return false }
        account = LocalAccount(
            name: name,
            email: email.lowercased(),
            passwordHash: hash(password)
        )
        return true
    }

    static func signIn(email: String, password: String) -> LocalAccount? {
        guard let account,
              account.email == email.lowercased(),
              account.passwordHash == hash(password) else { return nil }
        return account
    }
}

// MARK: - Sign in gate

struct SignInGate: View {
    @AppStorage("signedInName") private var signedInName = ""
    @AppStorage("signedInEmail") private var signedInEmail = ""
    @State private var showCreateAccount = false
    @State private var showEmailSignIn = false

    private var hasAccount: Bool { AccountStore.account != nil }

    var body: some View {
        VStack(spacing: 26) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Color.mint.opacity(0.12))
                    .frame(width: 122, height: 122)
                Image(systemName: "banknote.fill")
                    .font(.system(size: 42))
                    .foregroundStyle(Color.mint)
            }
            VStack(spacing: 10) {
                Text("Yetties Bank")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.ink)
                Text("Your money, beautifully organised.\nCreate an account to view balances, move money and track every payment.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            VStack(spacing: 12) {
                SignInWithAppleButton(.signIn) { request in
                    request.requestedScopes = [.fullName, .email]
                } onCompletion: { result in
                    handle(result)
                }
                .signInWithAppleButtonStyle(.black)
                .frame(height: 54)
                .clipShape(RoundedRectangle(cornerRadius: 16))

                if hasAccount {
                    Button {
                        showEmailSignIn = true
                    } label: {
                        Label("Sign in with email", systemImage: "envelope")
                            .font(.headline)
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.ink.opacity(0.12), lineWidth: 1)
                            )
                    }
                } else {
                    Button {
                        showCreateAccount = true
                    } label: {
                        Label("Create an account", systemImage: "person.crop.circle.badge.plus")
                            .font(.headline)
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color.white)
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .strokeBorder(Color.ink.opacity(0.12), lineWidth: 1)
                            )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .background(Color.paper.ignoresSafeArea())
        .sheet(isPresented: $showCreateAccount) {
            CreateAccountView()
        }
        .sheet(isPresented: $showEmailSignIn) {
            EmailSignInView()
        }
    }

    private func handle(_ result: Result<ASAuthorization, Error>) {
        if case .success(let auth) = result,
           let credential = auth.credential as? ASAuthorizationAppleIDCredential {
            let name = [credential.fullName?.givenName, credential.fullName?.familyName]
                .compactMap { $0 }
                .joined(separator: " ")
            signedInName = name.isEmpty ? "Friend" : name
            signedInEmail = credential.email ?? ""
        }
    }
}

// MARK: - Create account

struct CreateAccountView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("signedInName") private var signedInName = ""
    @AppStorage("signedInEmail") private var signedInEmail = ""

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Full name", text: $name)
                        .textInputAutocapitalization(.words)
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                } header: {
                    Text("Your details")
                }

                Section {
                    SecureField("Password (at least 6 characters)", text: $password)
                    SecureField("Confirm password", text: $confirmPassword)
                } header: {
                    Text("Password")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Section {
                    Button {
                        create()
                    } label: {
                        Text("Create account")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(Color.mint)
                } footer: {
                    Text("Your account is stored securely on this device.")
                }
            }
            .navigationTitle("Create account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func create() {
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)

        guard !trimmedName.isEmpty else {
            errorMessage = "Please enter your name."
            return
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Please enter a valid email address."
            return
        }
        guard password.count >= 6 else {
            errorMessage = "Password must be at least 6 characters."
            return
        }
        guard password == confirmPassword else {
            errorMessage = "Passwords do not match."
            return
        }

        if AccountStore.create(name: trimmedName, email: trimmedEmail, password: password) {
            signedInName = trimmedName
            signedInEmail = trimmedEmail.lowercased()
            dismiss()
        } else {
            errorMessage = "An account already exists on this device. Sign in instead."
        }
    }
}

// MARK: - Email sign in

struct EmailSignInView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("signedInName") private var signedInName = ""
    @AppStorage("signedInEmail") private var signedInEmail = ""

    @State private var email = ""
    @State private var password = ""
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Password", text: $password)
                } header: {
                    Text("Sign in")
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }

                Section {
                    Button {
                        signIn()
                    } label: {
                        Text("Sign in")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .tint(Color.mint)
                }
            }
            .navigationTitle("Welcome back")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func signIn() {
        if let account = AccountStore.signIn(email: email, password: password) {
            signedInName = account.name
            signedInEmail = account.email
            dismiss()
        } else {
            errorMessage = "Incorrect email or password."
        }
    }
}