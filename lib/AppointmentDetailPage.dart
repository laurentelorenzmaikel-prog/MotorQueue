import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:lorenz_app/models/appointment.dart';

class AppointmentDetailPage extends StatelessWidget {
  final Appointment appointment;
  final int index;

  const AppointmentDetailPage({
    super.key,
    required this.appointment,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Appointment Details")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Service: ${appointment.service}",
                style: TextStyle(fontSize: 18)),
            Text("Date: ${appointment.dateTime}",
                style: TextStyle(fontSize: 16)),
            Text("Motor Details: ${appointment.motorDetails}",
                style: TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // TODO: Add rescheduling logic
              },
              child: const Text("Reschedule Appointment"),
            ),
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () async {
                final box = Hive.box<Appointment>('appointments');
                await box.deleteAt(index);
                Navigator.pop(context);
              },
              style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
              child: const Text("Cancel Appointment"),
            )
          ],
        ),
      ),
    );
  }
}
