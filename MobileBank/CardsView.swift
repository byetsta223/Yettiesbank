//
//  CardsView.swift
//  MobileBank
//

import SwiftUI

struct CardsView: View {
    @ObservedObject var store: BankStore
    @State private var revealedID: UUID?

    private var cards: [BankAccount] {
        store.accounts.filter(\.isCard)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 30) {
                    ForEach(cards) { account in
                        VStack(spacing: 18) {
                            CardVisual(account: account, revealed: revealedID == account.id)
                            controls(account)
                            settings(account)
                        }
                    }
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .background(Color.paper.ignoresSafeArea())
            .navigationTitle("Cards")
        }
    }

    private func controls(_ account: BankAccount) -> some View {
        HStack(spacing: 12) {
            Button {
                withAnimation(.snappy) { store.toggleFreeze(account.id) }
            } label: {
                Label(account.isFrozen ? "Unfreeze" : "Freeze",
                      systemImage: "snowflake")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(account.isFrozen ? .white : Color.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        account.isFrozen ? Color(hex: "5B7BD5") : Color.white,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }
            Button {
                withAnimation(.snappy) {
                    if revealedID == account.id {
                        revealedID = nil
                    } else {
                        revealedID = account.id
                    }
                }
            } label: {
                Label(revealedID == account.id ? "Hide number" : "Reveal number",
                      systemImage: revealedID == account.id ? "eye.slash" : "eye")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            }
        }
    }

    private func settingBinding(_ account: BankAccount, _ keyPath: WritableKeyPath<BankAccount, Bool>) -> Binding<Bool> {
        Binding(
            get: { account[keyPath: keyPath] },
            set: { newValue in
                store.update(account: account.id) { updated in
                    updated[keyPath: keyPath] = newValue
                }
            }
        )
    }

    private func settings(_ account: BankAccount) -> some View {
        VStack(spacing: 14) {
            Toggle(isOn: settingBinding(account, \.contactless)) {
                Label("Contactless payments", systemImage: "wave.3.right")
                    .font(.subheadline)
            }
            Divider()
            Toggle(isOn: settingBinding(account, \.onlinePayments)) {
                Label("Online payments", systemImage: "globe")
                    .font(.subheadline)
            }
            Divider()
            Toggle(isOn: settingBinding(account, \.atmWithdrawals)) {
                Label("ATM withdrawals", systemImage: "banknote")
                    .font(.subheadline)
            }
        }
        .tint(Color.mint)
        .foregroundStyle(Color.ink)
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }
}