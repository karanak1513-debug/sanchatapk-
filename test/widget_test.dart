import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:sanchay/providers/sanchay_provider.dart';
import 'package:sanchay/providers/vault_provider.dart';
import 'package:sanchay/screens/auth_screen.dart';
import 'package:sanchay/theme/app_theme.dart';

void main() {
  testWidgets('Sanchay Auth Screen displays brand wordmark and secure Google authentication', (WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SanchayProvider()),
          ChangeNotifierProvider(create: (_) => VaultProvider()),
        ],
        child: MaterialApp(
          theme: AppTheme.lightTheme,
          home: const AuthScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify brand wordmark and Google authentication button
    expect(find.text('SANCHAT'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Unlock Vault'), findsOneWidget);
  });
}
