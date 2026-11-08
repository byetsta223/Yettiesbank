//
//  NotificationsView.swift
//  YettiesBank
//

import SwiftUI

struct NotificationsView: View {
    @ObservedObject var store: BankStore

    private var sorted: [AppNotification] {
        store.notifications.sorted { $0.date > $1.date }
    }

    var body: some View {
        Group {
            if store.notifications.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "bell.slash")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.subtleText)
                    Text("No notifications yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(sorted) { notification in
                            NotificationRow(notification: notification) {
                                if !notification.isRead {
                                    withAnimation(.snappy) {
                                        store.markNotificationRead(notification.id)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                }
            }
        }
        .background(Color.paper.ignoresSafeArea())
        .navigationTitle("Notifications")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if store.unreadNotificationCount > 0 {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Mark all read") {
                        withAnimation(.snappy) { store.markAllNotificationsRead() }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.mint)
                }
            }
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: notification.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: notification.colorHex))
                    .frame(width: 40, height: 40)
                    .background(Circle().fill(Color(hex: notification.colorHex).opacity(0.12)))
                VStack(alignment: .leading, spacing: 3) {
                    Text(notification.title)
                        .font(.subheadline.weight(notification.isRead ? .regular : .semibold))
                        .foregroundStyle(Color.ink)
                    Text(notification.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(notification.date.relativeLabel())
                        .font(.caption2)
                        .foregroundStyle(Color.subtleText)
                }
                Spacer()
                if !notification.isRead {
                    Circle()
                        .fill(Color.mint)
                        .frame(width: 8, height: 8)
                        .padding(.top, 6)
                }
            }
            .padding(14)
            .background(notification.isRead ? Color.white : Color(hex: "EEF8F3"),
                        in: RoundedRectangle(cornerRadius: 18))
        }
        .buttonStyle(.plain)
    }
}