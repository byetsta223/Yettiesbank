//
//  ProfileView.swift
//  MobileBank
//

import SwiftUI

struct ProfileView: View {
    @ObservedObject var store: BankStore
    @ObservedObject private var lock = AppLock.shared
    @AppStorage("signedInName") private var signedInName = ""
    @AppStorage("signedInEmail") private var signedInEmail = ""
    @State private var showResetConfirm = false

    private var initials: String {
        let parts = signedInName.split(separator: " ").prefix(2)
        return parts.compactMap { $0.first.map(String.init) }.joined().uppercased()
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 14) {
                        Text(initials.isEmpty ? "MB" : initials)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(Circle().fill(Color.mint))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(signedInName)
                                .font(.headline)
                            Text(signedInEmail.isEmpty ? "Signed in with Apple" : signedInEmail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .listRowBackground(Color.white)
                }

                Section("Preferences") {
                    Toggle(isOn: $store.hideBalances) {
                        Label("Hide balances", systemImage: "eye.slash")
                            .foregroundStyle(Color.ink)
                    }
                    .tint(Color.mint)
                    .listRowBackground(Color.white)

                    Toggle(isOn: Binding(
                        get: { lock.isEnabled },
                        set: { newValue in
                            if newValue {
                                lock.authenticateForToggle()
                            } else {
                                lock.isEnabled = false
                            }
                        }
                    )) {
                        Label("App lock", systemImage: "faceid")
                            .foregroundStyle(Color.ink)
                    }
                    .tint(Color.mint)
                    .listRowBackground(Color.white)
                }

                Section("Data") {
                    Button {
                        showResetConfirm = true
                    } label: {
                        Label("Reset demo data", systemImage: "arrow.counterclockwise")
                            .foregroundStyle(Color.ink)
                    }
                    .listRowBackground(Color.white)
                }

                Section {
                    Button(role: .destructive) {
                        signedInName = ""
                        signedInEmail = ""
                    } label: {
                        Label("Sign out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .listRowBackground(Color.white)
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.paper)
            .navigationTitle("Profile")
            .alert("Reset demo data?", isPresented: $showResetConfirm) {
                Button("Reset", role: .destructive) {
                    store.resetDemoData()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Balances and activity will return to the original demo state.")
            }
        }
    }
}