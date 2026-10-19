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
            if store.bills.isEmpty {
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
                    ForEach(Array(store.bills.sorted { $0.nextDue < $1.nextDue }.enumerated()), id: \.element.id) { index, bill in
                        billRow(bill)
                        if index < store.bills.count - 1 {
                            Divider().padding(.leading, 66)
                        }
                    }
                }
                .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
        }
    }

    private func billRow(_ bill: BillPayment) -> some View {
        HStack(spacing: 14) {
            Image(systemName: "receipt")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Color.mint)
                .frame(width: 40, height: 40)
                .background(Circle().fill(Color(hex: "E2F3EC")))
            VStack(alignment: .leading, spacing: 3) {
                Text(bill.payee)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Text("\(bill.frequency.rawValue) · due \(bill.nextDue.dueLabel())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(store.hideBalances ? "••••" : Currency.string(bill.amount))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color.ink)
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
                    TransactionRow(tx: tx)
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
                    TransactionRow(tx: tx)
                }
            }
            .listRowBackground(Color.white)
        }
        .scrollContentBackground(.hidden)
        .background(Color.paper)
        .navigationTitle(account.name)
        .navigationBarTitleDisplayMode(.inline)
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
                                TransactionRow(tx: tx)
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