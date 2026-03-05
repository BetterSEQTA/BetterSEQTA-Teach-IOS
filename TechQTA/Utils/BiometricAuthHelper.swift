//
//  BiometricAuthHelper.swift
//  TechQTA
//
//  Created by Aden Lindsay on 3/5/2026.
//

import LocalAuthentication

enum BiometricAuthHelper {
    /// Returns whether Face ID or Touch ID is available on this device.
    static var isAvailable: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    /// Returns the biometric type available: "Face ID", "Touch ID", or nil if unavailable.
    static var biometricType: LABiometryType? {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return nil
        }
        return context.biometryType
    }

    /// Human-readable name for the available biometric type.
    static var biometricTypeName: String {
        switch biometricType {
        case .faceID: return "Face ID"
        case .touchID: return "Touch ID"
        default: return "Biometrics"
        }
    }

    /// Authenticates the user with Face ID or Touch ID.
    /// - Parameter reason: Shown to the user during authentication.
    /// - Returns: true if authentication succeeded, false otherwise.
    static func authenticate(reason: String = "Unlock the app") async -> Bool {
        let context = LAContext()
        var error: NSError?
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        do {
            return try await context.evaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, localizedReason: reason)
        } catch {
            return false
        }
    }
}
