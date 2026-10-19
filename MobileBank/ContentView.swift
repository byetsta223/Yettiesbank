//
//  ContentView.swift
//  MobileBank
//
//  Created by Neel Makhecha on 9/5/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var store = BankStore.shared
    @AppStorage("signedInName") private var signedInName = ""

    var body: some View {
        if signedInName.isEmpty {
            SignInGate()
        } else {
            TabView {
                HomeView(store: store)
                    .tabItem { Label("Home", systemImage: "house.fill") }
                CardsView(store: store)
                    .tabItem { Label("Cards", systemImage: "creditcard.fill") }
                TransferTabView(store: store)
                    .tabItem { Label("Transfer", systemImage: "arrow.left.arrow.right") }
                ProfileView(store: store)
                    .tabItem { Label("Profile", systemImage: "person.crop.circle.fill") }
            }
            .tint(Color.mint)
            .preferredColorScheme(.light)
        }
    }
}

#Preview {
    ContentView()
}