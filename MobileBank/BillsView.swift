//
//  BillsView.swift
//  MobileBank
//

import SwiftUI

struct ScheduleBillView: View {
    @ObservedObject var store: BankStore
    @Environment(\.dismiss) private var dismiss

    @State private var payeeIndex = -1
    @State private var newPayee = ""
    @State private var amount: Double = 0
    @State private var accountID: UUID?
    @State private var frequency: BillFrequency = .monthly
    @State private var firstDue = Calendar.current.date(byAdding: .day, value: 1, to: Date()) ?? Date()

    private var isValid: Bool {
        let payee = payeeIndex == -1 ? newPayee : store.contacts.indices.contains(payeeIndex) ? store.contacts[payeeIndex].name : ""
        return !payee.isEmpty && amount > 0 && accountID != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Pay to", selection: $payeeIndex) {
                        Text("New payee…").tag(-1)
                        ForEach(Array(store.contacts.enumerated()), id: \.element.id) { index, contact in
                            Text(contact.name).tag(index)
                        }
                    }
                    if payeeIndex == -1 {
                        TextField("Payee name", text: $newPayee)
                    }
                } header: {
                    Text("Payee")
                } footer: {
                    Text("Pick someone from your contacts, or add a new bill payee.")
                }

                Section("Details") {
                    TextField("Amount", value: $amount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold))
                    Picker("From account", selection: $accountID) {
                        ForEach(store.accounts) { account in
                            Text(account.name).tag(account.id as UUID?)
                        }
                    }
                    Picker("Frequency", selection: $frequency) {
                        ForEach(BillFrequency.allCases) { frequency in
                            Text(frequency.rawValue).tag(frequency)
                        }
                    }
                    .pickerStyle(.segmented)
                    DatePicker("First due", selection: $firstDue, in: Date()..., displayedComponents: [.date])
                }
            }
            .navigationTitle("Schedule payment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Schedule") {
                        if let accountID, let index = store.accounts.firstIndex(where: { $0.id == accountID }) {
                            let payee = payeeIndex == -1 ? newPayee : store.contacts[payeeIndex].name
                            store.addBill(payee: payee, amount: amount, accountID: accountID,
                                          frequency: frequency, firstDue: firstDue)
                        }
                        dismiss()
                    }
                    .disabled(!isValid)
                }
            }
            .onAppear {
                if accountID == nil { accountID = store.accounts.first?.id }
            }
        }
        .preferredColorScheme(.light)
    }
}