//
//  ArtHub3App.swift
//  ArtHub3
//
//  Created by User on 2025-06-10.
//

import SwiftUI
import FirebaseCore
import Stripe
import UserNotifications
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate, MessagingDelegate {
    func application(_ application: UIApplication,
                    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        FirebaseApp.configure()
        StripeAPI.defaultPublishableKey = "pk_test_51QeVY6LgoAKhLV6i5KxwluTp0aElL2hQ4KpXDzZSY5fXa2efrUrX0WNT98o3cMFkhf9az1r8lwVCWOGS4KkUJkE800ba24Pq43"
        print("Stripe publishable key set")
        
        // Request notification permissions
        UNUserNotificationCenter.current().delegate = self
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]
        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                print("Error requesting notification authorization: \(error)")
            } else {
                print("Notification permission granted: \(granted)")
            }
        }
        application.registerForRemoteNotifications()
        
        // Set Messaging delegate
        Messaging.messaging().delegate = self
        return true
    }

    // MARK: - UNUserNotificationCenterDelegate
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .badge])
    }

    // MARK: - MessagingDelegate
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        print("FCM registration token: \(fcmToken ?? "nil")")
        // TODO: Send token to server if needed
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Messaging.messaging().apnsToken = deviceToken
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
