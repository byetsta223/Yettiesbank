//
//  ContentView.swift
//  YettiesBank
//
//  Created by Neel Makhecha on 9/5/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = BankStore.shared
    @StateObject private var lock = AppLock.shared
    @AppStorage("signedInName") private var signedInName = ""
    @Environment(\.scenePhase) private var scenePhase
    @State private var checkedLaunchLock = false

    var body: some View {
        if lock.isLocked {
            LockScreenView()
        } else if signedInName.isEmpty {
            SignInGate()
        } else {
            TabView {
                HomeView(store: store)
                    .tabItem { Label("Home", systemImage: "house.fill") }
                CardsView(store: store)
                    .tabItem { Label("Cards", systemImage: "creditcard.fill") }
                TransferTabView(store: store)
                    .tabItem { Label("Transfer", systemImage: "arrow.left.arrow.right") }
                InsightsView(store: store)
                    .tabItem { Label("Insights", systemImage: "chart.bar.fill") }
                ProfileView(store: store)
                    .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
            }
            .tint(Color.mint)
            .preferredColorScheme(.light)
            .onChange(of: scenePhase) { phase in
                switch phase {
                case .background:
                    lock.appDidEnterBackground()
                case .active:
                    store.processDueBills()
                    store.processDueRecurringTransfers()
                    lock.appWillEnterForeground()
                default:
                    break
                }
            }
            .onAppear {
                if !checkedLaunchLock {
                    checkedLaunchLock = true
                    lock.lockAtLaunchIfNeeded()
                }
            }
        }
    }
}