import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'models/user_model.dart';
import 'screens/login_screen.dart';
import 'screens/kitchen_dashboard_screen.dart';
import 'screens/delivery_screen.dart';
import 'screens/branch_home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  UserModel? _currentUser;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Branch Stock Manager',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: _currentUser == null
          ? LoginScreen(onLoginSuccess: (user) => setState(() => _currentUser = user))
          : _currentUser!.role == UserRole.kitchenStaff
              ? KitchenDashboardScreen(currentUser: _currentUser!)
              : _currentUser!.role == UserRole.delivery
                  ? DeliveryScreen(currentUser: _currentUser!)
                  : BranchHomeScreen(currentUser: _currentUser!),
    );
  }
}