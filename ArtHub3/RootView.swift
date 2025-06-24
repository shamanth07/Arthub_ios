import SwiftUI

enum AppScreen {
    case splash
    case login
    case register
    case visitorHome
    case artistHome
    case adminHome
}

struct RootView: View {
    @State private var currentScreen: AppScreen = .splash

    var body: some View {
        switch currentScreen {
        case .splash:
            SplashView(onFinish: { currentScreen = .login })
        case .login:
            LoginView(
                onSignUp: { currentScreen = .register },
                onLoginSuccess: { role in
                    switch role.lowercased() {
                    case "visitor": currentScreen = .visitorHome
                    case "artist": currentScreen = .artistHome
                    case "admin": currentScreen = .adminHome
                    default: currentScreen = .login
                    }
                }
            )
        case .register:
            RegisterView(
                onSignIn: { currentScreen = .login },
                onRegisterSuccess: { currentScreen = .login }
            )
        case .visitorHome:
            VisitorHomeView(onLogout: { currentScreen = .login })
        case .artistHome:
            ArtistHomeView(onLogout: { currentScreen = .login })
        case .adminHome:
            AdminHomeView(onLogout: { currentScreen = .login })
        }
    }
}

#Preview {
    RootView()
}
