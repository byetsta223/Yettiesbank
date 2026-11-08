//
//  InsightsView.swift
//  YettiesBank
//

import SwiftUI

struct CategoryInsight: Identifiable {
    let name: String
    let icon: String
    let colorHex: String
    let bgHex: String
    let total: Double
    var id: String { name }
}

struct MerchantInsight: Identifiable {
    let merchant: String
    let icon: String
    let colorHex: String
    let count: Int
    let total: Double
    var id: String { merchant }
}

struct InsightsView: View {
    @ObservedObject var store: BankStore
    @AppStorage("monthlyBudget") private var monthlyBudget: Double = 3000
    @State private var monthOffset = 0
    @State private var showBudgetEditor = false

    private let calendar = Calendar.current

    private var monthFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM"
        return formatter
    }

    private var monthDate: Date {
        calendar.date(byAdding: .month, value: monthOffset, to: Date()) ?? Date()
    }

    private var previousMonthDate: Date {
        calendar.date(byAdding: .month, value: -1, to: monthDate) ?? Date()
    }

    private func monthInterval(for date: Date) -> DateInterval {
        calendar.dateInterval(of: .month, for: date) ?? DateInterval(start: date, duration: 1)
    }

    private func spending(in interval: DateInterval) -> [Transaction] {
        store.transactions.filter { tx in
            tx.amount < 0
                && tx.category != "Internal transfer"
                && interval.contains(tx.date)
        }
    }

    private var monthSpending: [Transaction] { spending(in: monthInterval(for: monthDate)) }
    private var totalSpent: Double { monthSpending.map { -$0.amount }.reduce(0, +) }
    private var previousSpent: Double {
        spending(in: monthInterval(for: previousMonthDate)).map { -$0.amount }.reduce(0, +)
    }

    private var monthPercent: Int? {
        guard previousSpent > 0, abs(previousSpent - totalSpent) > 0.005 else { return nil }
        return Int((abs(previousSpent - totalSpent) / previousSpent * 100).rounded())
    }

    private var categoryTotals: [CategoryInsight] {
        Dictionary(grouping: monthSpending, by: { $0.category })
            .map { category, txs in
                let style = Self.style(for: category)
                return CategoryInsight(name: category, icon: style.icon,
                                       colorHex: style.colorHex, bgHex: style.bgHex,
                                       total: txs.map { -$0.amount }.reduce(0, +))
            }
            .sorted { $0.total > $1.total }
    }

    private var topMerchants: [MerchantInsight] {
        Dictionary(grouping: monthSpending, by: { $0.merchant })
            .map { merchant, txs in
                let style = Self.style(for: txs.first?.category ?? "")
                return MerchantInsight(merchant: merchant, icon: style.icon,
                                       colorHex: style.colorHex,
                                       count: txs.count,
                                       total: txs.map { -$0.amount }.reduce(0, +))
            }
            .sorted { $0.total > $1.total }
            .prefix(5)
            .map { $0 }
    }

    static func style(for category: String) -> (icon: String, colorHex: String, bgHex: String) {
        switch category {
        case "Groceries": return ("cart.fill", "2FA36B", "DFF3E7")
        case "Food & drink": return ("fork.knife", "E0784A", "FBE9DE")
        case "Transport": return ("car.fill", "3F6BD6", "E1E8FA")
        case "Subscriptions": return ("tv.fill", "8E6FD8", "ECE6FA")
        case "Electronics": return ("desktopcomputer", "6B7280", "EDEFF2")
        case "Travel": return ("airplane", "4EA58B", "E2F3EC")
        case "Cash": return ("banknote.fill", "D08A3E", "FBEFDF")
        case "Bills": return ("receipt", "4C8DF5", "E1E8FA")
        case "Income": return ("banknote.fill", "0E7C5A", "E2F3EC")
        default: return ("creditcard.fill", "6B7280", "EDEFF2")
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header

                    if monthSpending.isEmpty {
                        emptyCard
                    } else {
                        totalSection
                        categoryCard
                        merchantsCard
                        budgetCard
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 30)
            }
            .background(Color.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showBudgetEditor) {
                BudgetEditorView(budget: $monthlyBudget)
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(alignment: .center) {
            Text("Insights")
                .font(.system(size: 32, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
            Spacer()
            monthStepper
        }
    }

    private var monthStepper: some View {
        HStack(spacing: 2) {
            Button {
                monthOffset -= 1
            } label: {
                Image(systemName: "chevron.left")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .frame(width: 32, height: 32)
            }
            Text(monthFormatter.string(from: monthDate))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.ink)
                .frame(minWidth: 78)
            Button {
                if monthOffset < 0 { monthOffset += 1 }
            } label: {
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(monthOffset < 0 ? Color.ink : Color(hex: "C6CAD3"))
                    .frame(width: 32, height: 32)
            }
            .disabled(monthOffset >= 0)
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Color.white, in: Capsule())
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    private var totalSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Total spent")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(alignment: .top) {
                Text(Currency.string(totalSpent))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                Spacer()
                if let percent = monthPercent {
                    let less = totalSpent < previousSpent
                    HStack(spacing: 4) {
                        Image(systemName: less ? "arrow.down" : "arrow.up")
                            .font(.caption.weight(.bold))
                        Text("\(percent)%")
                            .font(.subheadline.weight(.bold))
                    }
                    .foregroundStyle(Color(hex: less ? "1E8A63" : "D24E4E"))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 7)
                    .background(Capsule().fill(Color(hex: less ? "E2F3EC" : "FBE4E4")))
                }
            }
            if let percent = monthPercent {
                Text("\(percent)% \(totalSpent < previousSpent ? "less" : "more") than \(monthFormatter.string(from: previousMonthDate))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var categoryCard: some View {
        card {
            Text("Spending by category")
                .font(.headline)
                .foregroundStyle(Color.ink)
            let maxTotal = categoryTotals.first?.total ?? 1
            ForEach(categoryTotals) { item in
                HStack(spacing: 14) {
                    Image(systemName: item.icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(hex: item.colorHex))
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(Color(hex: item.bgHex)))
                    Text(item.name)
                        .font(.subheadline)
                        .foregroundStyle(Color.ink)
                        .frame(width: 104, alignment: .leading)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color(hex: "F0F1F4"))
                            Capsule()
                                .fill(Color(hex: item.colorHex))
                                .frame(width: geo.size.width * CGFloat(max(item.total / maxTotal, 0.02)))
                        }
                    }
                    .frame(height: 12)
                    Text(Currency.string(item.total))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.ink)
                        .frame(minWidth: 74, alignment: .trailing)
                }
            }
        }
    }

    private var merchantsCard: some View {
        card {
            HStack {
                Text("Top merchants")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Spacer()
                NavigationLink {
                    AllTransactionsView(store: store)
                } label: {
                    HStack(spacing: 3) {
                        Text("See all")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.mint)
                        Image(systemName: "chevron.right")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.mint)
                    }
                }
            }
            .padding(.bottom, 8)

            ForEach(Array(topMerchants.enumerated()), id: \.element.id) { index, item in
                HStack(spacing: 14) {
                    Image(systemName: item.icon)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(Color(hex: item.colorHex)))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.merchant)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Color.ink)
                            .lineLimit(1)
                        Text(item.count == 1 ? "1 transaction" : "\(item.count) transactions")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(Currency.string(item.total))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.ink)
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color(hex: "C6CAD3"))
                }
                .padding(.vertical, 10)
                if index < topMerchants.count - 1 {
                    Divider()
                }
            }
        }
    }

    private var budgetCard: some View {
        card(spacing: 14) {
            HStack {
                Text("Monthly budget")
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Spacer()
                Button {
                    showBudgetEditor = true
                } label: {
                    Text(Currency.string(monthlyBudget, cents: false))
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(Color.ink)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(hex: "F0F1F4"), in: Capsule())
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color(hex: "EEF0F3"))
                    Capsule()
                        .fill(Color(hex: "1FA97C"))
                        .frame(width: geo.size.width * budgetFraction)
                }
            }
            .frame(height: 14)
            HStack {
                Text("\(Currency.string(totalSpent)) spent")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Spacer()
                let remaining = monthlyBudget - totalSpent
                if remaining >= 0 {
                    Text("\(Currency.string(remaining, cents: false)) left")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color(hex: "1E8A63"))
                } else {
                    Text("\(Currency.string(-remaining)) over budget")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(Color(hex: "D24E4E"))
                }
            }
        }
    }

    private var budgetFraction: CGFloat {
        guard monthlyBudget > 0 else { return 0 }
        return CGFloat(min(max(totalSpent / monthlyBudget, 0), 1))
    }

    private var emptyCard: some View {
        card {
            VStack(spacing: 10) {
                Image(systemName: "chart.bar")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(Color(hex: "C6CAD3"))
                Text("No spending this month")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                Text("Payments you make in \(monthFormatter.string(from: monthDate)) will appear here.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 18)
        }
    }

    private func card<Content: View>(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: spacing) {
            content()
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.04), radius: 10, y: 3)
    }
}

struct BudgetEditorView: View {
    @Binding var budget: Double
    @Environment(\.dismiss) private var dismiss
    @State private var draft: Double = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Amount", value: $draft, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold))
                } header: {
                    Text("Monthly budget")
                } footer: {
                    Text("Your budget powers the progress bar at the bottom of Insights.")
                }
            }
            .navigationTitle("Edit budget")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        budget = max(draft, 0)
                        dismiss()
                    }
                }
            }
            .onAppear { draft = budget }
        }
        .preferredColorScheme(.light)
    }
}