//
//  ArtHub3App.swift
//  ArtHub3
//
//  Created by User on 2025-06-10.
//

import SwiftUI
import FirebaseCore
import Stripe

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        StripeAPI.defaultPublishableKey = "pk_test_51QeVY6LgoAKhLV6i5KxwluTp0aElL2hQ4KpXDzZSY5fXa2efrUrX0WNT98o3cMFkhf9az1r8lwVCWOGS4KkUJkE800ba24Pq43"
        print("Stripe publishable key set")
        return true
    }
}

@main
struct ArtHub3App: App {
    // register app delegate for Firebase setup
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            NavigationView {
                ContentView()
            }
        }
    }
}
