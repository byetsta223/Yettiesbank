//
//  GoalsView.swift
//  YettiesBank
//

import SwiftUI

struct GoalsView: View {
    @ObservedObject var store: BankStore

    @State private var showCreate = false
    @State private var contributeTarget: Goal?

    private var totalSaved: Double { store.goals.map(\.saved).reduce(0, +) }
    private var totalTarget: Double { store.goals.map(\.target).reduce(0, +) }
    private var overallPercent: Int {
        totalTarget > 0 ? Int((totalSaved / totalTarget * 100).rounded()) : 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    totalCard
                    ForEach(store.goals) { goal in
                        GoalCard(goal: goal) {
                            contributeTarget = goal
                        }
                    }
                    if store.goals.isEmpty {
                        emptyCard
                    }
                    Text("Tap + to start a new goal")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 6)
                }
                .padding(.horizontal, 20)
                .padding(.top, 6)
                .padding(.bottom, 30)
            }
            .background(Color.paper.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $showCreate) {
                CreateGoalView(store: store)
            }
            .sheet(item: $contributeTarget) { goal in
                ContributeView(store: store, goal: goal)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center) {
            Text("Goals")
                .font(.system(size: 34, weight: .bold, design: .default))
                .foregroundStyle(Color.ink)
            Spacer()
            Button {
                showCreate = true
            } label: {
                Image(systemName: "plus")
                    .font(.system(size: 18, weight: .bold))
                    .foregroundStyle(Color.mint)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Color.white))
                    .shadow(color: .black.opacity(0.07), radius: 10, y: 3)
            }
        }
        .padding(.top, 8)
    }

    private var totalCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Total saved across goals")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(Currency.string(totalSaved))
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ink)
                overallCaption
            }
            Spacer()
            coinsIllustration
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
    }

    private var overallCaption: some View {
        HStack(spacing: 0) {
            Text("You're ")
                .foregroundStyle(.secondary)
            Text("\(overallPercent)%")
                .fontWeight(.bold)
                .foregroundStyle(Color.ink)
            Text(" to your total goal of \(Currency.string(totalTarget, cents: false))")
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }

    private var coinsIllustration: some View {
        ZStack(alignment: .bottom) {
            VStack(spacing: -7) {
                coin(fill: Color(hex: "A9E3C6"), rim: Color(hex: "8FD9B4"))
                coin(fill: Color(hex: "8FD9B4"), rim: Color(hex: "6BC7A0"))
                coin(fill: Color(hex: "6BC7A0"), rim: Color(hex: "4FB68C"))
            }
            .offset(x: 12)
            coin(fill: Color(hex: "C9EED9"), rim: Color(hex: "A9E3C6"))
                .scaleEffect(0.8)
                .offset(x: -32, y: -2)
        }
        .frame(width: 110, height: 78)
    }

    private func coin(fill: Color, rim: Color) -> some View {
        ZStack(alignment: .top) {
            Ellipse()
                .fill(fill)
                .frame(width: 52, height: 22)
            Ellipse()
                .fill(rim)
                .frame(width: 52, height: 22)
                .offset(y: -4)
                .mask(Ellipse().frame(width: 52, height: 22))
        }
    }

    private var emptyCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "target")
                .font(.system(size: 30))
                .foregroundStyle(Color.mint)
            Text("No goals yet")
                .font(.headline)
                .foregroundStyle(Color.ink)
            Text("Start saving for something you care about.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(28)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 24))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
    }
}

// MARK: - Goal card

struct GoalCard: View {
    let goal: Goal
    var onAdd: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            ProgressRingView(fraction: goal.fraction, colorHex: goal.colorHex)
            VStack(alignment: .leading, spacing: 3) {
                Text(goal.name)
                    .font(.headline)
                    .foregroundStyle(Color.ink)
                Text("\(Currency.string(goal.saved, cents: false)) saved of \(Currency.string(goal.target, cents: false))")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if goal.isReached {
                    Text("Goal reached")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.mint)
                }
            }
            Spacer()
            Button(action: onAdd) {
                Text("Add")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(goal.isReached ? Color.subtleText : Color.mint)
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Capsule().fill(goal.isReached ? Color(hex: "EFEFF2") : Color(hex: "E2F3EC")))
            }
            .disabled(goal.isReached)
        }
        .padding(18)
        .background(Color.white, in: RoundedRectangle(cornerRadius: 22))
        .shadow(color: .black.opacity(0.05), radius: 10, y: 3)
    }
}

// MARK: - Progress ring

struct ProgressRingView: View {
    let fraction: Double
    let colorHex: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color(hex: "ECEEF1"), lineWidth: 9)
            Circle()
                .trim(from: 0, to: fraction)
                .stroke(Color(hex: colorHex), style: StrokeStyle(lineWidth: 9, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text("\(Int((fraction * 100).rounded()))%")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(Color.ink)
        }
        .frame(width: 68, height: 68)
        .animation(.snappy, value: fraction)
    }
}

// MARK: - Create goal

struct CreateGoalView: View {
    @ObservedObject var store: BankStore
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var emoji = "✈️"
    @State private var colorHex = "3BB273"
    @State private var target: Double = 0

    private let emojis = ["✈️", "💻", "🚨", "🏠", "📱", "🚗", "🎓", "💍", "🏖️", "🎸"]
    private let colors = ["3BB273", "F2762E", "4C8DF5", "8E6FD8", "1FA97C", "D96A7B", "D08A3E", "35507B"]

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && target > 0
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Goal") {
                    TextField("Name (e.g. Japan trip)", text: $name)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Icon").font(.footnote).foregroundStyle(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(emojis, id: \.self) { item in
                                    Button {
                                        emoji = item
                                    } label: {
                                        Text(item)
                                            .font(.system(size: 24))
                                            .frame(width: 46, height: 46)
                                            .background(Circle().fill(Color(hex: "F2F3F5")))
                                            .overlay(Circle().stroke(emoji == item ? Color.mint : .clear, lineWidth: 2))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Color").font(.footnote).foregroundStyle(.secondary)
                        HStack(spacing: 12) {
                            ForEach(colors, id: \.self) { hex in
                                Button {
                                    colorHex = hex
                                } label: {
                                    Circle()
                                        .fill(Color(hex: hex))
                                        .frame(width: 32, height: 32)
                                        .overlay(Circle().stroke(colorHex == hex ? Color.ink : .clear, lineWidth: 2))
                                        .overlay(Circle().stroke(.white, lineWidth: colorHex == hex ? 2 : 0))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section("Target amount") {
                    TextField("Target", value: $target, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold))
                }
            }
            .navigationTitle("New goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        store.addGoal(name: name.trimmingCharacters(in: .whitespaces),
                                      emoji: emoji, colorHex: colorHex, target: target)
                        dismiss()
                    }
                    .disabled(!canCreate)
                }
            }
        }
        .preferredColorScheme(.light)
    }
}

// MARK: - Contribute to goal

struct ContributeView: View {
    @ObservedObject var store: BankStore
    let goal: Goal

    @Environment(\.dismiss) private var dismiss
    @State private var accountID: UUID?
    @State private var amount: Double = 0
    @State private var repeatFrequency: BillFrequency?

    private var account: BankAccount? {
        store.accounts.first { $0.id == accountID } ?? store.accounts.first
    }

    private var remaining: Double { max(goal.target - goal.saved, 0) }
    private var afterSaving: Double { goal.saved + max(amount, 0) }

    private var exceedsBalance: Bool {
        (account?.balance ?? 0) < amount
    }

    private var canContribute: Bool {
        amount > 0 && !exceedsBalance && !goal.isReached
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 14) {
                        Text(goal.emoji)
                            .font(.system(size: 28))
                            .frame(width: 52, height: 52)
                            .background(Circle().fill(Color(hex: "F2F3F5")))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(goal.name).font(.headline).foregroundStyle(Color.ink)
                            Text("\(Currency.string(goal.saved, cents: false)) of \(Currency.string(goal.target, cents: false)) · \(Int((goal.fraction * 100).rounded()))%")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        ProgressRingView(fraction: goal.fraction, colorHex: goal.colorHex)
                            .scaleEffect(0.85)
                    }
                }

                Section("From account") {
                    ForEach(store.accounts) { acc in
                        Button {
                            accountID = acc.id
                        } label: {
                            HStack {
                                Text(String(acc.name.prefix(1)))
                                    .font(.system(size: 15, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 34, height: 34)
                                    .background(Circle().fill(Color(hex: acc.colorHex)))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(acc.name).font(.subheadline.weight(.semibold)).foregroundStyle(Color.ink)
                                    Text(Currency.string(acc.balance))
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: account?.id == acc.id ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(account?.id == acc.id ? Color.mint : Color.subtleText)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }

                Section {
                    TextField("Amount", value: $amount, format: .currency(code: "USD"))
                        .keyboardType(.decimalPad)
                        .font(.title3.weight(.semibold))
                    HStack(spacing: 8) {
                        ForEach([50.0, 100.0, 500.0], id: \.self) { chip in
                            Button("+ \(Currency.string(chip, cents: false))") {
                                amount += chip
                            }
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.mint)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Capsule().fill(Color(hex: "E2F3EC")))
                        }
                    }
                } header: {
                    Text("Amount")
                } footer: {
                    if exceedsBalance {
                        Text("Amount exceeds the account balance.")
                            .foregroundStyle(Color(hex: "D24E4E"))
                    } else {
                        Text("After this: \(Currency.string(afterSaving, cents: false)) of \(Currency.string(goal.target, cents: false)) saved.")
                    }
                }

                Section {
                    Picker("Repeat", selection: $repeatFrequency) {
                        Text("One time").tag(BillFrequency?.none)
                        Text("Weekly").tag(BillFrequency?.some(.weekly))
                        Text("Monthly").tag(BillFrequency?.some(.monthly))
                    }
                } header: {
                    Text("Repeat")
                } footer: {
                    if let frequency = repeatFrequency {
                        Text("Today's contribution goes through now; it repeats \(frequency.rawValue.lowercased()) after that. Remove it any time under Upcoming payments on Home.")
                    }
                }
            }
            .navigationTitle("Contribute")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add to goal") {
                        if let acc = account {
                            store.contribute(toGoal: goal.id, fromAccount: acc.id, amount: amount)
                            if let frequency = repeatFrequency {
                                store.addRecurringTransfer(kind: .goal,
                                                           title: "Saving for \(goal.name)",
                                                           fromAccountID: acc.id,
                                                           goalID: goal.id,
                                                           amount: amount,
                                                           frequency: frequency)
                            }
                        }
                        dismiss()
                    }
                    .disabled(!canContribute)
                }
            }
            .onAppear {
                if accountID == nil { accountID = store.accounts.first?.id }
            }
        }
        .preferredColorScheme(.light)
    }
}