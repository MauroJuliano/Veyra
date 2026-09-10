import Foundation
import OSLog

enum UserFacingErrorContext: String {
    case authentication
    case registration
    case conversations
    case people
    case startConversation
    case deleteConversation
    case messages
    case sendMessage
    case deleteMessage
    case reaction
    case calls
    case audioRecording
    case profile
    case imageLoading
    case imageSaving
}

enum UserFacingError {
    private static let logger = Logger(subsystem: "com.maurojuliano.veyra", category: "UserFacingError")

    static func message(for error: any Error, context: UserFacingErrorContext) -> String {
        #if DEBUG
        logger.error("Operation failed [\(context.rawValue, privacy: .public)]: \(String(reflecting: error), privacy: .public)")
        #endif

        if let knownMessage = knownMessage(for: error) {
            return knownMessage
        }

        let description = error.localizedDescription.lowercased()
        if isConnectivityError(error, description: description) {
            return localized("Check your internet connection and try again.")
        }

        if context == .authentication {
            if description.contains("invalid login credentials") || description.contains("invalid credentials") {
                return localized("The email or password is incorrect.")
            }
            if description.contains("email not confirmed") {
                return localized("Confirm your email before signing in.")
            }
            if description.contains("rate limit") || description.contains("too many") {
                return localized("Too many attempts. Wait a moment and try again.")
            }
        }

        if context == .registration {
            if description.contains("already registered")
                || description.contains("email already")
                || description.contains("user already exists") {
                return localized("This email is already in use.")
            }
            if description.contains("username already") || description.contains("profiles_username_key") {
                return localized("This username is already in use.")
            }
            if description.contains("rate limit") || description.contains("too many") {
                return localized("Too many attempts. Wait a moment and try again.")
            }
        }

        return localized(defaultKey(for: context))
    }

    private static func knownMessage(for error: any Error) -> String? {
        if let authenticationError = error as? AuthenticationServiceError {
            switch authenticationError {
            case .missingConfiguration:
                return localized("Online access is not configured on this device.")
            case .usernameAlreadyInUse:
                return localized("This username is already in use.")
            }
        }

        if let chatError = error as? ChatRepositoryError {
            switch chatError {
            case .conversationNotFound:
                return localized("The conversation could not be loaded.")
            case .messagingBlocked:
                return localized("Messages are unavailable while either user is blocked.")
            }
        }

        if error is CallRepositoryError {
            return localized("This user cannot receive calls right now.")
        }

        if let audioError = error as? VoiceCallAudioError {
            switch audioError {
            case .microphonePermissionDenied:
                return localized("Microphone access is required for voice calls.")
            default:
                return localized("Unable to connect audio for this call.")
            }
        }

        return nil
    }

    private static func isConnectivityError(_ error: any Error, description: String) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain { return true }
        return [
            "network connection",
            "network is offline",
            "not connected to the internet",
            "connection lost",
            "could not connect to the server",
            "timed out",
            "dns"
        ].contains { description.contains($0) }
    }

    private static func defaultKey(for context: UserFacingErrorContext) -> String.LocalizationValue {
        switch context {
        case .authentication: "We couldn't complete this sign-in request. Please try again."
        case .registration: "We couldn't create your account. Please try again."
        case .conversations: "Unable to refresh conversations. Please try again."
        case .people: "Unable to load people right now. Please try again."
        case .startConversation: "Unable to start this conversation. Please try again."
        case .deleteConversation: "Unable to remove this conversation. Please try again."
        case .messages: "Unable to load messages. Please try again."
        case .sendMessage: "Your message could not be sent. Tap it to try again."
        case .deleteMessage: "Unable to remove this message. Please try again."
        case .reaction: "Unable to update this reaction. Please try again."
        case .calls: "Unable to complete this call action. Please try again."
        case .audioRecording: "Unable to record audio right now. Please try again."
        case .profile: "Unable to update your profile. Please try again."
        case .imageLoading: "The selected image could not be loaded."
        case .imageSaving: "The image could not be saved. Please try again."
        }
    }

    private static func localized(_ key: String.LocalizationValue) -> String {
        AppLocalization.string(key, table: "Errors")
    }
}
