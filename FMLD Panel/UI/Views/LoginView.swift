//
//  LoginView.swift
//  FMLD Panel
//
//  Created by Vladyslav Aleinikov on 8/9/25.
//

import SwiftUI
import LocalAuthentication

struct LoginView: View {
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var email = ""
    @State private var password = ""
    @State private var rememberMe = false
    @State private var showBiometric = false
    @State private var biometricType: LABiometryType = .none
    
    var body: some View {
        VStack(spacing: 30) {
            // Logo and Title
            VStack(spacing: 16) {
                Image(systemName: "shield.checkered")
                    .font(.system(size: 60))
                    .foregroundColor(.blue)
                
                Text("FMLD Panel")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Fraud, Money Laundering & Detection")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 50)
            
            // Login Form
            VStack(spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Email")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    TextField("Enter your email", text: $email)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disableAutocorrection(true)
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    Text("Password")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    SecureField("Enter your password", text: $password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                
                HStack {
                    Toggle("Remember me", isOn: $rememberMe)
                        .toggleStyle(SwitchToggleStyle())
                    
                    Spacer()
                    
                    Button("Forgot Password?") {
                        // Handle forgot password
                    }
                    .foregroundColor(.blue)
                }
                
                // Login Button
                Button(action: login) {
                    HStack {
                        if authManager.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "arrow.right.circle.fill")
                        }
                        
                        Text("Sign In")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(authManager.isLoading || email.isEmpty || password.isEmpty)
                
                // Biometric Login
                if showBiometric {
                    Button(action: biometricLogin) {
                        HStack {
                            Image(systemName: biometricIcon)
                            Text("Sign in with \(biometricType.localizedString)")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.green)
                        .foregroundColor(.white)
                        .cornerRadius(10)
                    }
                }
            }
            .padding(.horizontal, 40)
            
            // Demo Accounts
            VStack(spacing: 12) {
                Text("Demo Accounts")
                    .font(.headline)
                    .foregroundColor(.secondary)
                
                VStack(spacing: 8) {
                    DemoAccountButton(role: "Admin", email: "admin@fmld.com", password: "admin123")
                    DemoAccountButton(role: "Analyst", email: "analyst@fmld.com", password: "analyst123")
                    DemoAccountButton(role: "Viewer", email: "viewer@fmld.com", password: "viewer123")
                }
            }
            .padding(.horizontal, 40)
            
            Spacer()
            
            // Error Message
            if let error = authManager.error {
                Text(error.localizedDescription)
                    .foregroundColor(.red)
                    .padding()
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
                    .padding(.horizontal, 40)
            }
        }
        .onAppear {
            checkBiometricAvailability()
        }
    }
    
    private var biometricIcon: String {
        switch biometricType {
        case .faceID:
            return "faceid"
        case .touchID:
            return "touchid"
        default:
            return "person.crop.circle"
        }
    }
    
    private func login() {
        Task {
            await authManager.login(email: email, password: password, rememberMe: rememberMe)
        }
    }
    
    private func biometricLogin() {
        Task {
            let success = await authManager.authenticateWithBiometrics()
            if success {
                // Load saved user from keychain
                authManager.checkAuthenticationStatus()
            }
        }
    }
    
    private func checkBiometricAvailability() {
        let context = LAContext()
        var error: NSError?
        
        if context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) {
            biometricType = context.biometryType
            showBiometric = true
        }
    }
}

struct DemoAccountButton: View {
    let role: String
    let email: String
    let password: String
    
    @StateObject private var authManager = AuthenticationManager.shared
    @State private var emailText: String = ""
    @State private var passwordText: String = ""
    
    var body: some View {
        Button(action: {
            emailText = email
            passwordText = password
            Task {
                await authManager.login(email: email, password: password)
            }
        }) {
            HStack {
                VStack(alignment: .leading) {
                    Text(role)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(email)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Image(systemName: "arrow.right.circle")
                    .foregroundColor(.blue)
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

extension LABiometryType {
    var localizedString: String {
        switch self {
        case .faceID:
            return "Face ID"
        case .touchID:
            return "Touch ID"
        default:
            return "Biometric"
        }
    }
}

#Preview {
    LoginView()
}
