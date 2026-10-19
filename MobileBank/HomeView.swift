//
//  HomeView.swift
//  MobileBank
//

import SwiftUI

struct HomeView: View {
    @ObservedObject var store: BankStore
    @AppStorage("signedInName") private var userName = ""

    @State private var showTransfer = false
    @State private var transferMode: TransferMode = .send
    @State private var showAll = false
    @State private var showGoals = false
    @State private var showScheduleBill = false
    @State private var showNotifications = false

    private var firstName: String {
        userName.split(separator: " ").first.map(String.init) ?? "there"
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning,"
        case 12..<18: return "Good afternoon,"
        default: return "Good evening,"
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(greeting)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Text(firstName)
                                .font(.title.bold())
                                .foregroundStyle(Color.ink)
                        }
                        Spacer()
                        bellButton
                    }
                    balanceCard
                    quickActions
                    accountsSection
                    upcomingSection
                    recentSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 30)
            }
            .background(Color.paper.ignoresSafeArea())
            .navigationDestination(isPresented: $showAll) {
                AllTransactionsView(store: store)
            }
            .navigationDestination(isPresented: $showGoals) {
                GoalsView(store: store)
            }
            .navigationDestination(isPresented: $showNotifications) {
                NotificationsView(store: store)
            }
            .sheet(isPresented: $showTransfer) {
                TransferFlowView(store: store, initialMode: transferMode)
            }
            .sheet(isPresented: $showScheduleBill) {
                ScheduleBillView(store: store)
            }
        }
    }

    private var bellButton: some View {
        Button {
            showNotifications = true
        } label: {
            Image(systemName: "bell")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.ink)
                .frame(width: 42, height: 42)
                .background(Circle().fill(Color.white))
                .shadow(color: .black.opacity(0.06), radius: 6, y: 2)
                .overlay(alignment: .topTrailing) {
                    if store.unreadNotificationCount > 0 {
                        Text(store.unreadNotificationCount > 9 ? "9+" : "\(store.unreadNotificationCount)")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4.5)
                            .padding(.vertical, 2.5)
                            .background(Capsule().fill(Color(hex: "E0524D")))
                            .offset(x: 6, y: -5)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private var balanceCard: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26)
                .fill(Color.navy)
            Circle()
                .fill(.white.opacity(0.06))
                .frame(width: 200, height: 200)
                .offset(x: 110, y: -80)
            Circle()
                .fill(.white.opacity(0.04))
                .frame(width: 150, height: 150)
                .offset(x: -120, y: 90)

            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("Total balance")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                    Spacer()
                    Button {
                        withAnimation(.snappy) { store.hideBalances.toggle() }
                    } label: {
                        Image(systemName: store.hideBalances ? "eye.slash" : "eye")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                Text(store.hideBalances ? "$ ••••••" : Currency.string(store.totalBalance))
                    .font(.system(size: 38, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                Text("\(store.accounts.count) accounts · updated just now")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.6))
            }
            .padding(22)
        }
    }

    private var quickActions: some View {
        HStack(spacing: 10) {
            QuickActionButton(icon: "arrow.up.right", title: "Send") {
                transferMode = .send
                showTransfer = true
            }
            QuickActionButton(icon: "plus", title: "Top up") {
                transferMode = .topUp
                showTransfer = true
            }
            QuickActionButton(icon: "target", title: "Goals") {
                showGoals = true
            }
            QuickActionButton(icon: "clock", title: "History") {
                showAll = true
            }
        }
    }

    private var accountsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accounts")
                .font(.headline)
                .foregroundStyle(Color.ink)
            VStack(spacing: 0) {
                ForEach(Array(store.accounts.enumerated()), id: \.element.id) { index, account in
                    NavigationLink {
                        AccountDetailView(store: store, account: account)
                    } label: {
                        accountRow(account)
                    }
                    .buttonStyle(.plain)
                    if index < store.accounts.count - 1 {
                        Divider().padding(.leading, 66)
                    }
                }
            }
            .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }

    private func accountRow(_ account: BankAccount) -> some View {
        HStack(spacing: 14) {
            Text(String(account.name.prefix(1)))
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(hex: account.colorHex)))
            VStack(alignment: .leading, spacing: 3) {
                Text(account.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Text("\(account.kind) · \(account.number)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(store.hideBalances ? "••••" : Currency.string(account.balance))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.ink)
            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Color.subtleText)
        }
        .padding(16)
    }

    private struct UpcomingItem: Identifiable {
        let id: UUID
        let title: String
        let subtitle: String
        let amount: Double
        let icon: String
        let isRecurringTransfer: Bool
        let due: Date
    }

    private var upcomingItems: [UpcomingItem] {
        var items: [UpcomingItem] = []
        for bill in store.bills {
            items.append(UpcomingItem(id: bill.id, title: bill.payee,
                                      subtitle: "\(bill.frequency.rawValue) · due \(bill.nextDue.dueLabel())",
                                      amount: bill.amount, icon: "receipt",
                                      isRecurringTransfer: false, due: bill.nextDue))
        }
        for recurring in store.recurringTransfers {
            items.append(UpcomingItem(id: recurring.id, title: recurring.title,
                                      subtitle: "Repeats \(recurring.frequency.rawValue.lowercased()) · next \(recurring.nextDue.dueLabel())",
                                      amount: recurring.amount,
                                      icon: recurring.kind == .goal ? "target" : "arrow.left.arrow.right",
                                      isRecurringTransfer: true, due: recurring.nextDue))
        }
        return items.sorted { $0.due < $1.due }
    }

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming payments")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Spacer()
                Button {
                    showScheduleBill = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(Color.mint)
                }
            }
            if upcomingItems.isEmpty {
                HStack {
                    Spacer()
                    Text("No upcoming payments scheduled")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(20)
                .frame(maxWidth: .infinity)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(upcomingItems.enumerated()), id: \.element.id) { index, item in
                        upcomingRow(item)
                        if index < upcomingItems.count - 1 {
                            Divider().padding(.leading, 66)
                        }
                    }
                }
                .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
        }
    }

    private func upcomingRow(_ item: UpcomingItem) -> some View {
        HStack(spacing: 14) {
            Image(systemName: item.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.mint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(hex: "E2F3EC")))
            VStack(alignment: .leading, spacing: 3) {
                Text(item.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Text(item.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(store.hideBalances ? "••••" : Currency.string(item.amount))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.ink)
            if item.isRecurringTransfer {
                Button {
                    store.removeRecurringTransfer(item.id)
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.subtleText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove recurring transfer")
            }
        }
        .padding(16)
    }

    private var recentSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent activity")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Spacer()
                Button("See all") { showAll = true }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mint)
            }
            VStack(spacing: 12) {
                ForEach(store.transactions(for: nil).prefix(5)) { tx in
                    EditableTransactionRow(store: store, tx: tx)
                }
            }
            .padding(16)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }
}

struct AccountDetailView: View {
    @ObservedObject var store: BankStore
    let account: BankAccount

    @State private var showExport = false

    var body: some View {
        List {
            Section {
                HStack {
                    Text("Available balance")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(store.hideBalances ? "••••" : Currency.string(account.balance))
                        .font(.title3.bold())
                        .foregroundStyle(Color.ink)
                }
            }
            .listRowBackground(Color.white)

            Section("Activity") {
                ForEach(store.transactions(for: account.id)) { tx in
                    EditableTransactionRow(store: store, tx: tx)
                }
            }
            .listRowBackground(Color.white)
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showExport = true
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(Color.mint)
                }
                .accessibilityLabel("Export statement")
            }
        }
        .sheet(isPresented: $showExport) {
            StatementExportSheet(store: store, account: account)
        }
    }
}

struct StatementExportSheet: View {
    @ObservedObject var store: BankStore
    let account: BankAccount

    @State private var month = Date()
    @State private var fileURL: URL?
    @State private var transactionCount = 0

    private var isCurrentMonth: Bool {
        Calendar.current.isDate(month, equalTo: Date(), toGranularity: .month)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: month)
    }

    var body: some View {
        VStack(spacing: 18) {
            Text("Export statement")
                .font(.headline)
                .foregroundStyle(Color.ink)

            HStack {
                Button {
                    month = Calendar.current.date(byAdding: .month, value: -1, to: month) ?? month
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white))
                }
                Spacer()
                Text(monthTitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Spacer()
                Button {
                    month = Calendar.current.date(byAdding: .month, value: 1, to: month) ?? month
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Color.ink)
                        .frame(width: 40, height: 40)
                        .background(Circle().fill(Color.white))
                }
                .disabled(isCurrentMonth)
                .opacity(isCurrentMonth ? 0.3 : 1)
            }

            Text("\(transactionCount) transaction\(transactionCount == 1 ? "" : "s") in this month")
                .font(.caption)
                .foregroundStyle(.secondary)

            if let fileURL {
                ShareLink(item: fileURL, preview: SharePreview("Statement — \(account.name), \(monthTitle)")) {
                    Label("Export statement", systemImage: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Color.mint))
                }
            } else {
                Text("Could not prepare the statement.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color.paper)
        .presentationDetents([.height(240)])
        .onAppear { prepare() }
        .onChange(of: month) { _ in prepare() }
    }

    private func prepare() {
        fileURL = nil
        let calendar = Calendar.current
        let interval = calendar.dateInterval(of: .month, for: month) ?? DateInterval()
        transactionCount = store.transactions(for: account.id).filter { interval.contains($0.date) }.count

        let idFormatter = DateFormatter()
        idFormatter.dateFormat = "yyyy-MM"
        let safeName = account.name.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("Statement - \(safeName) - \(idFormatter.string(from: month)).csv")

        let csv = store.statementCSV(for: account.id, month: month)
        do {
            try csv.data(using: .utf8)?.write(to: url)
            fileURL = url
        } catch {
            fileURL = nil
        }
    }
}

struct AllTransactionsView: View {
    @ObservedObject var store: BankStore
    @State private var filterID: UUID?
    @State private var searchText = ""

    private var matches: [Transaction] {
        store.transactions(for: filterID).filter { searchMatches($0, query: searchText) }
    }

    private func searchMatches(_ tx: Transaction, query: String) -> Bool {
        let query = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return true }
        if tx.merchant.lowercased().contains(query) { return true }
        if tx.category.lowercased().contains(query) { return true }
        let plainAmount = String(format: "%.2f", abs(tx.amount))
        if plainAmount.contains(query) { return true }
        if plainAmount.replacingOccurrences(of: ".", with: "").contains(query.replacingOccurrences(of: ".", with: "")) { return true }
        if Currency.string(abs(tx.amount)).lowercased().contains(query) { return true }
        return false
    }

    private var grouped: [(day: String, items: [Transaction])] {
        var result: [(String, [Transaction])] = []
        for tx in matches {
            let label = tx.date.dayLabel()
            if result.last?.0 == label {
                result[result.count - 1].1.append(tx)
            } else {
                result.append((label, [tx]))
            }
        }
        return result.map { (day: $0.0, items: $0.1) }
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip("All", selected: filterID == nil) { filterID = nil }
                    ForEach(store.accounts) { account in
                        chip(account.name, selected: filterID == account.id) {
                            filterID = account.id
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }
            if !searchText.isEmpty && matches.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 28, weight: .medium))
                        .foregroundStyle(Color.subtleText)
                    Text("No results for \"\(searchText)\"")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Try a merchant, category or amount")
                        .font(.caption)
                        .foregroundStyle(Color.subtleText)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(grouped, id: \.day) { group in
                        Section(group.day) {
                            ForEach(group.items) { tx in
                                EditableTransactionRow(store: store, tx: tx)
                            }
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
        .background(Color.paper)
        .navigationTitle("All activity")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search transactions")
        .onDisappear {
            searchText = ""
        }
    }

    private func chip(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(selected ? .white : Color.ink)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(selected ? Color.mint : Color.white, in: Capsule())
        }
    }
}