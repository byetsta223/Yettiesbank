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
    private enum RecipientMode { case accounts, contacts, eTransfer }

    @State private var step: Step = .amount
    @State private var amountText = ""
    @State private var recipientMode: RecipientMode = .contacts
    @State private var fromID: UUID?
    @State private var toContactID: UUID?
    @State private var toAccountID: UUID?
    @State private var newName = ""
    @State private var newHandle = ""
    @State private var question = ""
    @State private var answer = ""
    @State private var note = ""
    @State private var showValidationError = false
    @State private var validationMessage = ""

    private var amount: Double {
        Double(amountText) ?? 0
    }

    private var fromAccount: BankAccount? { store.accounts.first { $0.id == fromID } }
    private var toContact: Contact? { store.contacts.first { $0.id == toContactID } }
    private var toAccount: BankAccount? { store.accounts.first { $0.id == toAccountID } }

    private var trimmedName: String { newName.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedHandle: String { newHandle.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var recipientName: String {
        switch recipientMode {
        case .accounts: return toAccount?.name ?? "an account"
        case .contacts: return toContact?.name ?? "a contact"
        case .eTransfer: return trimmedName.isEmpty ? "a new recipient" : trimmedName
        }
    }

    private var hasRecipient: Bool {
        switch recipientMode {
        case .accounts: return toAccountID != nil
        case .contacts: return toContact != nil
        case .eTransfer: return !trimmedName.isEmpty && !trimmedHandle.isEmpty
        }
    }

    private var canProceed: Bool {
        guard let from = fromAccount else { return false }
        return amount > 0 && amount <= from.balance && hasRecipient
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
            recipientMode = (initialMode == .send) ? .contacts : .accounts
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

            Picker("Recipient", selection: $recipientMode) {
                Text("My accounts").tag(RecipientMode.accounts)
                Text("Contacts").tag(RecipientMode.contacts)
                Text("E-transfer").tag(RecipientMode.eTransfer)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20)
            .tint(Color.mint)

            if recipientMode == .eTransfer {
                VStack(spacing: 10) {
                    TextField("Recipient name", text: $newName)
                        .padding(14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                    TextField("Email or mobile number", text: $newHandle)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .padding(14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ink)
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        if recipientMode == .contacts {
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

            if !hasRecipient {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.exclamationmark")
                    Text(recipientMode == .eTransfer ? "Enter a name and an email or mobile number"
                                             : (recipientMode == .contacts ? "Select a contact to send to" : "Select an account to move money to"))
                        .font(.footnote.weight(.medium))
                }
                .foregroundStyle(Color(hex: "8A6D1F"))
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(hex: "F6EFD9"), in: RoundedRectangle(cornerRadius: 14))
                .padding(.horizontal, 20)
                .padding(.top, 10)
            }

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
                    .background(canProceed ? Color.mint : Color.mint.opacity(0.35), in: RoundedRectangle(cornerRadius: 16))
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
                Image(systemName: recipientMode == .eTransfer ? "paperplane.circle.fill" : "person.crop.circle.fill")
                    .font(.system(size: 46))
                    .foregroundStyle(Color.mint)
                Text(recipientName)
                    .font(.title3.bold())
                    .foregroundStyle(Color.ink)
                if recipientMode == .eTransfer && !trimmedHandle.isEmpty {
                    Text(trimmedHandle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                Text(Currency.string(amount))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
            }
            .padding(.vertical, 24)

            VStack(spacing: 14) {
                summaryRow(label: "From", value: fromAccount?.name ?? "—")
                summaryRow(label: "To", value: recipientMode == .eTransfer ? trimmedHandle : recipientName)
                HStack(alignment: .top, spacing: 12) {
                    Text("Note")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    TextField("Optional", text: $note, axis: .vertical)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .multilineTextAlignment(.trailing)
                        .frame(maxWidth: 180)
                }
                if recipientMode == .eTransfer {
                    HStack(alignment: .top, spacing: 12) {
                        Text("Security question")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        TextField("e.g. Favourite city?", text: $question, axis: .vertical)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 180)
                    }
                    HStack(alignment: .top, spacing: 12) {
                        Text("Answer")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Spacer()
                        SecureField("Answer", text: $answer)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ink)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 180)
                    }
                }
                summaryRow(label: "Fee", value: "No fee")
            }
            .padding(18)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 20))
            .padding(.horizontal, 20)

            Spacer()

            Button {
                if let from = fromAccount {
                    if recipientMode == .eTransfer {
                        store.sendETransfer(from: from.id,
                                            recipientName: trimmedName,
                                            handle: trimmedHandle,
                                            amount: amount,
                                            note: note,
                                            question: question,
                                            answer: answer)
                    } else {
                        store.performTransfer(from: from.id,
                                              toContactID: recipientMode == .contacts ? toContactID : nil,
                                              toAccountID: recipientMode == .accounts ? toAccountID : nil,
                                              amount: amount,
                                              note: note)
                    }
                }
                withAnimation(.snappy) { step = .success }
            } label: {
                Text(recipientMode == .eTransfer ? "Confirm & send e-transfer"
                     : (initialMode == .send ? "Confirm & send" : "Confirm & move"))
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
            Text(recipientMode == .eTransfer ? "E-transfer sent" : "Money sent")
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
        newName = ""
        newHandle = ""
        question = ""
        answer = ""
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
            } else if recipientMode == .contacts {
                if toContact == nil { message = "Choose a contact." }
            } else if recipientMode == .eTransfer {
                if trimmedName.isEmpty {
                    message = "Enter the recipient's name."
                } else if trimmedHandle.isEmpty {
                    message = "Enter an email or mobile number."
                } else if question.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    message = "Set a security question."
                } else if answer.isEmpty {
                    message = "Set the answer to your security question."
                }
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