//
//  CardsView.swift
//  YettiesBank
//

import SwiftUI

struct CardsView: View {
    @ObservedObject var store: BankStore
    @State private var revealedID: UUID?
    @State private var hiddenVirtualCardIDs: Set<UUID> = []
    @State private var showAddCard = false
    @State private var spendTargetID: UUID?
    @State private var showSpendPrompt = false
    @State private var spendAmountText = ""
    @State private var declineMessage: String?

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
                    virtualCardsSection
                }
                .padding(20)
                .padding(.bottom, 30)
            }
            .background(Color.paper.ignoresSafeArea())
            .navigationTitle("Cards")
            .sheet(isPresented: $showAddCard) {
                AddVirtualCardView(store: store)
            }
            .alert("Spend with virtual card", isPresented: $showSpendPrompt) {
                TextField("Amount", text: $spendAmountText)
                    .keyboardType(.decimalPad)
                Button("Charge") { attemptSpend() }
                Button("Cancel", role: .cancel) { }
            } message: {
                if let card = spendCard {
                    Text("Remaining limit \(Currency.string(card.remaining))")
                }
            }
            .alert("Purchase declined", isPresented: Binding(
                get: { declineMessage != nil },
                set: { if !$0 { declineMessage = nil } }
            )) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(declineMessage ?? "")
            }
        }
    }

    // MARK: - Physical cards (existing)

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

    // MARK: - Virtual cards

    private var virtualCardsSection: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Virtual cards")
                .font(.headline)
                .foregroundStyle(Color.ink)

            ForEach(store.virtualCards) { card in
                virtualCardRow(card)
            }

            Button {
                showAddCard = true
            } label: {
                Label("Add virtual card", systemImage: "plus")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mint)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(Color.mint.opacity(0.4), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                    )
            }
        }
    }

    private var spendCard: VirtualCard? {
        guard let spendTargetID else { return nil }
        return store.virtualCards.first(where: { $0.id == spendTargetID })
    }

    private func sourceAccount(for card: VirtualCard) -> BankAccount? {
        store.accounts.first(where: { $0.id == card.sourceAccountID })
    }

    private func virtualCardRow(_ card: VirtualCard) -> some View {
        let isRevealed = !hiddenVirtualCardIDs.contains(card.id)
        return VStack(spacing: 16) {
            VirtualCardVisual(card: card,
                              source: sourceAccount(for: card),
                              revealed: isRevealed)

            usageRow(card)

            HStack(spacing: 12) {
                Button {
                    withAnimation(.snappy) { store.toggleVirtualCardFreeze(card.id) }
                } label: {
                    Label(card.isFrozen ? "Unfreeze" : "Freeze",
                          systemImage: "snowflake")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(card.isFrozen ? .white : Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(
                            card.isFrozen ? Color(hex: "5B7BD5") : Color.white,
                            in: RoundedRectangle(cornerRadius: 14)
                        )
                }
                Button {
                    withAnimation(.snappy) {
                        if isRevealed {
                            hiddenVirtualCardIDs.insert(card.id)
                        } else {
                            hiddenVirtualCardIDs.remove(card.id)
                        }
                    }
                } label: {
                    Label(isRevealed ? "Hide details" : "Show details",
                          systemImage: isRevealed ? "eye.slash" : "eye")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                }
            }

            Button {
                spendTargetID = card.id
                spendAmountText = ""
                showSpendPrompt = true
            } label: {
                Label(card.isUsedUp ? "Limit reached" : "Spend",
                      systemImage: "cart")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(card.isUsedUp ? Color.subtleText : .white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(
                        card.isUsedUp ? Color(hex: "ECEEF2") : Color.mint,
                        in: RoundedRectangle(cornerRadius: 14)
                    )
            }
            .disabled(card.isUsedUp)
        }
    }

    private func usageRow(_ card: VirtualCard) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Limit \(Currency.string(card.limit, cents: false))")
                Spacer()
                Text(card.isUsedUp ? "Fully used" : "\(Currency.string(card.remaining, cents: false)) left")
                    .foregroundStyle(card.isUsedUp ? Color.mint : Color.subtleText)
            }
            ProgressView(value: card.limit > 0 ? min(card.spent / card.limit, 1) : 0)
                .tint(Color.mint)
        }
        .font(.caption)
        .foregroundStyle(Color.ink)
        .padding(16)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private func attemptSpend() {
        defer { spendAmountText = "" }
        guard let card = spendCard else { return }
        let amount = Double(spendAmountText.replacingOccurrences(of: ",", with: ".")) ?? 0

        if card.isFrozen {
            declineMessage = "This card is frozen. Unfreeze it before spending."
        } else if amount <= 0 {
            declineMessage = "Enter an amount greater than zero."
        } else if amount > card.remaining + 0.001 {
            declineMessage = "Purchase exceeds the remaining limit of \(Currency.string(card.remaining))."
        } else {
            if !store.spendOnVirtualCard(id: card.id, amount: amount) {
                declineMessage = "Purchase could not be completed. Try again."
            }
        }
    }
}

// MARK: - Virtual card visual

struct VirtualCardVisual: View {
    let card: VirtualCard
    let source: BankAccount?
    var revealed: Bool = true
    var holderName: String = "NEEL MAKHECHA"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: source?.colorHex ?? "35507B"))
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 230, height: 230)
                .offset(x: 120, y: -110)
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 170, height: 170)
                .offset(x: -130, y: 110)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Virtual card")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("Single-use · \(source?.name ?? "Card account")")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    if card.isUsedUp {
                        Text("Used up")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.ink)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.85), in: Capsule())
                    } else {
                        Image(systemName: "sparkles")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                Text(revealed ? card.formattedCardNumber : card.maskedCardNumber)
                    .font(.system(size: 19, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.bottom, 12)
                HStack {
                    Text(holderName)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    if revealed {
                        Text("CVC \(card.cvc)")
                            .font(.system(size: 12, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.8))
                            .padding(.trailing, 10)
                    }
                    Text(card.expiry)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                }
            }
            .padding(22)
        }
        .frame(height: 210)
        .blur(radius: card.isFrozen ? 8 : 0)
        .overlay {
            if card.isFrozen {
                VStack(spacing: 6) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 30, weight: .light))
                    Text("Frozen")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color(hex: source?.colorHex ?? "35507B").opacity(0.35), radius: 14, y: 8)
    }
}

// MARK: - Add virtual card flow

struct AddVirtualCardView: View {
    @ObservedObject var store: BankStore
    @Environment(\.dismiss) private var dismiss
    @State private var sourceID: UUID?
    @State private var limitText = "100"

    private var sourceCards: [BankAccount] {
        store.accounts.filter(\.isCard)
    }

    private var limit: Double {
        Double(limitText.replacingOccurrences(of: ",", with: ".")) ?? 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Source card") {
                    Picker("Pay from", selection: $sourceID) {
                        ForEach(sourceCards) { account in
                            Text("\(account.name) · \(account.maskedCardNumber)")
                                .tag(account.id as UUID?)
                        }
                    }
                }

                Section {
                    HStack(spacing: 2) {
                        Text("$")
                            .foregroundStyle(Color.subtleText)
                        TextField("100", text: $limitText)
                            .keyboardType(.decimalPad)
                    }
                    HStack(spacing: 8) {
                        ForEach([50, 100, 250, 500], id: \.self) { value in
                            Button("$\(value)") { limitText = "\(value)" }
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Color.ink)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(hex: "ECEEF2"), in: Capsule())
                        }
                        Spacer()
                    }
                } header: {
                    Text("Spending limit")
                } footer: {
                    Text("The card declines any purchase that would take total spending past this limit.")
                }

                Section {
                    Button {
                        create()
                    } label: {
                        Text("Create virtual card")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .foregroundStyle(.white)
                    }
                    .listRowBackground(limit > 0 ? Color.mint : Color(hex: "B9C0CB"))
                    .disabled(limit <= 0)
                }
            }
            .navigationTitle("Add virtual card")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .onAppear {
                if sourceID == nil { sourceID = sourceCards.first?.id }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func create() {
        guard let sourceID, limit > 0 else { return }
        store.addVirtualCard(sourceAccountID: sourceID, limit: limit)
        dismiss()
    }
}