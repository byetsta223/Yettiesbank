//
//  AppLock.swift
//  MobileBank
//

import SwiftUI
import LocalAuthentication

final class AppLock: ObservableObject {
    static let shared = AppLock()

    /// Lock engages at launch and whenever the app returns from 2+ minutes in the background.
    static let backgroundGracePeriod: TimeInterval = 120

    @Published var isEnabled: Bool {
        didSet { UserDefaults.standard.set(isEnabled, forKey: "appLockEnabled") }
    }

    @Published var isLocked = false

    private var backgroundedAt: Date?
    private var pendingUnlock = false

    private init() {
        isEnabled = UserDefaults.standard.bool(forKey: "appLockEnabled")
    }

    func lockAtLaunchIfNeeded() {
        guard isEnabled else { return }
        isLocked = true
    }

    func appDidEnterBackground() {
        guard isEnabled else { return }
        backgroundedAt = Date()
    }

    func appWillEnterForeground() {
        guard isEnabled else { return }
        let elapsed = backgroundedAt.map { Date().timeIntervalSince($0) }
        backgroundedAt = nil

        // Already locked (launch lock or a previous short background): keep the lock on.
        if isLocked { return }

        if let elapsed, elapsed >= Self.backgroundGracePeriod {
            isLocked = true
            unlock()
        }
    }

    func unlock(onSuccess: (() -> Void)? = nil) {
        guard !pendingUnlock else { return }
        pendingUnlock = true

        let context = LAContext()
        context.localizedFallbackTitle = "Use Passcode"

        var evaluationError: NSError?
        let policy: LAPolicy = context.canEvaluatePolicy(.deviceOwnerAuthentication, error: &evaluationError)
            ? .deviceOwnerAuthentication
            : .deviceOwnerAuthenticationWithBiometrics

        guard context.canEvaluatePolicy(policy, error: &evaluationError) else {
            // No biometrics or passcode available on this device; nothing to secure with.
            pendingUnlock = false
            isLocked = false
            onSuccess?()
            return
        }

        context.evaluatePolicy(policy, localizedReason: "Unlock Yetties Bank to see your balances and payments.") { success, _ in
            DispatchQueue.main.async {
                self.pendingUnlock = false
                if success {
                    withAnimation(.easeOut(duration: 0.25)) {
                        self.isLocked = false
                    }
                    onSuccess?()
                }
            }
        }
    }

    /// Confirms with Face ID before turning the app lock on from Profile.
    func authenticateForToggle() {
        unlock { self.isEnabled = true }
    }
}

struct LockScreenView: View {
    @ObservedObject private var lock = AppLock.shared
    @AppStorage("signedInName") private var signedInName = ""

    var body: some View {
        VStack(spacing: 26) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.mint.opacity(0.12))
                    .frame(width: 118, height: 118)
                Image(systemName: "faceid")
                    .font(.system(size: 44, weight: .medium))
                    .foregroundStyle(Color.mint)
            }

            VStack(spacing: 8) {
                Text("Yetties Bank")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(Color.ink)
                Text(signedInName.isEmpty ? "Your bank is locked" : "Welcome back, \(signedInName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Button {
                lock.unlock()
            } label: {
                Label("Unlock with Face ID", systemImage: "lock.open.fill")
                    .font(.headline)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(Color.mint)

            Spacer()

            Text("Protected with Face ID")
                .font(.caption)
                .foregroundStyle(Color.subtleText)
                .padding(.bottom, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.paper.ignoresSafeArea())
        .onAppear { lock.unlock() }
    }
}