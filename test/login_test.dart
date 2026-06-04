import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:attendexa/screens/login_screen.dart';
import 'package:attendexa/services/database_service.dart';
import 'package:attendexa/services/nfc_service.dart';
import 'package:attendexa/services/excel_service.dart';

void main() {
  testWidgets('Automated Login Validation Check', (WidgetTester tester) async {
    // 1. Build the LoginScreen widget within the required Provider scope
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider(create: (_) => DatabaseService()),
          Provider(create: (_) => NfcService()),
          Provider(create: (_) => ExcelService()),
        ],
        child: const MaterialApp(
          home: LoginScreen(),
        ),
      ),
    );

    // Give it a moment to render
    await tester.pumpAndSettle();

    // 2. Locate the TextFields
    final textFields = find.byType(TextField);
    expect(textFields, findsNWidgets(2), reason: 'Should have exactly two text fields (ID and Password)');

    final idField = textFields.at(0);
    final passField = textFields.at(1);
    final loginButton = find.text('SIGN IN');

    expect(loginButton, findsOneWidget, reason: 'Login button should be visible');

    // 3. Automated check: Enter wrong credentials
    await tester.enterText(idField, 'wronguser');
    await tester.enterText(passField, 'wrongpass');
    await tester.pump();
    
    // Tap the login button
    await tester.tap(loginButton);
    await tester.pump(); // Trigger setState

    // Wait for the simulated network delay (600ms)
    await tester.pump(const Duration(milliseconds: 700));

    // Verify error message appeared
    expect(find.text('Invalid ID or Password'), findsOneWidget, reason: 'Error should display on wrong credentials');

    // 4. Automated check: Enter correct credentials
    await tester.enterText(idField, 'teacher');
    await tester.enterText(passField, '1234');
    await tester.pump();

    // Tap login button
    await tester.tap(loginButton);
    await tester.pump();

    // Wait for the simulated delay (600ms) plus transition (600ms)
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pump(); // Use pump instead of pumpAndSettle due to repeating animations in Dashboard

    // Verify the error message is gone, meaning validation passed and it routing occurred
    expect(find.text('Invalid ID or Password'), findsNothing, reason: 'Error should have disappeared on valid creds');
    
    // Since we transition to DashboardScreen, we expect "Mark Attendance" text to be found in the widget tree eventually
    expect(find.text('Mark\nAttendance'), findsOneWidget, reason: 'Should have successfully navigated to DashboardScreen');
  });
}
