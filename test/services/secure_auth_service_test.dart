import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:lorenz_app/services/secure_auth_service.dart';

// Generate mocks with: flutter pub run build_runner build
@GenerateMocks([
  FirebaseAuth,
  FirebaseFirestore,
  GoogleSignIn,
  User,
  UserCredential,
  CollectionReference,
  DocumentReference,
  DocumentSnapshot,
])
import 'secure_auth_service_test.mocks.dart';

void main() {
  group('SecureAuthService Tests', () {
    late MockFirebaseAuth mockAuth;
    late MockFirebaseFirestore mockFirestore;
    late MockGoogleSignIn mockGoogleSignIn;
    late SecureAuthService authService;

    setUp(() {
      mockAuth = MockFirebaseAuth();
      mockFirestore = MockFirebaseFirestore();
      mockGoogleSignIn = MockGoogleSignIn();

      authService = SecureAuthService(
        auth: mockAuth,
        firestore: mockFirestore,
        googleSignIn: mockGoogleSignIn,
      );
    });

    group('Email Sign Up', () {
      test('should create user account with valid credentials', () async {
        // Arrange
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();

        when(mockAuth.createUserWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => mockUserCredential);

        when(mockUserCredential.user).thenReturn(mockUser);
        when(mockUser.uid).thenReturn('test-uid');
        when(mockUser.email).thenReturn('test@example.com');
        when(mockUser.displayName).thenReturn('Test User');
        when(mockUser.updateDisplayName(any)).thenAnswer((_) async => {});
        when(mockUser.sendEmailVerification()).thenAnswer((_) async => {});

        // Mock Firestore
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDoc = MockDocumentReference<Map<String, dynamic>>();

        when(mockFirestore.collection('users')).thenReturn(mockCollection);
        when(mockCollection.doc(any)).thenReturn(mockDoc);
        when(mockDoc.set(any)).thenAnswer((_) async => {});
        when(mockCollection.add(any)).thenAnswer((_) async => mockDoc);

        // Act
        final userProfile = await authService.signUpWithEmail(
          email: 'test@example.com',
          password: 'Test@123456',
          displayName: 'Test User',
        );

        // Assert
        expect(userProfile.email, 'test@example.com');
        expect(userProfile.displayName, 'Test User');
        expect(userProfile.role, UserRole.user);
        expect(userProfile.isActive, true);

        verify(mockAuth.createUserWithEmailAndPassword(
          email: 'test@example.com',
          password: 'Test@123456',
        )).called(1);

        verify(mockUser.sendEmailVerification()).called(1);
      });

      test('should reject weak password', () async {
        // Act & Assert
        expect(
          () => authService.signUpWithEmail(
            email: 'test@example.com',
            password: 'weak',
            displayName: 'Test User',
          ),
          throwsException,
        );
      });

      test('should reject invalid email', () async {
        // Act & Assert
        expect(
          () => authService.signUpWithEmail(
            email: 'invalid-email',
            password: 'Test@123456',
            displayName: 'Test User',
          ),
          throwsException,
        );
      });

      test('should validate password requirements', () async {
        // Test missing uppercase
        expect(
          () => authService.signUpWithEmail(
            email: 'test@example.com',
            password: 'test@123456',
            displayName: 'Test User',
          ),
          throwsException,
        );

        // Test missing special character
        expect(
          () => authService.signUpWithEmail(
            email: 'test@example.com',
            password: 'Test123456',
            displayName: 'Test User',
          ),
          throwsException,
        );

        // Test too short
        expect(
          () => authService.signUpWithEmail(
            email: 'test@example.com',
            password: 'Te@1',
            displayName: 'Test User',
          ),
          throwsException,
        );
      });
    });

    group('Email Sign In', () {
      test('should sign in user with valid credentials', () async {
        // Arrange
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();
        final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();

        when(mockAuth.signInWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => mockUserCredential);

        when(mockUserCredential.user).thenReturn(mockUser);
        when(mockUser.uid).thenReturn('test-uid');
        when(mockUser.email).thenReturn('test@example.com');

        // Mock Firestore user profile
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDocRef = MockDocumentReference<Map<String, dynamic>>();

        when(mockFirestore.collection('users')).thenReturn(mockCollection);
        when(mockCollection.doc('test-uid')).thenReturn(mockDocRef);
        when(mockDocRef.get()).thenAnswer((_) async => mockDoc);
        when(mockDoc.exists).thenReturn(true);
        when(mockDoc.data()).thenReturn({
          'uid': 'test-uid',
          'email': 'test@example.com',
          'role': 'user',
          'displayName': 'Test User',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'lastLoginAt': Timestamp.now(),
          'permissions': {'book_appointments': true},
        });
        when(mockDocRef.update(any)).thenAnswer((_) async => {});
        when(mockCollection.add(any)).thenAnswer((_) async => mockDocRef);

        // Act
        final userProfile = await authService.signInWithEmail(
          email: 'test@example.com',
          password: 'Test@123456',
        );

        // Assert
        expect(userProfile.email, 'test@example.com');
        expect(userProfile.isActive, true);

        verify(mockAuth.signInWithEmailAndPassword(
          email: 'test@example.com',
          password: 'Test@123456',
        )).called(1);
      });

      test('should reject sign in for deactivated account', () async {
        // Arrange
        final mockUserCredential = MockUserCredential();
        final mockUser = MockUser();
        final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();

        when(mockAuth.signInWithEmailAndPassword(
          email: anyNamed('email'),
          password: anyNamed('password'),
        )).thenAnswer((_) async => mockUserCredential);

        when(mockUserCredential.user).thenReturn(mockUser);
        when(mockUser.uid).thenReturn('test-uid');

        // Mock Firestore with inactive user
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDocRef = MockDocumentReference<Map<String, dynamic>>();

        when(mockFirestore.collection('users')).thenReturn(mockCollection);
        when(mockCollection.doc('test-uid')).thenReturn(mockDocRef);
        when(mockDocRef.get()).thenAnswer((_) async => mockDoc);
        when(mockDoc.exists).thenReturn(true);
        when(mockDoc.data()).thenReturn({
          'uid': 'test-uid',
          'email': 'test@example.com',
          'role': 'user',
          'displayName': 'Test User',
          'isActive': false, // Deactivated account
          'createdAt': Timestamp.now(),
          'lastLoginAt': Timestamp.now(),
          'permissions': {},
        });

        when(mockAuth.signOut()).thenAnswer((_) async => {});

        // Act & Assert
        expect(
          () => authService.signInWithEmail(
            email: 'test@example.com',
            password: 'Test@123456',
          ),
          throwsException,
        );
      });
    });

    group('Sign Out', () {
      test('should sign out user and clear session', () async {
        // Arrange
        final mockUser = MockUser();
        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn('test-uid');
        when(mockUser.email).thenReturn('test@example.com');
        when(mockAuth.signOut()).thenAnswer((_) async => {});
        when(mockGoogleSignIn.signOut()).thenAnswer((_) async => null);

        // Mock Firestore for logging
        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        when(mockFirestore.collection('security_logs')).thenReturn(mockCollection);
        when(mockCollection.add(any)).thenAnswer((_) async => MockDocumentReference<Map<String, dynamic>>());

        // Act
        await authService.signOut();

        // Assert
        verify(mockAuth.signOut()).called(1);
        verify(mockGoogleSignIn.signOut()).called(1);
      });
    });

    group('Session Validation', () {
      test('should validate active session within timeout', () async {
        // Arrange
        final mockUser = MockUser();
        final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();

        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn('test-uid');

        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDocRef = MockDocumentReference<Map<String, dynamic>>();

        when(mockFirestore.collection('users')).thenReturn(mockCollection);
        when(mockCollection.doc('test-uid')).thenReturn(mockDocRef);
        when(mockDocRef.get()).thenAnswer((_) async => mockDoc);
        when(mockDoc.exists).thenReturn(true);
        when(mockDoc.data()).thenReturn({
          'uid': 'test-uid',
          'email': 'test@example.com',
          'role': 'user',
          'displayName': 'Test User',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'lastLoginAt': Timestamp.now(), // Recent login
          'permissions': {},
        });

        // Act
        final isValid = await authService.isSessionValid();

        // Assert
        expect(isValid, true);
      });

      test('should invalidate expired session', () async {
        // Arrange
        final mockUser = MockUser();
        final mockDoc = MockDocumentSnapshot<Map<String, dynamic>>();

        when(mockAuth.currentUser).thenReturn(mockUser);
        when(mockUser.uid).thenReturn('test-uid');

        final mockCollection = MockCollectionReference<Map<String, dynamic>>();
        final mockDocRef = MockDocumentReference<Map<String, dynamic>>();

        when(mockFirestore.collection('users')).thenReturn(mockCollection);
        when(mockCollection.doc('test-uid')).thenReturn(mockDocRef);
        when(mockDocRef.get()).thenAnswer((_) async => mockDoc);
        when(mockDoc.exists).thenReturn(true);

        // Last login was 10 hours ago (exceeds 8 hour timeout)
        final expiredLogin = DateTime.now().subtract(const Duration(hours: 10));

        when(mockDoc.data()).thenReturn({
          'uid': 'test-uid',
          'email': 'test@example.com',
          'role': 'user',
          'displayName': 'Test User',
          'isActive': true,
          'createdAt': Timestamp.now(),
          'lastLoginAt': Timestamp.fromDate(expiredLogin),
          'permissions': {},
        });

        // Act
        final isValid = await authService.isSessionValid();

        // Assert
        expect(isValid, false);
      });
    });
  });
}
