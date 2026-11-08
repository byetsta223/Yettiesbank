//
//  TransactionEditSheet.swift
//  YettiesBank
//

import SwiftUI

/// A transaction row that opens the edit sheet when tapped.
/// Used in every activity list (Home, account detail, All activity).
struct EditableTransactionRow: View {
    @ObservedObject var store: BankStore
    let tx: Transaction

    @State private var showEdit = false

    var body: some View {
        TransactionRow(tx: tx)
            .contentShape(Rectangle())
            .onTapGesture { showEdit = true }
            .sheet(isPresented: $showEdit) {
                TransactionEditSheet(store: store, transaction: tx)
            }
    }
}

/// Small sheet for editing a transaction's merchant name and category.
/// Editing never changes any account balance.
struct TransactionEditSheet: View {
    @ObservedObject var store: BankStore
    let transaction: Transaction

    @Environment(\.dismiss) private var dismiss
    @State private var merchant = ""
    @State private var category = ""

    private var categories: [String] {
        var list = store.editorCategories
        if !list.contains(transaction.category) {
            list.insert(transaction.category, at: 0)
        }
        return list
    }

    private var canSave: Bool {
        !merchant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !category.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(spacing: 4) {
                Text("Edit transaction")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text("\(Currency.string(transaction.amount, showSign: true)) · \(transaction.date.dayLabel())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text("Merchant")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                TextField("Merchant name", text: $merchant)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .padding(14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Category")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Menu {
                    ForEach(categories, id: \.self) { name in
                        Button {
                            category = name
                        } label: {
                            if name == category {
                                Label(name, systemImage: "checkmark")
                            } else {
                                Text(name)
                            }
                        }
                    }
                } label: {
                    HStack {
                        Text(category.isEmpty ? "Choose a category" : category)
                            .foregroundStyle(category.isEmpty ? Color.subtleText : Color.ink)
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(Color.subtleText)
                    }
                    .font(.subheadline.weight(.semibold))
                    .padding(14)
                    .background(Color.white, in: RoundedRectangle(cornerRadius: 14))
                }
            }

            Button {
                store.updateTransaction(transaction.id, merchant: merchant, category: category)
                dismiss()
            } label: {
                Text("Save changes")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(canSave ? Color.mint : Color(hex: "B9C0CB"), in: RoundedRectangle(cornerRadius: 14))
            }
            .disabled(!canSave)

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color.paper)
        .presentationDetents([.height(360)])
        .onAppear {
            merchant = transaction.merchant
            category = transaction.category
        }
    }
}