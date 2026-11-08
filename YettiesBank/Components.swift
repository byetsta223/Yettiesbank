//
//  Components.swift
//  YettiesBank
//

import SwiftUI

struct TransactionRow: View {
    let tx: Transaction

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: tx.icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tx.amount < 0 ? Color.ink : Color.mint)
                .frame(width: 40, height: 40)
                .background(
                    Circle().fill(tx.amount < 0 ? Color(hex: "ECEEF2") : Color(hex: "E2F3EC"))
                )
            VStack(alignment: .leading, spacing: 3) {
                Text(tx.merchant)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.ink)
                    .lineLimit(1)
                Text(tx.category)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(Currency.string(tx.amount, showSign: true))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(tx.amount < 0 ? Color.ink : Color.mint)
        }
        .padding(.vertical, 2)
    }
}

struct QuickActionButton: View {
    let icon: String
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.system(size: 17, weight: .semibold))
                Text(title)
                    .font(.caption.weight(.medium))
            }
            .foregroundStyle(Color.ink)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(Color.white, in: RoundedRectangle(cornerRadius: 18))
            .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
        }
    }
}

struct CardVisual: View {
    let account: BankAccount
    var revealed: Bool = false
    var holderName: String = "NEEL MAKHECHA"

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: account.colorHex))
            Circle()
                .fill(.white.opacity(0.07))
                .frame(width: 230, height: 230)
                .offset(x: 120, y: -110)
            Circle()
                .fill(.white.opacity(0.05))
                .frame(width: 170, height: 170)
                .offset(x: -130, y: 110)

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(account.name)
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(account.kind)
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                    Spacer()
                    if account.contactless {
                        Image(systemName: "wave.3.right")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                Spacer()
                Text(revealed ? account.formattedCardNumber : account.maskedCardNumber)
                    .font(.system(size: 19, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(.bottom, 12)
                HStack {
                    Text(holderName)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                    Spacer()
                    Text(account.expiry)
                        .font(.system(size: 12, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.8))
                    if account.cardNumber.hasPrefix("5") {
                        mastercardMark
                            .padding(.leading, 8)
                    }
                }
            }
            .padding(22)
        }
        .frame(height: 210)
        .blur(radius: account.isFrozen ? 8 : 0)
        .overlay {
            if account.isFrozen {
                VStack(spacing: 6) {
                    Image(systemName: "snowflake")
                        .font(.system(size: 30, weight: .light))
                    Text("Frozen")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(.white)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 24))
        .shadow(color: Color(hex: account.colorHex).opacity(0.35), radius: 14, y: 8)
    }

    /// The Mastercard twin-circle mark, drawn for cards whose number starts with 5.
    private var mastercardMark: some View {
        ZStack {
            Circle()
                .fill(Color(hex: "EB001B"))
                .frame(width: 24, height: 24)
            Circle()
                .fill(Color(hex: "F79E1B"))
                .frame(width: 24, height: 24)
                .offset(x: 12, y: 0)
            Circle()
                .fill(Color(hex: "FF5F00"))
                .frame(width: 18, height: 24)
                .offset(x: 9, y: 0)
        }
    }
}