//
//  TransferView.swift
//  MobileBank
//

import SwiftUI

enum TransferMode {
    case send
    case topUp
}

struct TransferFlowView: View {
    @ObservedObject var store: BankStore
    var initialMode: TransferMode = .send
    var embedded: Bool = false

    @Environment(\.dismiss) private var dismiss

    private enum Step { case amount, confirm, success }
    @State private var step: Step = .amount
    @State private var amountText = ""
    @State private var useContacts = false
    @State private var fromID: UUID?
    @State private var toContactID: UUID?
    @State private var toAccountID: UUID?
    @State private var note = ""
    @State private var showValidationError = false
    @State private var validationMessage = ""

    private var amount: Double {
        Double(amountText) ?? 0
    }

    private var fromAccount: BankAccount? { store.accounts.first { $0.id == fromID } }
    private var toContact: Contact? { store.contacts.first { $0.id == toContactID } }
    private var toAccount: BankAccount? { store.accounts.first { $0.id == toAccountID } }

    private var recipientName: String {
        useContacts ? (toContact?.name ?? "a contact") : (toAccount?.name ?? "an account")
    }

    var body: some View {
        Group {
            switch step {
            case .amount: amountStep
            case .confirm: confirmStep
            case .success: successStep
            }
        }
        .background(Color.paper.ignoresSafeArea())
        .onAppear {
            useContacts = (initialMode == .send)
            if fromID == nil { fromID = store.accounts.first?.id }
        }
        .alert(validationMessage, isPresented: $showValidationError) {
            Button("OK", role: .cancel) {}
        }
    }

    // MARK: - Amount step

    private var amountStep: some View {
        VStack(spacing: 0) {
            if !embedded {
                HStack {
                    Text(initialMode == .send ? "Send money" : "Top up")
                        .font(.title2.bold())
                        .foregroundStyle(Color.ink)
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(Color.subtleText)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
            }

            VStack(spacing: 6) {
                Text(amountText.isEmpty ? "$0" : "$" + amountText)
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(amount > 0 ? Color.ink : Color.subtleText)
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                Text("Available \(Currency.string(fromAccount?.balance ?? 0))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 22)

            Picker("Recipient", selection: $useContacts) {
                Text("My accounts").tag(false)
                Text("Contacts").tag(true)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .tint(Color.mint)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    if useContacts {
                        ForEach(store.contacts) { contact in
                            personChip(contact)
                        }
                    } else {
                        ForEach(store.accounts.filter { $0.id != fromID }) { account in
                            accountChip(account)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            }

            Menu {
                ForEach(store.accounts) { account in
                    Button("\(account.name) · \(Currency.string(account.balance))") {
                        fromID = account.id
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "creditcard")
                        .font(.subheadline)
                    Text("From \(fromAccount?.name ?? "Choose account")")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(Color.ink)
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            }
            .padding(.horizontal, 20)

            TextField("Add a note (optional)", text: $note)
                .font(.subheadline)
                .padding(14)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.top, 10)

            Spacer(minLength: 14)

            KeypadView(text: $amountText)
                .padding(.horizontal, 20)

            Button {
                validateAndContinue()
            } label: {
                Text("Continue")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.mint, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 14)
        }
    }

    private func personChip(_ contact: Contact) -> some View {
        Button {
            toContactID = contact.id
        } label: {
            HStack(spacing: 8) {
                Text(String(contact.name.prefix(1)))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 30, height: 30)
                    .background(Circle().fill(Color(hex: contact.colorHex)))
                Text(contact.name)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(toContactID == contact.id ? .white : Color.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                toContactID == contact.id ? Color.mint : Color.white,
                in: Capsule()
            )
        }
    }

    private func accountChip(_ account: BankAccount) -> some View {
        Button {
            toAccountID = account.id
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "creditcard.fill")
                    .font(.caption)
                Text(account.name)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(toAccountID == account.id ? .white : Color.ink)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(
                toAccountID == account.id ? Color.mint : Color.white,
                in: Capsule()
            )
        }
    }

    // MARK: - Confirm step

    private var confirmStep: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Confirm")
                    .font(.title2.bold())
                    .foregroundStyle(Color.ink)
                Spacer()
                Button("Back") {
                    withAnimation { step = .amount }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.mint)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)

            VStack(spacing: 18) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Color.mint)
                Text(recipientName)
                    .font(.title3.bold())
                    .foregroundStyle(Color.ink)
                Text(Currency.string(amount))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
            }
            .padding(.vertical, 24)

            VStack(spacing: 14) {
                summaryRow(label: "From", value: fromAccount?.name ?? "—")
                summaryRow(label: "To", value: recipientName)
                if !note.isEmpty {
                    summaryRow(label: "Note", value: note)
                }
                summaryRow(label: "Fee", value: "No fee")
            }
            .padding(18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 20)

            Spacer()

            Button {
                if let from = fromAccount {
                    store.performTransfer(from: from.id,
                                          toContactID: useContacts ? toContactID : nil,
                                          toAccountID: useContacts ? nil : toAccountID,
                                          amount: amount,
                                          note: note)
                }
                withAnimation(.snappy) { step = .success }
            } label: {
                Text(initialMode == .send ? "Confirm & send" : "Confirm & move")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.mint, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ink)
        }
    }

    // MARK: - Success step

    private var successStep: some View {
        VStack(spacing: 18) {
            Spacer()
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(Color.mint)
            Text("Money sent")
                .font(.title.bold())
                .foregroundStyle(Color.ink)
            Text("\(Currency.string(amount)) to \(recipientName)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Button {
                done()
            } label: {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.mint, in: RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)
        }
    }

    private func done() {
        step = .amount
        amountText = ""
        note = ""
        toContactID = nil
        toAccountID = nil
        if !embedded {
            dismiss()
        }
    }

    // MARK: - Validation

    private func validateAndContinue() {
        var message: String? = nil
        if let from = fromAccount {
            if amount <= 0 {
                message = "Enter an amount greater than $0."
            } else if amount > from.balance {
                message = "Insufficient balance in \(from.name)."
            } else if useContacts {
                if toContact == nil { message = "Choose a contact." }
            } else {
                if toAccount == nil {
                    message = "Choose an account."
                } else if toAccount?.id == from.id {
                    message = "Choose a different account."
                }
            }
        } else {
            message = "Choose an account to send from."
        }

        if let message {
            validationMessage = message
            showValidationError = true
        } else {
            withAnimation(.snappy) { step = .confirm }
        }
    }
}

struct KeypadView: View {
    @Binding var text: String

    private let rows = [["1", "2", "3"], ["4", "5", "6"], ["7", "8", "9"], [".", "0", "⌫"]]

    var body: some View {
        VStack(spacing: 10) {
            ForEach(rows, id: \.self) { row in
                HStack(spacing: 10) {
                    ForEach(row, id: \.self) { key in
                        Button {
                            tap(key)
                        } label: {
                            Group {
                                if key == "⌫" {
                                    Image(systemName: "delete.left")
                                } else {
                                    Text(key)
                                }
                            }
                            .font(.system(size: 21, weight: .medium, design: .rounded))
                            .foregroundStyle(Color.ink)
                            .frame(maxWidth: .infinity, minHeight: 50)
                            .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                        }
                    }
                }
            }
        }
    }

    private func tap(_ key: String) {
        if key == "⌫" {
            if !text.isEmpty { text.removeLast() }
            return
        }
        if key == "." {
            if text.contains(".") { return }
            text = text.isEmpty ? "0." : text + "."
            return
        }
        if text.contains("."), let dotIndex = text.firstIndex(of: "."),
           text.distance(from: dotIndex, to: text.endIndex) > 2 {
            return
        }
        if text == "0" {
            text = key
        } else if text.count < 9 {
            text += key
        }
    }
}

struct TransferTabView: View {
    @ObservedObject var store: BankStore

    var body: some View {
        NavigationStack {
            TransferFlowView(store: store, initialMode: .send, embedded: true)
                .navigationTitle("Send money")
                .navigationBarTitleDisplayMode(.inline)
        }
    }
}