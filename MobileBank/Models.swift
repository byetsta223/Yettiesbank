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

struct Goal: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var emoji: String
    var colorHex: String
    var target: Double
    var saved: Double

    var fraction: Double {
        target > 0 ? min(saved / target, 1) : 0
    }
    var isReached: Bool {
        saved >= target
    }
}

enum BillFrequency: String, Codable, CaseIterable, Identifiable {
    case weekly = "Weekly"
    case monthly = "Monthly"

    var id: String { rawValue }

    func date(after date: Date) -> Date {
        let calendar = Calendar.current
        switch self {
        case .weekly: return calendar.date(byAdding: .day, value: 7, to: date) ?? date
        case .monthly: return calendar.date(byAdding: .month, value: 1, to: date) ?? date
        }
    }
}

struct BillPayment: Identifiable, Codable, Equatable {
    let id: UUID
    var payee: String
    var amount: Double
    var accountId: UUID
    var frequency: BillFrequency
    var nextDue: Date
}

extension Date {
    private static let dueLabelFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter
    }()

    func dueLabel() -> String {
        Self.dueLabelFormatter.string(from: self)
    }
}

final class BankStore: ObservableObject {
    static let shared = BankStore()

    @Published var accounts: [BankAccount] = []
    @Published var transactions: [Transaction] = []
    @Published var contacts: [Contact] = []
    @Published var goals: [Goal] = []
    @Published var bills: [BillPayment] = []
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
            goals = state.goals ?? seedGoals()
            bills = state.bills ?? seedBills()
            hideBalances = state.hideBalances
            processDueBills()
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

    // MARK: - Goals

    func addGoal(name: String, emoji: String, colorHex: String, target: Double) {
        let goal = Goal(id: UUID(), name: name, emoji: emoji,
                        colorHex: colorHex, target: target, saved: 0)
        goals.append(goal)
        persist()
    }

    func contribute(toGoal goalID: UUID, fromAccount accountID: UUID, amount: Double) {
        guard amount > 0,
              let goalIndex = goals.firstIndex(where: { $0.id == goalID }),
              let accountIndex = accounts.firstIndex(where: { $0.id == accountID }),
              accounts[accountIndex].balance >= amount else { return }

        accounts[accountIndex].balance -= amount
        goals[goalIndex].saved += amount

        let tx = Transaction(id: UUID(), accountId: accountID,
                             merchant: "Saving for \(goals[goalIndex].name)",
                             category: "Internal transfer",
                             icon: "target", amount: -amount, date: Date())
        transactions.insert(tx, at: 0)
        persist()
    }

    func resetDemoData() {
        if let domain = Bundle.main.bundleIdentifier {
            defaults.removePersistentDomain(forName: domain)
        }
        seed()
    }

    // MARK: - Bill payments

    func addBill(payee: String, amount: Double, accountID: UUID, frequency: BillFrequency, firstDue: Date) {
        let bill = BillPayment(id: UUID(), payee: payee, amount: amount,
                               accountId: accountID, frequency: frequency, nextDue: firstDue)
        bills.append(bill)
        persist()
        processDueBills()
    }

    func removeBill(_ id: UUID) {
        bills.removeAll { $0.id == id }
        persist()
    }

    /// Records any payments whose due date has arrived and rolls them forward,
    /// so bills stay up to date whenever the app is used.
    func processDueBills() {
        let now = Date()
        var changed = false

        for index in bills.indices {
            guard let accountIndex = accounts.firstIndex(where: { $0.id == bills[index].accountId }) else { continue }
            var guardCounter = 0
            while bills[index].nextDue <= now, guardCounter < 60 {
                let bill = bills[index]
                accounts[accountIndex].balance -= bill.amount
                let tx = Transaction(id: UUID(), accountId: bill.accountId,
                                     merchant: bill.payee, category: "Bills",
                                     icon: "receipt", amount: -bill.amount, date: bill.nextDue)
                transactions.insert(tx, at: 0)
                bills[index].nextDue = bill.frequency.date(after: bill.nextDue)
                guardCounter += 1
                changed = true
            }
        }
        if changed { persist() }
    }

    // MARK: - Persistence

    private struct StoredState: Codable {
        var accounts: [BankAccount]
        var transactions: [Transaction]
        var contacts: [Contact]
        var goals: [Goal]?
        var bills: [BillPayment]?
        var hideBalances: Bool
    }

    private func persist() {
        let state = StoredState(accounts: accounts, transactions: transactions,
                                contacts: contacts, goals: goals, bills: bills, hideBalances: hideBalances)
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

        goals = seedGoals()
        bills = seedBills()

        persist()
    }

    private func seedGoals() -> [Goal] {
        [
            Goal(id: UUID(), name: "Japan trip", emoji: "✈️", colorHex: "3BB273", target: 5000, saved: 2150),
            Goal(id: UUID(), name: "New laptop", emoji: "💻", colorHex: "F2762E", target: 1500, saved: 1000),
            Goal(id: UUID(), name: "Emergency fund", emoji: "🚨", colorHex: "4C8DF5", target: 2000, saved: 500),
            Goal(id: UUID(), name: "Home deposit", emoji: "🏠", colorHex: "8E6FD8", target: 2500, saved: 2000),
            Goal(id: UUID(), name: "New phone", emoji: "📱", colorHex: "1FA97C", target: 700, saved: 700)
        ]
    }

    private func seedBills() -> [BillPayment] {
        let checkingID = accounts[0].id
        let cal = Calendar.current
        return [
            BillPayment(id: UUID(), payee: "Riverside Apartments", amount: 1650.00,
                        accountId: checkingID, frequency: .monthly,
                        nextDue: cal.date(byAdding: .day, value: 2, to: Date())!),
            BillPayment(id: UUID(), payee: "Spotify Premium", amount: 10.99,
                        accountId: checkingID, frequency: .monthly,
                        nextDue: cal.date(byAdding: .day, value: 5, to: Date())!),
            BillPayment(id: UUID(), payee: "City Gym", amount: 12.50,
                        accountId: checkingID, frequency: .weekly,
                        nextDue: cal.date(byAdding: .day, value: 3, to: Date())!)
        ]
    }
}