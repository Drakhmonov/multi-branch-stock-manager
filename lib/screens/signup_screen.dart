import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/auth_service.dart';
import '../models/user_model.dart';
import '../models/branch_model.dart';
import '../services/firestore_service.dart';
import '../widgets/responsive_body.dart';
import '../widgets/stream_error_view.dart';

/// Public sign-up. Deliberately does not offer [UserRole.manager] here —
/// manager accounts are still created manually, matching what
/// firestore.rules enforces server-side for self-created user docs.
const _signUpRoles = [
  UserRole.branchStaff,
  UserRole.kitchenStaff,
  UserRole.delivery,
];

class SignUpScreen extends StatefulWidget {
  final void Function(UserModel user) onSignUpSuccess;
  final VoidCallback onBackToLogin;

  const SignUpScreen({
    super.key,
    required this.onSignUpSuccess,
    required this.onBackToLogin,
  });

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _authService = AuthService();
  final _firestoreService = FirestoreService();
  late final Stream<List<BranchModel>> _branchesStream = _firestoreService
      .streamBranches();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _role = UserRole.branchStaff;
  String? _selectedBranchId;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> _handleSignUp() async {
    if (_role == UserRole.branchStaff && _selectedBranchId == null) {
      setState(() => _errorMessage = 'Select a branch.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = await _authService.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
        role: _role,
        branchId: _role == UserRole.branchStaff ? _selectedBranchId : null,
      );
      widget.onSignUpSuccess(user);
    } on FirebaseAuthException catch (e) {
      final message = e.code == 'email-already-in-use'
          ? 'An account with this email already exists. Go back and sign in instead.'
          : 'Sign up failed: ${e.message ?? e.code}';
      setState(() => _errorMessage = message);
    } catch (e) {
      setState(() => _errorMessage = 'Sign up failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Account'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBackToLogin,
        ),
      ),
      body: ResponsiveBody(
        maxWidth: 440,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: AutofillGroup(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'Name'),
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.name],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autofillHints: const [AutofillHints.email],
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  textInputAction: TextInputAction.done,
                  autofillHints: const [AutofillHints.newPassword],
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: _signUpRoles
                      .map(
                        (r) => DropdownMenuItem(value: r, child: Text(r.name)),
                      )
                      .toList(),
                  onChanged: (role) => setState(() {
                    _role = role!;
                    _selectedBranchId = null;
                  }),
                ),
                if (_role == UserRole.branchStaff) ...[
                  const SizedBox(height: 12),
                  StreamBuilder<List<BranchModel>>(
                    stream: _branchesStream,
                    builder: (context, snapshot) {
                      if (snapshot.hasError) {
                        return StreamErrorView(error: snapshot.error);
                      }
                      final branches = (snapshot.data ?? <BranchModel>[])
                          .where((b) => b.active)
                          .toList();
                      return DropdownButtonFormField<String>(
                        initialValue: _selectedBranchId,
                        decoration: const InputDecoration(labelText: 'Branch'),
                        items: branches
                            .map(
                              (b) => DropdownMenuItem(
                                value: b.id,
                                child: Text(b.name),
                              ),
                            )
                            .toList(),
                        onChanged: (branchId) =>
                            setState(() => _selectedBranchId = branchId),
                      );
                    },
                  ),
                ],
                const SizedBox(height: 20),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                const SizedBox(height: 12),
                _isLoading
                    ? const CircularProgressIndicator()
                    : ElevatedButton(
                        onPressed: _handleSignUp,
                        child: const Text('Create Account'),
                      ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
