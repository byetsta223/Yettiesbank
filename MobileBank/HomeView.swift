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
                    VStack(alignment: .leading, spacing: 2) {
                        Text(greeting)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(firstName)
                            .font(.title.bold())
                            .foregroundStyle(Color.ink)
                    }
                    balanceCard
                    quickActions
                    accountsSection
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
            .sheet(isPresented: $showTransfer) {
                TransferFlowView(store: store, initialMode: transferMode)
            }
        }
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
        HStack(spacing: 12) {
            QuickActionButton(icon: "arrow.up.right", title: "Send") {
                transferMode = .send
                showTransfer = true
            }
            QuickActionButton(icon: "plus", title: "Top up") {
                transferMode = .topUp
                showTransfer = true
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

    private var grouped: [(day: String, items: [Transaction])] {
        var result: [(String, [Transaction])] = []
        for tx in store.transactions(for: filterID) {
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
        .background(Color.paper)
        .navigationTitle("All activity")
        .navigationBarTitleDisplayMode(.inline)
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