import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'theme/app_theme.dart';
import 'models/user_model.dart';
import 'screens/login_screen.dart';
import 'screens/signup_screen.dart';
import 'screens/kitchen_dashboard_screen.dart';
import 'screens/delivery_screen.dart';
import 'screens/branch_home_screen.dart';
import 'screens/manager_dashboard_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  UserModel? _currentUser;
  bool _showSignUp = false;

  // Survives the screen swap below it (home: changes when _currentUser is
  // set), so a SnackBar queued the moment sign-up succeeds still shows on
  // top of whichever screen the user lands on.
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  void _handleSignUpSuccess(UserModel user) {
    setState(() {
      _currentUser = user;
      _showSignUp = false;
    });
    _scaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text('Account created — welcome, ${user.name}!')),
    );
  }

  void _handleSignOut() {
    setState(() {
      _currentUser = null;
      _showSignUp = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      scaffoldMessengerKey: _scaffoldMessengerKey,
      title: 'Multi-Branch Stock Manager',
      debugShowCheckedModeBanner: false,
      theme: buildAppTheme(),
      home: _currentUser == null
          ? (_showSignUp
                ? SignUpScreen(
                    onSignUpSuccess: _handleSignUpSuccess,
                    onBackToLogin: () => setState(() => _showSignUp = false),
                  )
                : LoginScreen(
                    onLoginSuccess: (user) =>
                        setState(() => _currentUser = user),
                    onCreateAccount: () => setState(() => _showSignUp = true),
                  ))
          : _currentUser!.role == UserRole.kitchenStaff
          ? KitchenDashboardScreen(
              currentUser: _currentUser!,
              onSignOut: _handleSignOut,
            )
          : _currentUser!.role == UserRole.delivery
          ? DeliveryScreen(
              currentUser: _currentUser!,
              onSignOut: _handleSignOut,
            )
          : _currentUser!.role == UserRole.manager
          ? ManagerDashboardScreen(
              currentUser: _currentUser!,
              onSignOut: _handleSignOut,
            )
          : BranchHomeScreen(
              currentUser: _currentUser!,
              onSignOut: _handleSignOut,
            ),
    );
  }
}
