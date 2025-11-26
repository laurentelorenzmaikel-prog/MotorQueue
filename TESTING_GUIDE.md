# Testing Guide for Lorenz Motorcycle Service App

## Overview

This guide covers how to run and write tests for the Lorenz Motorcycle Service application.

## Test Structure

```
test/
├── services/
│   ├── booking_service_test.dart       # ✅ Booking logic tests
│   └── secure_auth_service_test.dart   # ⚠️ Requires mockito setup
└── widget_test.dart                     # Default Flutter widget test
```

## Setup

### 1. Install Test Dependencies

```bash
flutter pub get
```

This will install:
- `mockito` - For mocking Firebase services
- `fake_cloud_firestore` - For testing Firestore without real database
- `firebase_auth_mocks` - For testing Firebase Auth

### 2. Generate Mocks (if using mockito)

```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

This generates mock files needed for auth service tests.

## Running Tests

### Run All Tests

```bash
flutter test
```

### Run Specific Test File

```bash
flutter test test/services/booking_service_test.dart
```

### Run Tests with Coverage

```bash
flutter test --coverage
```

View coverage report:
```bash
# Install lcov if not installed
# On macOS: brew install lcov
# On Ubuntu: sudo apt-get install lcov

# Generate HTML report
genhtml coverage/lcov.info -o coverage/html

# Open in browser
open coverage/html/index.html  # macOS
xdg-open coverage/html/index.html  # Linux
start coverage/html/index.html  # Windows
```

### Run Tests in Watch Mode (auto-rerun on changes)

```bash
flutter test --watch
```

##Test Coverage Status

### ✅ Implemented Tests

#### Booking Service Tests ([booking_service_test.dart](test/services/booking_service_test.dart))
- ✅ Time slot availability checking
- ✅ Double-booking prevention
- ✅ Cancelled appointments handling
- ✅ Past date validation
- ✅ Future date limits (3 months)
- ✅ Working hours validation (8 AM - 6 PM)
- ✅ Weekend booking rejection
- ✅ Valid booking creation
- ✅ Booking count retrieval
- ✅ Full slot rejection

#### Auth Service Tests ([secure_auth_service_test.dart](test/services/secure_auth_service_test.dart))
- ✅ User sign up with valid credentials
- ✅ Password strength validation
- ✅ Email format validation
- ✅ User sign in
- ✅ Deactivated account rejection
- ✅ Sign out functionality
- ✅ Session validation
- ✅ Expired session detection

### ⚠️ Tests Requiring Setup

The `secure_auth_service_test.dart` file requires generating mocks:

```bash
# Generate mocks for Firebase services
flutter pub run build_runner build --delete-conflicting-outputs
```

This creates `secure_auth_service_test.mocks.dart` with mock implementations.

### ❌ Missing Tests (To Be Implemented)

1. **Widget Tests**
   - Login page UI tests
   - Sign up page UI tests
   - Booking page UI tests
   - Email verification page UI tests
   - Profile page UI tests

2. **Integration Tests**
   - End-to-end booking flow
   - End-to-end authentication flow
   - Admin dashboard flows

3. **Service Tests**
   - Firestore service tests
   - Admin service tests
   - Cache service tests
   - Monitoring service tests

## Writing Tests

### Example: Simple Unit Test

```dart
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('description of what is being tested', () {
    // Arrange - Set up test data
    final input = 'test';

    // Act - Perform the action
    final result = input.toUpperCase();

    // Assert - Verify the result
    expect(result, 'TEST');
  });
}
```

### Example: Testing with Fake Firestore

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  test('should create document in Firestore', () async {
    // Arrange
    final fakeFirestore = FakeFirebaseFirestore();

    // Act
    await fakeFirestore.collection('test').add({
      'name': 'Test Document',
      'value': 123,
    });

    // Assert
    final docs = await fakeFirestore.collection('test').get();
    expect(docs.docs.length, 1);
    expect(docs.docs.first.data()['name'], 'Test Document');
  });
}
```

### Example: Widget Test

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('button displays correct text', (WidgetTester tester) async {
    // Arrange
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ElevatedButton(
            onPressed: () {},
            child: const Text('Click Me'),
          ),
        ),
      ),
    );

    // Assert
    expect(find.text('Click Me'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
```

## Test Best Practices

### 1. Arrange-Act-Assert Pattern

Always structure tests with clear sections:

```dart
test('description', () {
  // Arrange - Set up test data and mocks
  final input = setupTestData();

  // Act - Execute the code being tested
  final result = functionUnderTest(input);

  // Assert - Verify expected behavior
  expect(result, expectedValue);
});
```

### 2. Test One Thing at a Time

Each test should verify one specific behavior:

```dart
// ❌ Bad - Testing multiple things
test('user operations', () {
  expect(user.canLogin(), true);
  expect(user.canBookAppointment(), true);
  expect(user.canAccessAdmin(), false);
});

// ✅ Good - Separate tests
test('user can login', () {
  expect(user.canLogin(), true);
});

test('user can book appointment', () {
  expect(user.canBookAppointment(), true);
});

test('user cannot access admin', () {
  expect(user.canAccessAdmin(), false);
});
```

### 3. Use Descriptive Test Names

```dart
// ❌ Bad
test('test1', () { ... });

// ✅ Good
test('should reject booking when time slot is fully booked', () { ... });
```

### 4. Clean Up Resources

```dart
group('MyService Tests', () {
  late MyService service;
  late FakeFirebaseFirestore firestore;

  setUp(() {
    // Initialize before each test
    firestore = FakeFirebaseFirestore();
    service = MyService(firestore: firestore);
  });

  tearDown(() {
    // Clean up after each test
    firestore.clearPersistence();
  });

  test('...', () { ... });
});
```

### 5. Test Edge Cases

Don't just test the happy path:

```dart
group('validateEmail', () {
  test('accepts valid email', () {
    expect(validateEmail('test@example.com'), isNull);
  });

  test('rejects empty email', () {
    expect(validateEmail(''), isNotNull);
  });

  test('rejects email without @', () {
    expect(validateEmail('testexample.com'), isNotNull);
  });

  test('rejects email without domain', () {
    expect(validateEmail('test@'), isNotNull);
  });

  test('rejects email with spaces', () {
    expect(validateEmail('test @example.com'), isNotNull);
  });
});
```

## Continuous Integration

### GitHub Actions Example

Create `.github/workflows/test.yml`:

```yaml
name: Flutter Tests

on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest

    steps:
      - uses: actions/checkout@v3

      - uses: subosito/flutter-action@v2
        with:
          flutter-version: '3.5.4'

      - name: Install dependencies
        run: flutter pub get

      - name: Run tests
        run: flutter test --coverage

      - name: Upload coverage to Codecov
        uses: codecov/codecov-action@v3
        with:
          file: coverage/lcov.info
```

## Testing Firebase Features

### Firestore Rules Testing

Test Firestore security rules separately:

```bash
npm install -g firebase-tools
firebase emulators:start --only firestore
firebase emulators:exec --only firestore "flutter test"
```

### Testing with Firebase Emulators

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Initialize emulators:
   ```bash
   firebase init emulators
   ```

3. Run tests with emulators:
   ```bash
   firebase emulators:exec "flutter test"
   ```

## Test Coverage Goals

Target coverage percentages:

- **Critical paths (auth, booking)**: 90%+ coverage
- **Services**: 80%+ coverage
- **UI widgets**: 60%+ coverage
- **Overall**: 70%+ coverage

## Troubleshooting

### Issue: Tests fail with "Platform is not initialized"

**Solution**: Wrap test setup with `TestWidgetsFlutterBinding.ensureInitialized()`:

```dart
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('...', () { ... });
}
```

### Issue: "MissingPluginException" in tests

**Solution**: Use fake/mock implementations instead of real Firebase:

```dart
// ❌ Bad - Uses real Firebase
final firestore = FirebaseFirestore.instance;

// ✅ Good - Uses fake for testing
final firestore = FakeFirebaseFirestore();
```

### Issue: Mock generation fails

**Solution**: Ensure annotations are correct:

```dart
@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
])
import 'my_test.mocks.dart';
```

Then run:
```bash
flutter pub run build_runner build --delete-conflicting-outputs
```

### Issue: Async tests timeout

**Solution**: Increase timeout or use `pumpAndSettle`:

```dart
testWidgets('...', (tester) async {
  await tester.pumpWidget(MyApp());
  await tester.pumpAndSettle(); // Wait for all animations
  // ...
}, timeout: const Timeout(Duration(minutes: 2)));
```

## Resources

- [Flutter Testing Documentation](https://docs.flutter.dev/testing)
- [Mockito Documentation](https://pub.dev/packages/mockito)
- [Fake Cloud Firestore](https://pub.dev/packages/fake_cloud_firestore)
- [Firebase Auth Mocks](https://pub.dev/packages/firebase_auth_mocks)
- [Testing Best Practices](https://flutter.dev/docs/testing/best-practices)

## Running Tests Before Commits

Add a pre-commit hook to run tests automatically:

Create `.git/hooks/pre-commit`:

```bash
#!/bin/sh
echo "Running tests..."
flutter test

if [ $? -ne 0 ]; then
  echo "Tests failed. Commit aborted."
  exit 1
fi

echo "Tests passed!"
exit 0
```

Make it executable:
```bash
chmod +x .git/hooks/pre-commit
```

## Quick Commands Reference

```bash
# Run all tests
flutter test

# Run specific file
flutter test test/services/booking_service_test.dart

# Run with coverage
flutter test --coverage

# Run in watch mode
flutter test --watch

# Generate mocks
flutter pub run build_runner build --delete-conflicting-outputs

# View coverage report
genhtml coverage/lcov.info -o coverage/html && open coverage/html/index.html
```

---

**Next Steps:**
1. ✅ Run `flutter pub get` to install dependencies
2. ✅ Run `flutter test` to verify tests pass
3. ⚠️ Generate mocks: `flutter pub run build_runner build`
4. ✅ Add widget tests for critical UI components
5. ✅ Set up CI/CD pipeline with automated testing
6. ✅ Achieve 70%+ code coverage
