//
//  SignInGate.swift
//  MobileBank
//

import SwiftUI
import AuthenticationServices

struct SignInGate: View {
    @AppStorage("signedInName") private var signedInName = ""
    @AppStorage("signedInEmail") private var signedInEmail = ""

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
                Text("MobileBank")
                    .font(.largeTitle.bold())
                    .foregroundStyle(Color.ink)
                Text("Your money, beautifully organised.\nSign in to view balances, move money and track every payment.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            SignInWithAppleButton(.signIn) { request in
                request.requestedScopes = [.fullName, .email]
            } onCompletion: { result in
                handle(result)
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: .infinity)
        .background(Color.paper.ignoresSafeArea())
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