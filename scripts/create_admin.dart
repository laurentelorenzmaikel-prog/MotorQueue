/// Admin User Creation Script
///
/// This script helps you create an admin user for the Lorenz App.
/// Run this from the command line:
///
/// dart run scripts/create_admin.dart
///
/// Make sure you have configured Firebase and .env file first!

import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:lorenz_app/firebase_options.dart';
import 'package:lorenz_app/services/secure_auth_service.dart';
import 'package:lorenz_app/config/environment.dart';

void main() async {
  print('============================================');
  print('Lorenz App - Admin User Creation Script');
  print('============================================\n');

  // Initialize Firebase
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✓ Firebase initialized successfully\n');
  } catch (e) {
    print('✗ Error initializing Firebase: $e');
    print('Make sure you have configured firebase_options.dart');
    exit(1);
  }

  // Initialize environment
  try {
    await Environment.initialize();
    print('✓ Environment loaded successfully\n');
  } catch (e) {
    print('✗ Error loading environment: $e');
    print('Make sure you have a .env file in the root directory');
    exit(1);
  }

  final authService = SecureAuthService();

  // Collect admin details
  print('Enter admin account details:\n');

  stdout.write('Email address: ');
  final email = stdin.readLineSync() ?? '';
  if (email.isEmpty || !email.contains('@')) {
    print('✗ Invalid email address');
    exit(1);
  }

  stdout.write('Display name: ');
  final displayName = stdin.readLineSync() ?? '';
  if (displayName.isEmpty) {
    print('✗ Display name cannot be empty');
    exit(1);
  }

  stdout.write('Password (min 8 chars, must include uppercase, lowercase, number, special char): ');
  stdin.echoMode = false;
  final password = stdin.readLineSync() ?? '';
  stdin.echoMode = true;
  print(''); // New line after password input

  if (password.length < 8) {
    print('✗ Password must be at least 8 characters long');
    exit(1);
  }

  stdout.write('Confirm password: ');
  stdin.echoMode = false;
  final confirmPassword = stdin.readLineSync() ?? '';
  stdin.echoMode = true;
  print('\n');

  if (password != confirmPassword) {
    print('✗ Passwords do not match');
    exit(1);
  }

  // Create admin account
  print('Creating admin account...\n');

  try {
    final userProfile = await authService.signUpWithEmail(
      email: email,
      password: password,
      displayName: displayName,
      role: UserRole.admin,
    );

    print('============================================');
    print('✓ Admin account created successfully!');
    print('============================================\n');
    print('Account Details:');
    print('  UID: ${userProfile.uid}');
    print('  Email: ${userProfile.email}');
    print('  Display Name: ${userProfile.displayName}');
    print('  Role: ${userProfile.role.toString().split('.').last}');
    print('  Active: ${userProfile.isActive}');
    print('\nPermissions:');
    userProfile.permissions.forEach((key, value) {
      if (value == true) {
        print('  ✓ $key');
      }
    });
    print('\n⚠️  A verification email has been sent to $email');
    print('Please verify the email to complete the setup.\n');
    print('You can now log in to the admin dashboard!\n');

    exit(0);
  } catch (e) {
    print('============================================');
    print('✗ Error creating admin account');
    print('============================================\n');
    print('Error: $e\n');

    if (e.toString().contains('email-already-in-use')) {
      print('This email is already registered. Try using a different email.');
    } else if (e.toString().contains('weak-password')) {
      print('Password is too weak. Use a stronger password.');
    } else if (e.toString().contains('network')) {
      print('Network error. Check your internet connection.');
    }

    exit(1);
  }
}
