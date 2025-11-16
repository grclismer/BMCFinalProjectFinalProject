import 'package:ecommerce_app/screens/signup_screen.dart';
import 'package:ecommerce_app/screens/forgot_password_screen.dart';
import 'package:ecommerce_app/screens/home_screen.dart'; // **NEW IMPORT for successful navigation**
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

// 1. Create a StatefulWidget
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

// 2. This is the State class
class _LoginScreenState extends State<LoginScreen> {

  // 3. Create a GlobalKey for the Form
  final _formKey = GlobalKey<FormState>();

  // 4. Create TextEditingControllers
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  // 5. Clean up controllers when the widget is removed

  bool _isLoading = false;

  final FirebaseAuth _auth = FirebaseAuth.instance;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    // 1. Check if the form is valid
    if (!_formKey.currentState!.validate()) {
      return; // If not valid, stop here
    }

    // 2. Set loading to true
    setState(() {
      _isLoading = true;
    });

    try {
      // 3. This is the Firebase command to sign in
      await _auth.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // **CRITICAL FIX:** Manually navigate to the home screen
      // upon successful login to ensure navigation occurs immediately,
      // bypassing any potential issue with the passive AuthWrapper stream.
      if (mounted) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const HomeScreen()),
              (Route<dynamic> route) => false, // Clear all previous routes
        );
      }

    } on FirebaseAuthException catch (e) {
      // 5. This 'catch' block handles Firebase-specific errors

      // **FIXED: Enhanced Error Reporting**
      String message = 'Login failed. Please check credentials.';
      String detailedMessage = e.message ?? 'Unknown Firebase Error';

      if (e.code == 'user-not-found') {
        message = 'No user found for that email.';
      } else if (e.code == 'wrong-password') {
        message = 'The password entered is incorrect.';
      } else if (e.code == 'invalid-email') {
        message = 'The email format is invalid.';
      } else {
        // Catch any other specific error Firebase might throw (e.g., user-disabled)
        message = 'Login failed (${e.code}): $detailedMessage';
      }

      // Print full error to console for debugging
      print('Firebase Auth Error during login: ${e.code}, Message: $detailedMessage');

      // 6. Show the error message in a SnackBar
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } catch (e) {
      // 7. Catch any other general errors
      print('General login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('An unexpected error occurred: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }

    // 8. ALWAYS set loading to false at the end, only if we haven't navigated away
    if (mounted && _isLoading) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: Column(
                children: [
                  SizedBox(height: constraints.maxHeight * 0.1),

                  Image.asset(
                    'assets/images/app_logo.png',
                    height: 250,
                    width: 250,
                    fit: BoxFit.contain,
                  ),

                  SizedBox(height: constraints.maxHeight * 0.01),

                  Text(
                    "Log in",
                    style: Theme.of(context)
                        .textTheme
                        .headlineSmall!
                        .copyWith(fontWeight: FontWeight.bold),
                  ),

                  SizedBox(height: constraints.maxHeight * 0.05),

                  Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // 2. The Email Text Field
                        TextFormField(
                          controller: _emailController,
                          decoration: const InputDecoration(
                            hintText: 'Email',
                            filled: true,
                            fillColor: Color(0xFFF5FCF9),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 16.0 * 1.5, vertical: 16.0),
                            border: OutlineInputBorder(
                              borderSide: BorderSide.none,
                              borderRadius: BorderRadius.all(Radius.circular(50)),
                            ),
                          ),
                          keyboardType: TextInputType.emailAddress,
                          // 5. Show '@' on keyboard
                          // 6. Validator function
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter your email';
                            }
                            if (!value.contains('@')) {
                              return 'Please enter a valid email';
                            }
                            return null; // 'null' means the input is valid
                          },
                        ),

                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16.0),
                          child: TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: const InputDecoration(
                              hintText: 'Password',
                              filled: true,
                              fillColor: Color(0xFFF5FCF9),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 16.0 * 1.5, vertical: 16.0),
                              border: OutlineInputBorder(
                                borderSide: BorderSide.none,
                                borderRadius: BorderRadius.all(Radius.circular(50)),
                              ),
                            ),
                            // 11. Validator function
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return 'Please enter your password';
                              }
                              if (value.length < 6) {
                                return 'Password must be at least 6 characters';
                              }
                              return null;
                            },
                          ),
                        ),

                        // 2. The Login Button
                        ElevatedButton(
                          onPressed: _isLoading ? null : _login,
                          style: ElevatedButton.styleFrom(
                            elevation: 0,
                            backgroundColor: Theme.of(context).primaryColor, // Using your current theme color
                            foregroundColor: Colors.white,
                            minimumSize: const Size(double.infinity, 48),
                            shape: const StadiumBorder(),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          )
                              : const Text("Sign in"),
                        ),

                        const SizedBox(height: 16.0),

                        // Forgot password
                        TextButton(
                          onPressed: _isLoading ? null : () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (context) => const ForgotPasswordScreen(),
                              ),
                            );
                          },
                          child: Text(
                            'Forgot Password?',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .color!
                                  .withOpacity(0.64),
                            ),
                          ),
                        ),

                        // 7. The "Sign Up" toggle button
                        TextButton(
                          onPressed: _isLoading ? null : () {
                            // 8. Navigate to the Sign Up screen
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const SignUpScreen(),
                              ),
                            );
                          },
                          child: Text.rich(
                            const TextSpan(
                              text: "Don't have an account? ",
                              children: [
                                TextSpan(
                                  text: "Sign Up",
                                  style: TextStyle(color: Color(0xFF00BF6D)),
                                ),
                              ],
                            ),
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium!
                                .copyWith(
                              color: Theme.of(context)
                                  .textTheme
                                  .bodyLarge!
                                  .color!
                                  .withOpacity(0.64),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}