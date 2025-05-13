//
//  ArtHubProjectApp.swift
//  ArtHubProject
//
//  Created by User on 2025-05-08.
//

import SwiftUI
import FirebaseCore
import FirebaseAnalytics

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        do {
          
            FirebaseApp.configure()
            print("Firebase configured successfully")
            
        
            Analytics.setAnalyticsCollectionEnabled(true)
            
            return true
        } catch {
            print("Error configuring Firebase: \(error.localizedDescription)")
            return false
        }
    }
}

@main
struct ArtHubProjectApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
