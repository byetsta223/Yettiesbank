//
//  Models.swift
//  MobileBank
//

import Foundation

enum Currency {
    static func string(_ value: Double, showSign: Bool = false, cents: Bool = true) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "USD"
        formatter.maximumFractionDigits = cents ? 2 : 0
        let base = formatter.string(from: NSNumber(value: abs(value))) ?? "$0.00"
        if showSign {
            return value < 0 ? "-\(base)" : "+\(base)"
        }
        return base
    }
}

struct BankAccount: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var kind: String
    var number: String
    var balance: Double
    var colorHex: String
    var isCard: Bool
    var cardNumber: String
    var expiry: String
    var isFrozen: Bool
    var contactless: Bool
    var onlinePayments: Bool
    var atmWithdrawals: Bool

    var maskedCardNumber: String {
        guard cardNumber.count >= 4 else { return "•••• 0000" }
        return "•••• " + String(cardNumber.suffix(4))
    }

    var formattedCardNumber: String {
        let digits = cardNumber.prefix(16)
        return stride(from: 0, to: digits.count, by: 4)
            .map { String(digits[digits.index(digits.startIndex, offsetBy: $0)..<digits.index(digits.startIndex, offsetBy: min($0 + 4, digits.count))]) }
            .joined(separator: " ")
    }
}

struct Transaction: Identifiable, Codable, Equatable {
    let id: UUID
    var accountId: UUID
    var merchant: String
    var category: String
    var icon: String
    var amount: Double
    var date: Date
}

struct Contact: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var handle: String
    var colorHex: String
}

final class BankStore: ObservableObject {
    static let shared = BankStore()

    @Published var accounts: [BankAccount] = []
    @Published var transactions: [Transaction] = []
    @Published var contacts: [Contact] = []
    @Published var hideBalances = false {
        didSet { persist() }
    }

    private let defaults = UserDefaults.standard
    private let storageKey = "bank.state.v1"

    private init() {
        if let data = defaults.data(forKey: storageKey),
           let state = try? JSONDecoder().decode(StoredState.self, from: data) {
            accounts = state.accounts
            transactions = state.transactions
            contacts = state.contacts
            hideBalances = state.hideBalances
        } else {
            seed()
        }
    }

    var totalBalance: Double {
        accounts.map(\.balance).reduce(0, +)
    }

    func transactions(for accountID: UUID?) -> [Transaction] {
        transactions
            .filter { accountID == nil || $0.accountId == accountID }
            .sorted { $0.date > $1.date }
    }

    func update(account id: UUID, _ modify: (inout BankAccount) -> Void) {
        if let index = accounts.firstIndex(where: { $0.id == id }) {
            modify(&accounts[index])
        }
    }

    func toggleFreeze(_ id: UUID) {
        update(account: id) { $0.isFrozen.toggle() }
    }

    func performTransfer(from fromID: UUID, toContactID: UUID?, toAccountID: UUID?, amount: Double, note: String) {
        guard amount > 0,
              let fromIndex = accounts.firstIndex(where: { $0.id == fromID }) else { return }
        let now = Date()

        if let toContact = contacts.first(where: { $0.id == toContactID }) {
            accounts[fromIndex].balance -= amount
            let tx = Transaction(id: UUID(), accountId: fromID,
                                 merchant: note.isEmpty ? toContact.name : toContact.name,
                                 category: note.isEmpty ? "Transfers" : note,
                                 icon: "person.fill", amount: -amount, date: now)
            transactions.insert(tx, at: 0)
        } else if let toID = toAccountID, let toIndex = accounts.firstIndex(where: { $0.id == toID }) {
            accounts[fromIndex].balance -= amount
            accounts[toIndex].balance += amount
            transactions.insert(Transaction(id: UUID(), accountId: fromID,
                                            merchant: "To \(accounts[toIndex].name)",
                                            category: "Internal transfer",
                                            icon: "arrow.left.arrow.right", amount: -amount, date: now), at: 0)
            transactions.insert(Transaction(id: UUID(), accountId: toID,
                                            merchant: "From \(accounts[fromIndex].name)",
                                            category: "Internal transfer",
                                            icon: "arrow.left.arrow.right", amount: amount, date: now), at: 0)
        }
    }

    func resetDemoData() {
        if let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        }
        seed()
    }

    // MARK: - Persistence

    private struct StoredState: Codable {
        var accounts: [BankAccount]
        var transactions: [Transaction]
        var contacts: [Contact]
        var hideBalances: Bool
    }

    private func persist() {
        let state = StoredState(accounts: accounts, transactions: transactions,
                                contacts: contacts, hideBalances: hideBalances)
        if let data = try? JSONEncoder().encode(state) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func seed() {
        let checkingID = UUID()
        let savingsID = UUID()
        let travelID = UUID()

        accounts = [
            BankAccount(id: checkingID, name: "Everyday", kind: "Checking",
                        number: "•• 4821", balance: 4820.55, colorHex: "1C2540",
                        isCard: true, cardNumber: "4293881045214821", expiry: "04/29",
                        isFrozen: false, contactless: true, onlinePayments: true, atmWithdrawals: true),
            BankAccount(id: savingsID, name: "High-Yield Savings", kind: "Savings",
                        number: "•• 9034", balance: 12300.00, colorHex: "0E6B4F",
                        isCard: false, cardNumber: "", expiry: "",
                        isFrozen: false, contactless: false, onlinePayments: true, atmWithdrawals: false),
            BankAccount(id: travelID, name: "Travel", kind: "Prepaid card",
                        number: "•• 7712", balance: 340.20, colorHex: "35507B",
                        isCard: true, cardNumber: "5412751234567712", expiry: "09/28",
                        isFrozen: false, contactless: true, onlinePayments: true, atmWithdrawals: true)
        ]

        contacts = [
            Contact(id: UUID(), name: "Maya Chen", handle: "@maya", colorHex: "D96A7B"),
            Contact(id: UUID(), name: "Dev Patel", handle: "@devp", colorHex: "5B7BD5"),
            Contact(id: UUID(), name: "Sofia Rossi", handle: "@sofia", colorHex: "D08A3E"),
            Contact(id: UUID(), name: "Jonah Blake", handle: "@jonah", colorHex: "4EA58B")
        ]

        let cal = Calendar.current
        func days(_ n: Int, _ hours: Int = 0) -> Date {
            cal.date(byAdding: .hour, value: -(n * 24 + hours), to: Date())!
        }

        transactions = [
            Transaction(id: UUID(), accountId: checkingID, merchant: "Blue Bottle Coffee", category: "Food & drink", icon: "cup.and.saucer.fill", amount: -4.80, date: days(0, 2)),
            Transaction(id: UUID(), accountId: checkingID, merchant: "Uber", category: "Transport", icon: "car.fill", amount: -18.40, date: days(1, 4)),
            Transaction(id: UUID(), accountId: travelID, merchant: "Airbnb", category: "Travel", icon: "airplane", amount: -212.00, date: days(2, 1)),
            Transaction(id: UUID(), accountId: checkingID, merchant: "Salary — Meridian Labs", category: "Income", icon: "banknote.fill", amount: 3450.00, date: days(3, 6)),
            Transaction(id: UUID(), accountId: checkingID, merchant: "Whole Foods Market", category: "Groceries", icon: "cart.fill", amount: -86.25, date: days(3, 9)),
            Transaction(id: UUID(), accountId: travelID, merchant: "Metro Card Top-up", category: "Transport", icon: "tram.fill", amount: -30.00, date: days(4, 3)),
            Transaction(id: UUID(), accountId: checkingID, merchant: "Spotify", category: "Subscriptions", icon: "music.note", amount: -10.99, date: days(4, 7)),
            Transaction(id: UUID(), accountId: savingsID, merchant: "Monthly transfer in", category: "Internal transfer", icon: "arrow.down.left", amount: 500.00, date: days(5, 2)),
            Transaction(id: UUID(), accountId: travelID, merchant: "Café de Paris", category: "Food & drink", icon: "cup.and.saucer.fill", amount: -14.60, date: days(5, 5)),
            Transaction(id: UUID(), accountId: travelID, merchant: "Refund — Booking.com", category: "Refund", icon: "arrow.uturn.left", amount: 45.00, date: days(6, 2)),
            Transaction(id: UUID(), accountId: checkingID, merchant: "Apple Store", category: "Electronics", icon: "desktopcomputer", amount: -249.00, date: days(6, 8)),
            Transaction(id: UUID(), accountId: checkingID, merchant: "ATM Withdrawal", category: "Cash", icon: "banknote", amount: -100.00, date: days(7, 3)),
            Transaction(id: UUID(), accountId: savingsID, merchant: "Interest", category: "Income", icon: "percent", amount: 21.40, date: days(8, 1))
        ]

        persist()
    }
}