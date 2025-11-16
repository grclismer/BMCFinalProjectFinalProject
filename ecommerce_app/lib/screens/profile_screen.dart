import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart'; // Added Firestore
import 'package:google_fonts/google_fonts.dart';      // Added Google Fonts
import 'package:ecommerce_app/screens/auth_wrapper.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // --- Constants and Instances ---
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance; // Added Firestore
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final kGreen = const Color(0xFF00BF6D); // Defined a primary color

  // --- Form Keys and Controllers ---
  final _passFormKey = GlobalKey<FormState>();
  final _nameFormKey = GlobalKey<FormState>(); // New key for the name form

  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _firstNameController = TextEditingController(); // New controller
  final TextEditingController _lastNameController = TextEditingController();  // New controller

  // --- State Variables ---
  bool _isLoading = true; // Tracks initial profile loading and form submissions
  bool _isSavingName = false;
  bool _isChangingPassword = false;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  @override
  void dispose() {
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    super.dispose();
  }

  // --- Profile Data Handling (New Logic) ---

  Future<void> _loadUserProfile() async {
    final user = _currentUser;
    if (user == null) {
      if (mounted) _showSnackbar('Error: User not signed in.', Colors.red);
      setState(() => _isLoading = false);
      return;
    }

    try {
      final doc = await _firestore.collection('users').doc(user.uid).get();
      if (doc.exists) {
        final data = doc.data();
        _firstNameController.text = data?['firstName'] ?? '';
        _lastNameController.text = data?['lastName'] ?? '';
      }
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _saveUserProfile() async {
    if (!_nameFormKey.currentState!.validate()) return;
    if (_currentUser == null) return;

    setState(() => _isSavingName = true);

    try {
      await _firestore.collection('users').doc(_currentUser!.uid).set({
        'firstName': _firstNameController.text.trim(),
        'lastName': _lastNameController.text.trim(),
        'email': _currentUser!.email,
        'lastUpdated': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (mounted) _showSnackbar('Name saved successfully!', kGreen);
    } catch (e) {
      if (mounted) _showSnackbar('Failed to save name: $e', Colors.red);
      print('Error saving profile: $e');
    } finally {
      if (mounted) setState(() => _isSavingName = false);
    }
  }

  // --- Auth Management (Existing Logic, updated with loading state) ---

  Future<void> _changePassword() async {
    if (!_passFormKey.currentState!.validate()) return;
    if (_currentUser == null) return;

    setState(() => _isChangingPassword = true);

    try {
      await _currentUser!.updatePassword(_newPasswordController.text);

      _showSnackbar('Password changed successfully!', kGreen);

      _passFormKey.currentState!.reset();
      _newPasswordController.clear();
      _confirmPasswordController.clear();

    } on FirebaseAuthException catch (e) {
      // requires-recent-login is the most common error
      _showSnackbar('Failed to change password: ${e.message}', Colors.red);
      print("Error changing password: ${e.code}");
    } finally {
      if (mounted) setState(() => _isChangingPassword = false);
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
      );
    } catch (e) {
      print("Error during sign out: $e");
      // Fallback navigation even if sign out fails gracefully
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AuthWrapper()),
            (route) => false,
      );
    }
  }

  // --- Helper for Snackbars ---
  void _showSnackbar(String message, Color color) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: color,
        ),
      );
    }
  }

  // --- UI Build Methods ---

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
      child: Text(
        title,
        style: GoogleFonts.poppins(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: kGreen,
        ),
      ),
    );
  }

  Widget _buildNameEditSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _nameFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader('Profile Information'),

              Text(
                'Email: ${_currentUser?.email ?? 'Not logged in'}',
                style: GoogleFonts.roboto(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 16),

              TextFormField(
                controller: _firstNameController,
                decoration: const InputDecoration(
                  labelText: 'First Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person_outline),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _lastNameController,
                decoration: const InputDecoration(
                  labelText: 'Last Name',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.person),
                ),
                validator: (value) => value == null || value.trim().isEmpty ? 'Required' : null,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isSavingName ? null : _saveUserProfile,
                style: ElevatedButton.styleFrom(
                  backgroundColor: kGreen,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                child: _isSavingName
                    ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : Text(
                  'Save Profile',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordChangeSection() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.only(bottom: 24),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _passFormKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildSectionHeader('Security Settings'),

              TextFormField(
                controller: _newPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'New Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_open),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please enter a password';
                  if (value.length < 6) return 'Password must be at least 6 characters';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirm Password',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                validator: (value) {
                  if (value == null || value.isEmpty) return 'Please confirm your password';
                  if (value != _newPasswordController.text) return 'Passwords do not match';
                  return null;
                },
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  backgroundColor: Colors.blueGrey,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: _isChangingPassword ? null : _changePassword,
                child: _isChangingPassword
                    ? const SizedBox(
                  width: 20, height: 20,
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                )
                    : Text(
                  'Change Password',
                  style: GoogleFonts.poppins(fontSize: 16, color: Colors.white),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLogoutSection() {
    return ElevatedButton.icon(
      icon: const Icon(Icons.logout, color: Colors.white),
      label: Text(
          'Log Out',
          style: GoogleFonts.poppins(fontSize: 16, color: Colors.white)
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red[700],
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      onPressed: _signOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('My Profile', style: GoogleFonts.poppins(fontWeight: FontWeight.w600)),
        backgroundColor: kGreen,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Name and Email Editing Section
            _buildNameEditSection(),

            // 2. Change Password Section
            _buildPasswordChangeSection(),

            // 3. Logout Button
            const SizedBox(height: 16),
            _buildLogoutSection(),
            const SizedBox(height: 40), // Extra space at the bottom
          ],
        ),
      ),
    );
  }
}