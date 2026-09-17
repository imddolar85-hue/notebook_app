import 'package:flutter/foundation.dart';

import 'dart:convert';

import 'package:http/http.dart' as http;

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:country_picker/country_picker.dart';

import 'live_screen.dart';

import 'firebase_options.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.white,
      statusBarIconBrightness: Brightness.dark,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
    ),
  );

  runApp(const NoteBookApp());
}

class NoteBookApp extends StatelessWidget {
  const NoteBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'NoteBook',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1877F2)),
        scaffoldBackgroundColor: const Color(0xFFF0F2F5),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black87,
          surfaceTintColor: Colors.transparent,
          elevation: 0,
          systemOverlayStyle: SystemUiOverlayStyle(
            statusBarColor: Colors.white,
            statusBarIconBrightness: Brightness.dark,
          ),
        ),
      ),
      home: const AppStartupScreen(),
    );
  }
}

// ============================================================
// APP STARTUP / SPLASH SCREEN

class AppStartupScreen extends StatefulWidget {
  const AppStartupScreen({super.key});

  @override
  State<AppStartupScreen> createState() => _AppStartupScreenState();
}

class _AppStartupScreenState extends State<AppStartupScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _animationController;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _fadeAnimation;

  bool _initializationFinished = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.94, end: 1.04).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _fadeAnimation = Tween<double>(begin: 0.65, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _initializeApp();
  }

  Future<void> _initializeApp() async {
    try {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );

      if (!mounted) return;

      setState(() {
        _initializationFinished = true;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _errorMessage =
            'Could not start NoteBook.\n\n'
            'Error: $e';
      });
    }
  }

  void _tryAgain() {
    setState(() {
      _errorMessage = null;
    });

    _initializeApp();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_initializationFinished) {
      return const AuthGate();
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // ==================================================
                // ANIMATED NOTEBOOK LOGO
                // ==================================================

                AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Opacity(
                      opacity: _fadeAnimation.value,
                      child: Transform.scale(
                        scale: _scaleAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      color: const Color(0xFFE8F0FE),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF1877F2)
                              .withValues(alpha: 0.16),
                          blurRadius: 24,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/notebook_logo.png',
                      width: 90,
                      height: 90,
                      fit: BoxFit.contain,
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // ==================================================
                // APP NAME
                // ==================================================
                const Text(
                  'NoteBook',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1877F2),
                    letterSpacing: -0.5,
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Learn What You Love. Teach What You Know.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 14, color: Colors.grey),
                ),

                const SizedBox(height: 32),

                // ==================================================
                // LOADING / ERROR
                // ==================================================
                if (_errorMessage == null) ...[
                  const SizedBox(
                    width: 30,
                    height: 30,
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      color: Color(0xFF1877F2),
                    ),
                  ),

                  const SizedBox(height: 16),

                  const Text(
                    'Starting NoteBook...',
                    style: TextStyle(fontSize: 14, color: Colors.grey),
                  ),
                ] else ...[
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 14,
                      color: Colors.redAccent,
                    ),
                  ),

                  const SizedBox(height: 16),

                  FilledButton(
                    onPressed: _tryAgain,
                    child: const Text('Try Again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// AUTH GATE

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFFF0F2F5),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF1877F2)),
            ),
          );
        }

        if (snapshot.hasData) {
          return const HomeScreen();
        }

        return const LoginScreen();
      },
    );
  }
}

// ============================================================
// LOGIN SCREEN
// ============================================================

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;
  bool obscurePassword = true;

  Future<void> login() async {
    final email = emailController.text.trim();
    final password = passwordController.text;

    if (email.isEmpty) {
      showMessage('Please enter your email.');
      return;
    }

    if (password.isEmpty) {
      showMessage('Please enter your password.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      showMessage('Error code: ${e.code}\n${e.message ?? 'Login failed.'}');

      showMessage('Something went wrong.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> forgotPassword() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage('Please enter your email first.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
          'http://127.0.0.1:5001/smart-notebook-5f2b9/us-central1/requestPasswordOtp',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email}),
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => EmailOTPVerificationScreen(email: email),
          ),
        );
      } else {
        try {
          final data = jsonDecode(response.body);
          showMessage(data['message'] ?? 'Could not send verification code.');
        } catch (_) {
          showMessage('Could not send verification code.');
        }
      }
    } catch (e) {
      if (mounted) {
        showMessage('Error: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> googleLogin() async {
    if (loading) return;

    setState(() {
      loading = true;
    });

    try {
      if (kIsWeb) {
        final provider = GoogleAuthProvider();

        await FirebaseAuth.instance.signInWithPopup(provider);

        final user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'uid': user.uid,
                'name': user.displayName ?? '',
                'email': user.email,
                'photoURL': user.photoURL,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }
      } else {
        final GoogleSignInAccount googleUser = await GoogleSignIn.instance
            .authenticate();

        final GoogleSignInAuthentication googleAuth = googleUser.authentication;

        final idToken = googleAuth.idToken;

        if (idToken == null) {
          throw Exception('Google ID token is missing.');
        }

        final credential = GoogleAuthProvider.credential(idToken: idToken);

        await FirebaseAuth.instance.signInWithCredential(credential);

        final user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .set({
                'uid': user.uid,
                'name': user.displayName ?? '',
                'email': user.email,
                'photoURL': user.photoURL,
                'updatedAt': FieldValue.serverTimestamp(),
              }, SetOptions(merge: true));
        }
      }
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Google login failed.');
    } on GoogleSignInException catch (e) {
      showMessage('Google Sign-In failed: ${e.description ?? e.code.name}');
    } catch (e) {
      showMessage('Google login failed: $e');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Image.asset(
                  'assets/images/notebook_logo.png',
                  width: 75,
                  height: 75,
                  fit: BoxFit.contain,
                ),

                const SizedBox(height: 12),

                const Text(
                  'NoteBook',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1877F2),
                  ),
                ),

                const SizedBox(height: 8),

                const Text(
                  'Education. Connect. Learn.',
                  style: TextStyle(color: Colors.grey, fontSize: 15),
                ),

                const SizedBox(height: 35),

                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 15),

                TextField(
                  controller: passwordController,
                  obscureText: obscurePassword,
                  decoration: InputDecoration(
                    labelText: 'Password',
                    prefixIcon: const Icon(Icons.lock_outline),
                    suffixIcon: IconButton(
                      onPressed: () {
                        setState(() {
                          obscurePassword = !obscurePassword;
                        });
                      },
                      icon: Icon(
                        obscurePassword
                            ? Icons.visibility
                            : Icons.visibility_off,
                      ),
                    ),
                    border: const OutlineInputBorder(),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),

                const SizedBox(height: 20),

                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: loading ? null : forgotPassword,
                    child: const Text(
                      'Forgot Password?',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),

                const SizedBox(height: 5),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: FilledButton(
                    onPressed: loading ? null : login,
                    child: loading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text('Login', style: TextStyle(fontSize: 17)),
                  ),
                ),

                const SizedBox(height: 15),

                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: OutlinedButton.icon(
                    onPressed: loading ? null : googleLogin,
                    icon: const Icon(Icons.g_mobiledata, size: 30),
                    label: const Text(
                      'Continue with Google',
                      style: TextStyle(fontSize: 16),
                    ),
                  ),
                ),

                const SizedBox(height: 15),

                const SizedBox(height: 10),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text("Don't have an account?"),
                    TextButton(
                      onPressed: loading
                          ? null
                          : () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const RegisterScreen(),
                                ),
                              );
                            },
                      child: const Text('Create Account'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// REGISTER SCREEN
// ============================================================

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  String selectedRole = 'Student';

  bool loading = false;
  bool obscurePassword = true;
  bool obscureConfirmPassword = true;

  Future<void> createAccount() async {
    final firstName = firstNameController.text.trim();
    final lastName = lastNameController.text.trim();
    final email = emailController.text.trim();
    final password = passwordController.text;
    final confirmPassword = confirmPasswordController.text;

    if (firstName.isEmpty) {
      showMessage('Please enter your first name.');
      return;
    }

    if (lastName.isEmpty) {
      showMessage('Please enter your last name.');
      return;
    }

    if (email.isEmpty) {
      showMessage('Please enter your email.');
      return;
    }

    if (password.length < 6) {
      showMessage('Password must contain at least 6 characters.');
      return;
    }

    if (confirmPassword.isEmpty) {
      showMessage('Please confirm your password.');
      return;
    }

    if (password != confirmPassword) {
      showMessage('Password and Confirm Password do not match.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      final user = userCredential.user;
      final fullName = '$firstName $lastName';

      await user?.updateDisplayName(fullName);

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'firstName': firstName,
          'lastName': lastName,
          'name': fullName,
          'email': user.email,
          'role': selectedRole,
          'photoURL': user.photoURL,
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }

      if (!mounted) return;

      showMessage('Account created successfully as $selectedRole.');

      Navigator.pop(context);
    } on FirebaseAuthException catch (e) {
      String message;

      switch (e.code) {
        case 'email-already-in-use':
          message = 'This email is already registered.';
          break;

        case 'invalid-email':
          message = 'Please enter a valid email address.';
          break;

        case 'weak-password':
          message = 'This password is too weak.';
          break;

        case 'network-request-failed':
          message = 'Network error. Please check your internet connection.';
          break;

        default:
          message = e.message ?? 'Account creation failed.';
      }

      showMessage(message);

      showMessage('Something went wrong. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    firstNameController.dispose();
    lastNameController.dispose();
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Account')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Image.asset(
                  'assets/images/notebook_logo.png',
                  width: 70,
                  height: 70,
                  fit: BoxFit.contain,
                ),
              ),

              const SizedBox(height: 15),

              const Center(
                child: Text(
                  'Create Your NoteBook Account',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: firstNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: lastNameController,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  prefixIcon: Icon(Icons.person_outline),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 25),

              const Text(
                'Select Account Type',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedRole = 'Student';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: selectedRole == 'Student'
                              ? const Color(0xFFE8F0FE)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedRole == 'Student'
                                ? const Color(0xFF1877F2)
                                : Colors.grey.shade400,
                            width: selectedRole == 'Student' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.school,
                              size: 36,
                              color: selectedRole == 'Student'
                                  ? const Color(0xFF1877F2)
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Student',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 12),

                  Expanded(
                    child: GestureDetector(
                      onTap: () {
                        setState(() {
                          selectedRole = 'Teacher';
                        });
                      },
                      child: Container(
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: selectedRole == 'Teacher'
                              ? const Color(0xFFE8F0FE)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: selectedRole == 'Teacher'
                                ? const Color(0xFF1877F2)
                                : Colors.grey.shade400,
                            width: selectedRole == 'Teacher' ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.person_pin,
                              size: 36,
                              color: selectedRole == 'Teacher'
                                  ? const Color(0xFF1877F2)
                                  : Colors.grey,
                            ),
                            const SizedBox(height: 6),
                            const Text(
                              'Teacher',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 25),

              TextField(
                controller: passwordController,
                obscureText: obscurePassword,
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscurePassword = !obscurePassword;
                      });
                    },
                    icon: Icon(
                      obscurePassword ? Icons.visibility : Icons.visibility_off,
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              TextField(
                controller: confirmPasswordController,
                obscureText: obscureConfirmPassword,
                decoration: InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  suffixIcon: IconButton(
                    onPressed: () {
                      setState(() {
                        obscureConfirmPassword = !obscureConfirmPassword;
                      });
                    },
                    icon: Icon(
                      obscureConfirmPassword
                          ? Icons.visibility
                          : Icons.visibility_off,
                    ),
                  ),
                  border: const OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 30),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: loading ? null : createAccount,
                  child: loading
                      ? const SizedBox(
                          width: 25,
                          height: 25,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2.5,
                          ),
                        )
                      : const Text(
                          'Create Account',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================
// PHONE LOGIN
// ============================================================

class PhoneLoginScreen extends StatefulWidget {
  const PhoneLoginScreen({super.key});

  @override
  State<PhoneLoginScreen> createState() => _PhoneLoginScreenState();
}

class _PhoneLoginScreenState extends State<PhoneLoginScreen> {
  final phoneController = TextEditingController();
  Country selectedCountry = Country.parse('SA');

  bool loading = false;

  Future<void> sendCode() async {
    final phoneNumber = phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      showMessage('Please enter your phone number.');
      return;
    }

    final phone = '+${selectedCountry.phoneCode}$phoneNumber';

    setState(() {
      loading = true;
    });

    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: phone,
        verificationCompleted: (credential) async {
          await FirebaseAuth.instance.signInWithCredential(credential);
        },
        verificationFailed: (e) {
          showMessage(e.message ?? 'Phone verification failed.');

          if (mounted) {
            setState(() {
              loading = false;
            });
          }
        },
        codeSent: (verificationId, resendToken) {
          if (!mounted) return;

          setState(() {
            loading = false;
          });

          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  OTPVerificationScreen(verificationId: verificationId),
            ),
          );
        },
        codeAutoRetrievalTimeout: (verificationId) {
          if (mounted) {
            setState(() {
              loading = false;
            });
          }
        },
      );
    } catch (e) {
      showMessage('Could not send OTP: $e');

      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Login')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 30),

            const Icon(Icons.phone_android, size: 70, color: Color(0xFF1877F2)),

            const SizedBox(height: 20),

            const Text(
              'Login with Phone Number',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 25),

            InkWell(
              onTap: () {
                showCountryPicker(
                  context: context,
                  showPhoneCode: true,
                  onSelect: (Country country) {
                    setState(() {
                      selectedCountry = country;
                    });
                  },
                );
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 14,
                ),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Row(
                  children: [
                    Text(
                      '${selectedCountry.flagEmoji}  +${selectedCountry.phoneCode}',
                      style: const TextStyle(fontSize: 16),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_drop_down),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 12),

            TextField(
              controller: phoneController,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Phone Number',
                hintText: '5XXXXXXXX',
                prefixIcon: Icon(Icons.phone),
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: loading ? null : sendCode,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Send OTP', style: TextStyle(fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// OTP SCREEN
// ============================================================

class OTPVerificationScreen extends StatefulWidget {
  final String verificationId;

  const OTPVerificationScreen({super.key, required this.verificationId});

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen> {
  final otpController = TextEditingController();

  bool loading = false;

  Future<void> verifyOTP() async {
    final otp = otpController.text.trim();

    if (otp.length != 6) {
      showMessage('Please enter the 6-digit OTP.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final credential = PhoneAuthProvider.credential(
        verificationId: widget.verificationId,
        smsCode: otp,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      final user = FirebaseAuth.instance.currentUser;

      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'uid': user.uid,
          'phoneNumber': user.phoneNumber,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      showMessage(e.message ?? 'Invalid OTP.');

      showMessage('OTP verification failed.');
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify OTP')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),

            const Icon(Icons.sms_outlined, size: 70, color: Color(0xFF1877F2)),

            const SizedBox(height: 20),

            const Text(
              'Enter the OTP sent to your phone',
              style: TextStyle(fontSize: 17),
            ),

            const SizedBox(height: 20),

            TextField(
              controller: otpController,
              keyboardType: TextInputType.number,
              maxLength: 6,
              decoration: const InputDecoration(
                labelText: '6-digit OTP',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 10),

            SizedBox(
              width: double.infinity,
              height: 52,
              child: FilledButton(
                onPressed: loading ? null : verifyOTP,
                child: loading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Verify OTP', style: TextStyle(fontSize: 17)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
// ============================================================
// HOME / NEWS FEED SCREEN
// ============================================================

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int selectedNavIndex = 0;

  final List<String> stories = [
    'Add Story',
    'Teacher',
    'Science',
    'Mathematics',
    'Computer',
  ];

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
  }

  void showComingSoon(String feature) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('$feature will be added soon.')));
  }

  void openLiveScreen() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LiveScreen()),
    );
  }

  void openProfile() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const ProfileScreen()),
    );
  }

  void openMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.only(left: 12, right: 12, bottom: 20),
            children: [
              ListTile(
                leading: const Icon(
                  Icons.person_outline,
                  color: Color(0xFF1877F2),
                ),
                title: const Text(
                  'Profile',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  openProfile();
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.chat_bubble_outline,
                  color: Color(0xFF1877F2),
                ),
                title: const Text(
                  'Messenger',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  showComingSoon('Messenger');
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.settings_outlined,
                  color: Color(0xFF1877F2),
                ),
                title: const Text(
                  'Settings',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  showComingSoon('Settings');
                },
              ),

              ListTile(
                leading: const Icon(
                  Icons.help_outline,
                  color: Color(0xFF1877F2),
                ),
                title: const Text(
                  'Help & Support',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                onTap: () {
                  Navigator.pop(context);
                  showComingSoon('Help & Support');
                },
              ),

              const Divider(),

              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text(
                  'Logout',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.red,
                  ),
                ),
                onTap: () {
                  Navigator.pop(context);
                  logout();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    final userName =
        user?.displayName ?? user?.email?.split('@').first ?? 'User';

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),

      // ======================================================
      // TOP APP BAR
      // ======================================================
      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,

        automaticallyImplyLeading: false,

        titleSpacing: 8,

        title: Row(
          children: [
            // MENU
            IconButton(
              tooltip: 'Menu',
              onPressed: openMenu,
              icon: const Icon(
                Icons.menu_rounded,
                color: Colors.black87,
                size: 27,
              ),
            ),

            // NOTEBOOK
            const Text(
              'NoteBook',
              style: TextStyle(
                color: Color(0xFF1877F2),
                fontSize: 25,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
          ],
        ),

        actions: [
          // ==================================================
          // CREATE / PLUS
          // ==================================================

          IconButton(
            tooltip: 'Create',
            onPressed: () {
              _showCreateMenu();
            },
            icon: const Icon(
              Icons.add_circle_outline_rounded,
              color: Colors.black87,
              size: 27,
            ),
          ),

          // ==================================================
          // SEARCH
          // ==================================================
          IconButton(
            tooltip: 'Search',
            onPressed: () {
              showComingSoon('Search');
            },
            icon: const Icon(
              Icons.search_rounded,
              color: Colors.black87,
              size: 27,
            ),
          ),

          // ==================================================
          // MESSENGER
          // ==================================================
          IconButton(
            tooltip: 'Messenger',
            onPressed: () {
              showComingSoon('Messenger');
            },
            icon: const Icon(
              Icons.chat_bubble_outline_rounded,
              color: Colors.black87,
              size: 25,
            ),
          ),

          // ==================================================
          // NOTIFICATIONS
          // ==================================================
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: IconButton(
              tooltip: 'Notifications',
              onPressed: () {
                showComingSoon('Notifications');
              },
              icon: const Icon(
                Icons.notifications_none_rounded,
                color: Colors.black87,
                size: 27,
              ),
            ),
          ),
        ],
      ),

      // ======================================================
      // BODY
      // ======================================================
      body: SafeArea(
        child: IndexedStack(
          index: selectedNavIndex,
          children: [
            _buildFeed(user, userName),
            _buildWatchPlaceholder(),
            _buildLibraryPlaceholder(),
            _buildNotificationsPlaceholder(),
            _buildProfilePlaceholder(),
          ],
        ),
      ),

      // ======================================================
      // BOTTOM NAVIGATION
      // ======================================================
      bottomNavigationBar: NavigationBar(
        selectedIndex: selectedNavIndex,
        backgroundColor: Colors.white,
        indicatorColor: const Color(0xFFE8F0FE),
        elevation: 3,

        onDestinationSelected: (index) {
          setState(() {
            selectedNavIndex = index;
          });

          // Profile সরাসরি খুলবে
          if (index == 4) {
            openProfile();
          }
        },

        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home, color: Color(0xFF1877F2)),
            label: 'Feed',
          ),

          NavigationDestination(
            icon: Icon(Icons.play_circle_outline),
            selectedIcon: Icon(Icons.play_circle, color: Color(0xFF1877F2)),
            label: 'Watch',
          ),

          NavigationDestination(
            icon: Icon(Icons.library_books_outlined),
            selectedIcon: Icon(Icons.library_books, color: Color(0xFF1877F2)),
            label: 'Library',
          ),

          NavigationDestination(
            icon: Icon(Icons.notifications_none),
            selectedIcon: Icon(Icons.notifications, color: Color(0xFF1877F2)),
            label: 'Alerts',
          ),

          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person, color: Color(0xFF1877F2)),
            label: 'Profile',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CREATE MENU
  // ============================================================

  void _showCreateMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      showDragHandle: true,
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 25),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Create',
                  style: TextStyle(fontSize: 21, fontWeight: FontWeight.bold),
                ),

                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: _buildCreateMenuItem(
                        icon: Icons.edit_outlined,
                        label: 'Post',
                        color: const Color(0xFF1877F2),
                        onTap: () {
                          Navigator.pop(context);

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => CreatePostScreen(
                                userName:
                                    FirebaseAuth
                                        .instance
                                        .currentUser
                                        ?.displayName ??
                                    FirebaseAuth.instance.currentUser?.email
                                        ?.split('@')
                                        .first ??
                                    'User',
                                photoURL:
                                    FirebaseAuth.instance.currentUser?.photoURL,
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    Expanded(
                      child: _buildCreateMenuItem(
                        icon: Icons.photo_library_outlined,
                        label: 'Photo',
                        color: Colors.green,
                        onTap: () {
                          Navigator.pop(context);
                          showComingSoon('Photo');
                        },
                      ),
                    ),

                    Expanded(
                      child: _buildCreateMenuItem(
                        icon: Icons.videocam_outlined,
                        label: 'Video',
                        color: Colors.red,
                        onTap: () {
                          Navigator.pop(context);
                          showComingSoon('Video');
                        },
                      ),
                    ),

                    Expanded(
                      child: _buildCreateMenuItem(
                        icon: Icons.picture_as_pdf_outlined,
                        label: 'PDF',
                        color: Colors.orange,
                        onTap: () {
                          Navigator.pop(context);
                          showComingSoon('PDF');
                        },
                      ),
                    ),

                    Expanded(
                      child: _buildCreateMenuItem(
                        icon: Icons.live_tv_outlined,
                        label: 'Live',
                        color: Colors.red,
                        onTap: () {
                          Navigator.pop(context);
                          openLiveScreen();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCreateMenuItem({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: color.withValues(alpha: 0.10),
              child: Icon(icon, color: color, size: 27),
            ),

            const SizedBox(height: 6),

            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // NEWS FEED
  // ============================================================

  Widget _buildFeed(User? user, String userName) {
    return RefreshIndicator(
      color: const Color(0xFF1877F2),

      onRefresh: () async {
        await Future.delayed(const Duration(milliseconds: 600));
      },

      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 20),
        children: [
          _buildStoriesSection(),

          const SizedBox(height: 8),

          _buildCreatePostCard(user: user, userName: userName),

          const SizedBox(height: 8),

          _buildPostCard(
            name: 'NoteBook Teacher',
            category: 'Physics',
            time: '2h',
            avatarIcon: Icons.school,
            text:
                'Welcome to NoteBook! 📚\n\n'
                'Learn what you love and teach what you know. '
                'Share your knowledge with the world.',
            likes: '24',
            comments: '6',
          ),

          const SizedBox(height: 8),

          _buildPostCard(
            name: 'Education Center',
            category: 'Mathematics',
            time: '5h',
            avatarIcon: Icons.calculate,
            text:
                'Today’s learning topic:\n\n'
                'Understanding the basics of Mathematics '
                'step by step. 🎓',
            likes: '41',
            comments: '12',
          ),

          const SizedBox(height: 8),

          _buildPostCard(
            name: 'NoteBook Community',
            category: 'Learning',
            time: '1d',
            avatarIcon: Icons.public,
            text:
                'What are you learning today?\n\n'
                'Share your learning journey with the NoteBook '
                'community. 🌍',
            likes: '67',
            comments: '18',
          ),
        ],
      ),
    );
  }

  // ============================================================
  // STORIES
  // ============================================================

  Widget _buildStoriesSection() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 12),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Stories',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),

          const SizedBox(height: 10),

          SizedBox(
            height: 105,

            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: stories.length,

              itemBuilder: (context, index) {
                final story = stories[index];

                return GestureDetector(
                  onTap: () {
                    if (index == 0) {
                      showComingSoon('Add Story');
                    } else {
                      showComingSoon('Stories');
                    }
                  },

                  child: Container(
                    width: 82,
                    margin: const EdgeInsets.symmetric(horizontal: 4),

                    child: Column(
                      children: [
                        Container(
                          width: 65,
                          height: 65,

                          decoration: BoxDecoration(
                            shape: BoxShape.circle,

                            color: index == 0
                                ? const Color(0xFFE8F0FE)
                                : Colors.white,

                            border: Border.all(
                              color: const Color(0xFF1877F2),
                              width: 2,
                            ),
                          ),

                          child: Icon(
                            index == 0 ? Icons.add : Icons.person,
                            color: const Color(0xFF1877F2),
                            size: 30,
                          ),
                        ),

                        const SizedBox(height: 6),

                        Text(
                          story,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,

                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // CREATE POST CARD
  // ============================================================

  Widget _buildCreatePostCard({required User? user, required String userName}) {
    return Container(
      color: Colors.white,

      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),

      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: const Color(0xFFE8F0FE),

            backgroundImage: user?.photoURL != null
                ? NetworkImage(user!.photoURL!)
                : null,

            child: user?.photoURL == null
                ? const Icon(Icons.person, color: Color(0xFF1877F2))
                : null,
          ),

          const SizedBox(width: 10),

          Expanded(
            child: GestureDetector(
              onTap: () {
                _showCreateMenu();
              },

              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),

                decoration: BoxDecoration(
                  color: const Color(0xFFF0F2F5),
                  borderRadius: BorderRadius.circular(24),
                ),

                child: Text(
                  "What's on your mind, $userName?",
                  style: const TextStyle(color: Colors.grey, fontSize: 15),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ============================================================
  // POST CARD
  // ============================================================

  Widget _buildPostCard({
    required String name,
    required String category,
    required String time,
    required IconData avatarIcon,
    required String text,
    required String likes,
    required String comments,
  }) {
    return Container(
      color: Colors.white,

      padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),

      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,

        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: const Color(0xFFE8F0FE),

                child: Icon(avatarIcon, color: const Color(0xFF1877F2)),
              ),

              const SizedBox(width: 10),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Text(
                      name,

                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),

                    const SizedBox(height: 2),

                    Row(
                      children: [
                        Text(
                          category,

                          style: const TextStyle(
                            color: Color(0xFF1877F2),
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),

                        const Text(
                          '  •  ',
                          style: TextStyle(color: Colors.grey),
                        ),

                        Text(
                          time,

                          style: const TextStyle(
                            color: Colors.grey,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              IconButton(
                onPressed: () {
                  showComingSoon('Post Menu');
                },

                icon: const Icon(Icons.more_horiz),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Text(text, style: const TextStyle(fontSize: 15, height: 1.45)),

          const SizedBox(height: 14),

          Row(
            children: [
              const Icon(Icons.thumb_up, size: 17, color: Color(0xFF1877F2)),

              const SizedBox(width: 5),

              Text(
                likes,
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),

              const Spacer(),

              Text(
                '$comments comments',
                style: const TextStyle(color: Colors.grey, fontSize: 13),
              ),
            ],
          ),

          const SizedBox(height: 8),

          const Divider(height: 1),

          const SizedBox(height: 4),

          Row(
            children: [
              Expanded(
                child: _buildPostAction(
                  icon: Icons.thumb_up_outlined,
                  label: 'Like',
                ),
              ),

              Expanded(
                child: _buildPostAction(
                  icon: Icons.chat_bubble_outline,
                  label: 'Comment',
                ),
              ),

              Expanded(
                child: _buildPostAction(
                  icon: Icons.share_outlined,
                  label: 'Share',
                ),
              ),

              Expanded(
                child: _buildPostAction(
                  icon: Icons.bookmark_border,
                  label: 'Save',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ============================================================
  // POST ACTION
  // ============================================================

  Widget _buildPostAction({required IconData icon, required String label}) {
    return InkWell(
      onTap: () {
        showComingSoon(label);
      },

      borderRadius: BorderRadius.circular(8),

      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),

        child: Column(
          children: [
            Icon(icon, size: 21, color: Colors.grey.shade700),

            const SizedBox(height: 3),

            Text(
              label,
              style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // WATCH
  // ============================================================

  Widget _buildWatchPlaceholder() {
    return _buildSectionPlaceholder(
      icon: Icons.play_circle_outline,
      title: 'Watch',
      subtitle: 'Educational videos will appear here.',
    );
  }

  // ============================================================
  // LIBRARY
  // ============================================================

  Widget _buildLibraryPlaceholder() {
    return _buildSectionPlaceholder(
      icon: Icons.library_books_outlined,
      title: 'Library',
      subtitle: 'Learning materials and PDFs will appear here.',
    );
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  Widget _buildNotificationsPlaceholder() {
    return _buildSectionPlaceholder(
      icon: Icons.notifications_none_rounded,
      title: 'Notifications',
      subtitle: 'Your NoteBook notifications will appear here.',
    );
  }

  // ============================================================
  // PROFILE PLACEHOLDER
  // ============================================================

  Widget _buildProfilePlaceholder() {
    return Center(
      child: FilledButton.icon(
        onPressed: openProfile,
        icon: const Icon(Icons.person),
        label: const Text('Open My Profile'),
      ),
    );
  }

  // ============================================================
  // SECTION PLACEHOLDER
  // ============================================================

  Widget _buildSectionPlaceholder({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(30),

        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(icon, size: 75, color: const Color(0xFF1877F2)),

            const SizedBox(height: 18),

            Text(
              title,
              style: const TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey, fontSize: 15),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// PROFILE SCREEN
// ============================================================

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final nameController = TextEditingController();

  bool loading = true;
  bool saving = false;

  String role = 'Student';

  Future<void> loadProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      if (doc.exists) {
        final data = doc.data();

        nameController.text = data?['name'] ?? user.displayName ?? '';

        final savedRole = data?['role'];

        if (savedRole == 'Student' || savedRole == 'Teacher') {
          role = savedRole;
        }
      } else {
        nameController.text = user.displayName ?? '';
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not load profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  Future<void> saveProfile() async {
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return;

    final name = nameController.text.trim();

    if (name.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter your name.')));

      return;
    }

    setState(() {
      saving = true;
    });

    try {
      await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
        'uid': user.uid,
        'name': name,
        'email': user.email,
        'phoneNumber': user.phoneNumber,
        'role': role,
        'photoURL': user.photoURL,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile saved successfully! ✅')),
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Could not save profile: $e')));
      }
    } finally {
      if (mounted) {
        setState(() {
          saving = false;
        });
      }
    }
  }

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  @override
  void dispose() {
    nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),
      appBar: AppBar(
        title: const Text(
          'My Profile',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: loading
          ? const Center(
              child: CircularProgressIndicator(color: Color(0xFF1877F2)),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 55,
                    backgroundColor: const Color(0xFFE8F0FE),
                    backgroundImage: user?.photoURL != null
                        ? NetworkImage(user!.photoURL!)
                        : null,
                    child: user?.photoURL == null
                        ? const Icon(
                            Icons.person,
                            size: 60,
                            color: Color(0xFF1877F2),
                          )
                        : null,
                  ),

                  const SizedBox(height: 15),

                  Text(
                    user?.email ?? user?.phoneNumber ?? '',
                    style: const TextStyle(color: Colors.grey),
                  ),

                  const SizedBox(height: 25),

                  TextField(
                    controller: nameController,
                    textCapitalization: TextCapitalization.words,
                    decoration: const InputDecoration(
                      labelText: 'Full Name',
                      prefixIcon: Icon(Icons.person_outline),
                      border: OutlineInputBorder(),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),

                  const SizedBox(height: 20),

                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Account Type',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 10),

                        DropdownButtonFormField<String>(
                          initialValue: role,
                          decoration: const InputDecoration(
                            border: OutlineInputBorder(),
                            prefixIcon: Icon(Icons.school),
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'Student',
                              child: Text('Student'),
                            ),
                            DropdownMenuItem(
                              value: 'Teacher',
                              child: Text('Teacher'),
                            ),
                          ],
                          onChanged: (value) {
                            if (value == null) {
                              return;
                            }

                            setState(() {
                              role = value;
                            });
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 30),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: FilledButton.icon(
                      onPressed: saving ? null : saveProfile,
                      icon: saving
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                color: Colors.white,
                                strokeWidth: 2,
                              ),
                            )
                          : const Icon(Icons.save),
                      label: Text(
                        saving ? 'Saving...' : 'Save Profile',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

// ============================================
// EMAIL PASSWORD RESET - OTP SCREEN
// ============================================

class EmailOTPVerificationScreen extends StatefulWidget {
  final String email;

  const EmailOTPVerificationScreen({super.key, required this.email});

  @override
  State<EmailOTPVerificationScreen> createState() =>
      _EmailOTPVerificationScreenState();
}

class _EmailOTPVerificationScreenState
    extends State<EmailOTPVerificationScreen> {
  final otpController = TextEditingController();

  bool loading = false;

  Future<void> verifyEmailOTP() async {
    final otp = otpController.text.trim();

    if (otp.length != 6) {
      showMessage('Please enter the 6-digit OTP.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
          'http://127.0.0.1:5001/smart-notebook-5f2b9/us-central1/verifyPasswordOtp',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': widget.email, 'otp': otp}),
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        final resetToken = data['resetToken'];

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => ResetPasswordScreen(
              email: widget.email,
              resetToken: resetToken,
            ),
          ),
        );
      } else {
        showMessage(data['message'] ?? 'Invalid verification code.');
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    otpController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Verify Email')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              const Icon(
                Icons.mark_email_read_outlined,
                size: 70,
                color: Color(0xFF1877F2),
              ),

              const SizedBox(height: 20),

              const Text(
                'Enter the 6-digit code',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Text(
                'We sent a verification code to\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: otpController,
                keyboardType: TextInputType.number,
                maxLength: 6,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 24,
                  letterSpacing: 8,
                  fontWeight: FontWeight.bold,
                ),
                decoration: const InputDecoration(
                  labelText: '6-digit OTP',
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 15),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: loading ? null : verifyEmailOTP,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Verify OTP',
                          style: TextStyle(fontSize: 17),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================
// RESET PASSWORD SCREEN
// ============================================

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  final String resetToken;

  const ResetPasswordScreen({
    super.key,
    required this.email,
    required this.resetToken,
  });

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final newPasswordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool loading = false;

  Future<void> resetPassword() async {
    final newPassword = newPasswordController.text.trim();
    final confirmPassword = confirmPasswordController.text.trim();

    if (newPassword.length < 6) {
      showMessage('Password must be at least 6 characters.');
      return;
    }

    if (newPassword != confirmPassword) {
      showMessage('Passwords do not match.');
      return;
    }

    setState(() {
      loading = true;
    });

    try {
      final response = await http.post(
        Uri.parse(
          'http://127.0.0.1:5001/smart-notebook-5f2b9/us-central1/resetPassword',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'resetToken': widget.resetToken,
          'newPassword': newPassword,
        }),
      );

      if (!mounted) return;

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data['success'] == true) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const AuthGate()),
          (route) => false,
        );
      } else {
        showMessage(data['message'] ?? 'Could not reset password.');
      }
    } catch (e) {
      if (mounted) {
        showMessage('Password reset failed: $e');
      }
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  void showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    newPasswordController.dispose();
    confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              const SizedBox(height: 40),

              const Icon(
                Icons.lock_reset_rounded,
                size: 75,
                color: Color(0xFF1877F2),
              ),

              const SizedBox(height: 20),

              const Text(
                'Create a new password',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 23, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 10),

              Text(
                'Enter a new password for\n${widget.email}',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 15, color: Colors.grey),
              ),

              const SizedBox(height: 30),

              TextField(
                controller: newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 16),

              TextField(
                controller: confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  prefixIcon: Icon(Icons.lock_outline),
                  border: OutlineInputBorder(),
                ),
              ),

              const SizedBox(height: 24),

              SizedBox(
                width: double.infinity,
                height: 54,
                child: FilledButton(
                  onPressed: loading ? null : resetPassword,
                  child: loading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text(
                          'Reset Password',
                          style: TextStyle(fontSize: 17),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
// ============================================
// CREATE POST SCREEN
// ============================================

class CreatePostScreen extends StatefulWidget {
  final String userName;
  final String? photoURL;

  const CreatePostScreen({super.key, required this.userName, this.photoURL});

  @override
  State<CreatePostScreen> createState() => _CreatePostScreenState();
}

class _CreatePostScreenState extends State<CreatePostScreen> {
  final postController = TextEditingController();

  @override
  void dispose() {
    postController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF0F2F5),

      appBar: AppBar(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0.5,
        title: const Text(
          'Create Post',
          style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold),
        ),
      ),

      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 20),

          child: Column(
            children: [
              Container(
                color: Colors.white,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 23,
                          backgroundColor: const Color(0xFFE8F0FE),
                          backgroundImage: widget.photoURL != null
                              ? NetworkImage(widget.photoURL!)
                              : null,
                          child: widget.photoURL == null
                              ? const Icon(
                                  Icons.person,
                                  color: Color(0xFF1877F2),
                                )
                              : null,
                        ),

                        const SizedBox(width: 10),

                        Text(
                          widget.userName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    TextField(
                      controller: postController,
                      minLines: 5,
                      maxLines: null,
                      textCapitalization: TextCapitalization.sentences,

                      decoration: const InputDecoration(
                        hintText: "What's on your mind?",
                        hintStyle: TextStyle(color: Colors.grey, fontSize: 17),
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Container(
                color: Colors.white,

                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),

                child: Column(
                  children: [
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Add to your post',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    const SizedBox(height: 8),

                    Row(
                      children: [
                        Expanded(
                          child: _buildPostOption(
                            icon: Icons.photo_library_outlined,
                            label: 'Photo',
                            iconColor: Colors.green,
                          ),
                        ),

                        Expanded(
                          child: _buildPostOption(
                            icon: Icons.videocam_outlined,
                            label: 'Video',
                            iconColor: Colors.red,
                          ),
                        ),

                        Expanded(
                          child: _buildPostOption(
                            icon: Icons.picture_as_pdf_outlined,
                            label: 'PDF',
                            iconColor: Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 8),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),

                child: SizedBox(
                  width: double.infinity,
                  height: 52,

                  child: FilledButton(
                    onPressed: () async {
                      final text = postController.text.trim();

                      if (text.isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please write something first.'),
                          ),
                        );
                        return;
                      }

                      try {
                        final user = FirebaseAuth.instance.currentUser;

                        if (user == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Please login first.'),
                            ),
                          );
                          return;
                        }

                        await FirebaseFirestore.instance
                            .collection('posts')
                            .add({
                              'uid': user.uid,
                              'userName': widget.userName,
                              'photoURL': widget.photoURL,
                              'text': text,
                              'type': 'text',
                              'likes': 0,
                              'comments': 0,
                              'createdAt': FieldValue.serverTimestamp(),
                            });

                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Post published successfully!'),
                          ),
                        );

                        Navigator.pop(context);
                      } catch (e) {
                        if (!mounted) return;

                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Failed to publish post: $e')),
                        );
                      }
                    },

                    child: const Text(
                      'Post',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPostOption({
    required IconData icon,
    required String label,
    required Color iconColor,
  }) {
    return InkWell(
      onTap: () {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('$label upload will be added next.')),
        );
      },

      borderRadius: BorderRadius.circular(10),

      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),

        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,

          children: [
            Icon(icon, color: iconColor, size: 25),

            const SizedBox(width: 6),

            Text(
              label,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
