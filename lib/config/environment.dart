import 'package:flutter_dotenv/flutter_dotenv.dart';

/// Environment configuration for the application.
/// Loads values from .env file or uses defaults.
class Environment {
  /// Prevent instantiation
  Environment._();

  /// Initialize environment variables
  /// Call this in main() before runApp()
  static Future<void> initialize() async {
    try {
      await dotenv.load(fileName: '.env');
    } catch (e) {
      // .env file not found, will use default values
      print('Warning: .env file not found. Using default values.');
    }
  }

  /// Current environment (development, staging, production)
  static String get environment {
    return dotenv.get('ENVIRONMENT', fallback: 'development');
  }

  /// Check if running in development mode
  static bool get isDevelopment {
    return environment == 'development';
  }

  /// Check if running in production mode
  static bool get isProduction {
    return environment == 'production';
  }

  /// OpenRouter API key for AI chatbot (legacy)
  static String get openRouterApiKey {
    return dotenv.get('OPENROUTER_API_KEY', fallback: '');
  }

  /// OpenAI API key for GPT chatbot
  static String get openAIApiKey {
    return dotenv.get('OPENAI_API_KEY', fallback: '');
  }

  /// reCAPTCHA v3 Site Key for Firebase App Check (Web)
  static String get recaptchaV3SiteKey {
    return dotenv.get('RECAPTCHA_V3_SITE_KEY', fallback: '');
  }

  /// Backend API URL
  static String get apiUrl {
    return dotenv.get('API_URL', fallback: 'https://api.lorenz.com');
  }

  /// Feature flags
  static bool get enableAiChatbot {
    return dotenv.get('ENABLE_AI_CHATBOT', fallback: 'true').toLowerCase() == 'true';
  }

  static bool get enableAnalytics {
    return dotenv.get('ENABLE_ANALYTICS', fallback: 'true').toLowerCase() == 'true';
  }

  static bool get enableCrashlytics {
    return dotenv.get('ENABLE_CRASHLYTICS', fallback: 'true').toLowerCase() == 'true';
  }

  /// Debug settings
  static bool get debugMode {
    return dotenv.get('DEBUG_MODE', fallback: 'false').toLowerCase() == 'true';
  }

  static bool get verboseLogging {
    return dotenv.get('VERBOSE_LOGGING', fallback: 'false').toLowerCase() == 'true';
  }

  /// App configuration
  static String get appName {
    return dotenv.get('APP_NAME', fallback: 'Lorenz Motorcycle Service');
  }

  static String get appVersion {
    return dotenv.get('APP_VERSION', fallback: '1.0.0');
  }

  /// Validate that all required environment variables are set
  static bool validateConfig() {
    final errors = <String>[];

    // Check required fields
    if (isProduction) {
      if (openRouterApiKey.isEmpty) {
        errors.add('OPENROUTER_API_KEY is required in production');
      }
    }

    if (errors.isNotEmpty) {
      print('Environment configuration errors:');
      for (final error in errors) {
        print('  - $error');
      }
      return false;
    }

    return true;
  }

  /// Print current configuration (for debugging)
  static void printConfig() {
    if (!debugMode) return;

    print('=== Environment Configuration ===');
    print('Environment: $environment');
    print('API URL: $apiUrl');
    print('AI Chatbot: ${enableAiChatbot ? 'Enabled' : 'Disabled'}');
    print('Analytics: ${enableAnalytics ? 'Enabled' : 'Disabled'}');
    print('Crashlytics: ${enableCrashlytics ? 'Enabled' : 'Disabled'}');
    print('Debug Mode: ${debugMode ? 'ON' : 'OFF'}');
    print('Verbose Logging: ${verboseLogging ? 'ON' : 'OFF'}');
    print('App Name: $appName');
    print('App Version: $appVersion');
    print('================================');
  }
}
