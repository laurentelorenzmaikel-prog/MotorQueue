import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:lorenz_app/services/booking_service.dart';

void main() {
  group('BookingService Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late BookingService bookingService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      bookingService = BookingService(firestore: fakeFirestore);
    });

    group('Time Slot Availability', () {
      test('should return 0 for empty time slot', () async {
        // Arrange
        final date = DateTime.now().add(const Duration(days: 1));
        const timeSlot = '10:00 AM';

        // Act
        final count = await bookingService.getSlotBookingCount(
          date: date,
          timeSlot: timeSlot,
        );

        // Assert
        expect(count, 0);
      });

      test('should return correct count when slot has bookings', () async {
        // Arrange
        final date = DateTime.now().add(const Duration(days: 1));
        const timeSlot = '10:00 AM';
        final dateString = _formatDateOnly(date);

        // Create 2 bookings at the same time slot (max capacity)
        for (int i = 0; i < 2; i++) {
          await fakeFirestore.collection('appointments').add({
            'service': 'Test Service',
            'date': dateString,
            'timeSlot': timeSlot,
            'dateTime': date,
            'status': 'pending',
            'userId': 'user-$i',
          });
        }

        // Act
        final count = await bookingService.getSlotBookingCount(
          date: date,
          timeSlot: timeSlot,
        );

        // Assert
        expect(count, 2);
      });

      test('should not count cancelled appointments', () async {
        // Arrange
        final date = DateTime.now().add(const Duration(days: 1));
        const timeSlot = '10:00 AM';
        final dateString = _formatDateOnly(date);

        // Create 3 cancelled bookings
        for (int i = 0; i < 3; i++) {
          await fakeFirestore.collection('appointments').add({
            'service': 'Test Service',
            'date': dateString,
            'timeSlot': timeSlot,
            'dateTime': date,
            'status': 'cancelled', // Cancelled status
            'userId': 'user-$i',
          });
        }

        // Act
        final count = await bookingService.getSlotBookingCount(
          date: date,
          timeSlot: timeSlot,
        );

        // Assert
        expect(count, 0, reason: 'Cancelled appointments should not count');
      });

      test('should count confirmed appointments', () async {
        // Arrange
        final date = DateTime.now().add(const Duration(days: 1));
        const timeSlot = '2:00 PM';
        final dateString = _formatDateOnly(date);

        // Create 1 pending and 1 confirmed booking
        await fakeFirestore.collection('appointments').add({
          'service': 'Test Service',
          'date': dateString,
          'timeSlot': timeSlot,
          'status': 'pending',
          'userId': 'user-1',
        });
        await fakeFirestore.collection('appointments').add({
          'service': 'Test Service',
          'date': dateString,
          'timeSlot': timeSlot,
          'status': 'confirmed',
          'userId': 'user-2',
        });

        // Act
        final count = await bookingService.getSlotBookingCount(
          date: date,
          timeSlot: timeSlot,
        );

        // Assert
        expect(count, 2);
      });
    });

    group('Booking Validation', () {
      test('should reject past date bookings', () async {
        // Arrange
        final pastDate = DateTime.now().subtract(const Duration(days: 1));
        const timeSlot = '10:00 AM';

        // Act
        final result = await bookingService.validateBooking(
          userId: 'test-user',
          date: pastDate,
          timeSlot: timeSlot,
        );

        // Assert
        expect(result.isValid, false);
        expect(result.errorMessage, contains('past'));
      });

      test('should reject bookings more than 3 months ahead', () async {
        // Arrange
        final farFutureDate = DateTime.now().add(const Duration(days: 100));
        const timeSlot = '10:00 AM';

        // Act
        final result = await bookingService.validateBooking(
          userId: 'test-user',
          date: farFutureDate,
          timeSlot: timeSlot,
        );

        // Assert
        expect(result.isValid, false);
        expect(result.errorMessage, contains('3 months'));
      });

      test('should reject weekend bookings', () async {
        // Arrange - Find next Saturday
        var nextSaturday = DateTime.now().add(const Duration(days: 1));
        while (nextSaturday.weekday != DateTime.saturday) {
          nextSaturday = nextSaturday.add(const Duration(days: 1));
        }
        const timeSlot = '10:00 AM';

        // Act
        final result = await bookingService.validateBooking(
          userId: 'test-user',
          date: nextSaturday,
          timeSlot: timeSlot,
        );

        // Assert
        expect(result.isValid, false);
        expect(result.errorMessage, contains('weekdays'));
      });

      test('should reject duplicate booking by same user', () async {
        // Arrange - Find next weekday
        var nextWeekday = DateTime.now().add(const Duration(days: 1));
        while (nextWeekday.weekday == DateTime.saturday ||
            nextWeekday.weekday == DateTime.sunday) {
          nextWeekday = nextWeekday.add(const Duration(days: 1));
        }
        const timeSlot = '10:00 AM';
        final dateString = _formatDateOnly(nextWeekday);

        // Create existing booking for the same user
        await fakeFirestore.collection('appointments').add({
          'service': 'Test Service',
          'date': dateString,
          'timeSlot': timeSlot,
          'status': 'pending',
          'userId': 'test-user',
        });

        // Act
        final result = await bookingService.validateBooking(
          userId: 'test-user',
          date: nextWeekday,
          timeSlot: timeSlot,
        );

        // Assert
        expect(result.isValid, false);
        expect(result.errorMessage, contains('already booked'));
      });

      test('should reject booking when slot is full', () async {
        // Arrange - Find next weekday
        var nextWeekday = DateTime.now().add(const Duration(days: 1));
        while (nextWeekday.weekday == DateTime.saturday ||
            nextWeekday.weekday == DateTime.sunday) {
          nextWeekday = nextWeekday.add(const Duration(days: 1));
        }
        const timeSlot = '10:00 AM';
        final dateString = _formatDateOnly(nextWeekday);

        // Fill up the slot (2 bookings = max capacity)
        for (int i = 0; i < 2; i++) {
          await fakeFirestore.collection('appointments').add({
            'service': 'Test Service',
            'date': dateString,
            'timeSlot': timeSlot,
            'status': 'pending',
            'userId': 'other-user-$i',
          });
        }

        // Act
        final result = await bookingService.validateBooking(
          userId: 'new-user',
          date: nextWeekday,
          timeSlot: timeSlot,
        );

        // Assert
        expect(result.isValid, false);
        expect(result.errorMessage, contains('full'));
      });

      test('should accept valid weekday booking with available slot', () async {
        // Arrange - Find next weekday
        var nextWeekday = DateTime.now().add(const Duration(days: 1));
        while (nextWeekday.weekday == DateTime.saturday ||
            nextWeekday.weekday == DateTime.sunday) {
          nextWeekday = nextWeekday.add(const Duration(days: 1));
        }
        const timeSlot = '10:00 AM';

        // Act
        final result = await bookingService.validateBooking(
          userId: 'test-user',
          date: nextWeekday,
          timeSlot: timeSlot,
        );

        // Assert
        expect(result.isValid, true, reason: 'Valid booking should pass validation');
        expect(result.errorMessage, isNull);
      });
    });

    group('Create Booking', () {
      test('should create booking with valid data', () async {
        // Arrange - Find next weekday
        var validDate = DateTime.now().add(const Duration(days: 1));
        while (validDate.weekday == DateTime.saturday ||
            validDate.weekday == DateTime.sunday) {
          validDate = validDate.add(const Duration(days: 1));
        }
        const timeSlot = '10:00 AM';

        // Act
        final reference = await bookingService.createBooking(
          userId: 'test-user-id',
          service: 'Oil Change',
          date: validDate,
          timeSlot: timeSlot,
          motorBrand: 'Honda CBR',
          plateNumber: 'ABC-123',
        );

        // Assert
        expect(reference, isNotEmpty);
        expect(reference, startsWith('MQ-'));

        // Verify booking was created in Firestore
        final bookings = await fakeFirestore.collection('appointments').get();
        expect(bookings.docs.length, 1);

        final booking = bookings.docs.first.data();
        expect(booking['service'], 'Oil Change');
        expect(booking['motorBrand'], 'Honda CBR');
        expect(booking['plateNumber'], 'ABC-123');
        expect(booking['status'], 'pending');
        expect(booking['userId'], 'test-user-id');
        expect(booking['timeSlot'], timeSlot);
        expect(booking['date'], _formatDateOnly(validDate));
      });

      test('should throw error when time slot is full', () async {
        // Arrange - Find next weekday
        var validDate = DateTime.now().add(const Duration(days: 1));
        while (validDate.weekday == DateTime.saturday ||
            validDate.weekday == DateTime.sunday) {
          validDate = validDate.add(const Duration(days: 1));
        }
        const timeSlot = '10:00 AM';
        final dateString = _formatDateOnly(validDate);

        // Fill up the time slot (2 bookings = max capacity)
        for (int i = 0; i < 2; i++) {
          await fakeFirestore.collection('appointments').add({
            'service': 'Test Service',
            'date': dateString,
            'timeSlot': timeSlot,
            'status': 'pending',
            'userId': 'user-$i',
          });
        }

        // Act & Assert
        expect(
          () => bookingService.createBooking(
            userId: 'new-user',
            service: 'Oil Change',
            date: validDate,
            timeSlot: timeSlot,
            motorBrand: 'Honda CBR',
          ),
          throwsException,
        );
      });

      test('should throw error for duplicate booking by same user', () async {
        // Arrange - Find next weekday
        var validDate = DateTime.now().add(const Duration(days: 1));
        while (validDate.weekday == DateTime.saturday ||
            validDate.weekday == DateTime.sunday) {
          validDate = validDate.add(const Duration(days: 1));
        }
        const timeSlot = '2:00 PM';
        final dateString = _formatDateOnly(validDate);

        // Create existing booking for the same user
        await fakeFirestore.collection('appointments').add({
          'service': 'Test Service',
          'date': dateString,
          'timeSlot': timeSlot,
          'status': 'pending',
          'userId': 'test-user',
        });

        // Act & Assert
        expect(
          () => bookingService.createBooking(
            userId: 'test-user',
            service: 'Tire Change',
            date: validDate,
            timeSlot: timeSlot,
            motorBrand: 'Yamaha',
          ),
          throwsException,
        );
      });
    });

    group('Get Available Time Slots', () {
      test('should return all slots when none are booked', () async {
        // Arrange - Find next weekday
        var date = DateTime.now().add(const Duration(days: 1));
        while (date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday) {
          date = date.add(const Duration(days: 1));
        }

        // Act
        final availableSlots = await bookingService.getAvailableTimeSlots(
          date: date,
        );

        // Assert
        expect(availableSlots, containsAll(['8:00 AM', '10:00 AM', '12:00 PM', '2:00 PM', '4:00 PM']));
        expect(availableSlots.length, 5);
      });

      test('should exclude full slots', () async {
        // Arrange - Find next weekday
        var date = DateTime.now().add(const Duration(days: 1));
        while (date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday) {
          date = date.add(const Duration(days: 1));
        }
        final dateString = _formatDateOnly(date);

        // Fill up the 10:00 AM slot
        for (int i = 0; i < 2; i++) {
          await fakeFirestore.collection('appointments').add({
            'service': 'Test Service',
            'date': dateString,
            'timeSlot': '10:00 AM',
            'status': 'pending',
            'userId': 'user-$i',
          });
        }

        // Act
        final availableSlots = await bookingService.getAvailableTimeSlots(
          date: date,
        );

        // Assert
        expect(availableSlots, isNot(contains('10:00 AM')));
        expect(availableSlots.length, 4);
      });

      test('should exclude slots already booked by user', () async {
        // Arrange - Find next weekday
        var date = DateTime.now().add(const Duration(days: 1));
        while (date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday) {
          date = date.add(const Duration(days: 1));
        }
        final dateString = _formatDateOnly(date);

        // User has booked 2:00 PM slot
        await fakeFirestore.collection('appointments').add({
          'service': 'Test Service',
          'date': dateString,
          'timeSlot': '2:00 PM',
          'status': 'pending',
          'userId': 'test-user',
        });

        // Act
        final availableSlots = await bookingService.getAvailableTimeSlots(
          date: date,
          userId: 'test-user',
        );

        // Assert
        expect(availableSlots, isNot(contains('2:00 PM')));
        expect(availableSlots.length, 4);
      });
    });

    group('Slot Availability Info', () {
      test('should return remaining spots for all slots', () async {
        // Arrange - Find next weekday
        var date = DateTime.now().add(const Duration(days: 1));
        while (date.weekday == DateTime.saturday ||
            date.weekday == DateTime.sunday) {
          date = date.add(const Duration(days: 1));
        }
        final dateString = _formatDateOnly(date);

        // Add 1 booking to 8:00 AM slot
        await fakeFirestore.collection('appointments').add({
          'service': 'Test Service',
          'date': dateString,
          'timeSlot': '8:00 AM',
          'status': 'pending',
          'userId': 'user-1',
        });

        // Add 2 bookings to 10:00 AM slot (full)
        for (int i = 0; i < 2; i++) {
          await fakeFirestore.collection('appointments').add({
            'service': 'Test Service',
            'date': dateString,
            'timeSlot': '10:00 AM',
            'status': 'pending',
            'userId': 'user-$i',
          });
        }

        // Act
        final availability = await bookingService.getSlotAvailabilityInfo(
          date: date,
        );

        // Assert
        expect(availability['8:00 AM'], 1); // 1 spot remaining
        expect(availability['10:00 AM'], 0); // Full
        expect(availability['12:00 PM'], 2); // Empty
        expect(availability['2:00 PM'], 2); // Empty
        expect(availability['4:00 PM'], 2); // Empty
      });
    });

    group('User Duplicate Booking Check', () {
      test('should return true if user has booked the slot', () async {
        // Arrange
        final date = DateTime.now().add(const Duration(days: 1));
        const timeSlot = '10:00 AM';
        final dateString = _formatDateOnly(date);

        await fakeFirestore.collection('appointments').add({
          'service': 'Test Service',
          'date': dateString,
          'timeSlot': timeSlot,
          'status': 'pending',
          'userId': 'test-user',
        });

        // Act
        final hasBooked = await bookingService.hasUserAlreadyBooked(
          userId: 'test-user',
          date: date,
          timeSlot: timeSlot,
        );

        // Assert
        expect(hasBooked, true);
      });

      test('should return false if user has not booked the slot', () async {
        // Arrange
        final date = DateTime.now().add(const Duration(days: 1));
        const timeSlot = '10:00 AM';

        // Act
        final hasBooked = await bookingService.hasUserAlreadyBooked(
          userId: 'test-user',
          date: date,
          timeSlot: timeSlot,
        );

        // Assert
        expect(hasBooked, false);
      });

      test('should not count cancelled bookings as duplicates', () async {
        // Arrange
        final date = DateTime.now().add(const Duration(days: 1));
        const timeSlot = '10:00 AM';
        final dateString = _formatDateOnly(date);

        await fakeFirestore.collection('appointments').add({
          'service': 'Test Service',
          'date': dateString,
          'timeSlot': timeSlot,
          'status': 'cancelled', // Cancelled booking
          'userId': 'test-user',
        });

        // Act
        final hasBooked = await bookingService.hasUserAlreadyBooked(
          userId: 'test-user',
          date: date,
          timeSlot: timeSlot,
        );

        // Assert
        expect(hasBooked, false, reason: 'Cancelled bookings should not count as duplicates');
      });
    });
  });
}

/// Helper function to format date as YYYY-MM-DD string
String _formatDateOnly(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
