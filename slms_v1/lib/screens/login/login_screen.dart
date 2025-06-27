import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:schoollms/services/database_service.dart';
import 'package:schoollms/models/user.dart';
import 'package:country_code_picker/country_code_picker.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  String role = 'Please Select Your Role', country = '', citizenshipId = '';
  bool _obscureText = true; // For toggling citizenship ID visibility
  bool _isLoading = false; // Track loading state

  @override
  void initState() {
    super.initState();
    _initializeDatabase();
  }

  Future<void> _initializeDatabase() async {
    final db = Provider.of<DatabaseService>(context, listen: false);
    try {
      await db.init();
    } catch (e) {
      print('Database initialization error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to initialize database')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final db = Provider.of<DatabaseService>(context, listen: false);
    return Scaffold(
      body: SingleChildScrollView(
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFFF1F5F9), Color(0xFFD4A017)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/images/schoollms_logo.png',
                  height: 120,
                  width: 120,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(Icons.error,
                        size: 120, color: Colors.red);
                  },
                ),
                const SizedBox(height: 20),
                Card(
                  elevation: 8,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text(
                          'Welcome to SchoolLMS',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF1E3A8A),
                          ),
                        ),
                        const SizedBox(height: 20),
                        DropdownButtonFormField<String>(
                          value: role,
                          decoration: const InputDecoration(
                            labelText: 'Role',
                            border: OutlineInputBorder(),
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: 'Please Select Your Role',
                              child: Text('Please Select Your Role'),
                            ),
                            ...['teacher', 'learner', 'parent', 'admin']
                                .map((r) => DropdownMenuItem(
                                      value: r,
                                      child: Text(r.capitalize()),
                                    ))
                                .toList(),
                          ],
                          onChanged: (val) => setState(() => role = val!),
                          validator: (value) {
                            if (value == 'Please Select Your Role') {
                              return 'Please select a valid role';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 15),
                        const Text(
                          'Click the flag to select your country',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: EdgeInsets.zero,
                          child: CountryCodePicker(
                            onChanged: (CountryCode code) {
                              setState(() => country = code.name!);
                            },
                            initialSelection: 'ZA',
                            favorite: ['ZA', 'US', 'GB'],
                            showFlag: true,
                            showCountryOnly: true,
                            alignLeft: false,
                          ),
                        ),
                        const SizedBox(height: 15),
                        TextFormField(
                          decoration: const InputDecoration(
                            labelText: 'Citizenship ID',
                            border: OutlineInputBorder(),
                            suffixIcon: Icon(Icons.visibility),
                          ),
                          obscureText: _obscureText,
                          onChanged: (val) => citizenshipId = val,
                        ),
                        const SizedBox(height: 20),
                        ElevatedButton(
                          onPressed: _isLoading
                              ? null
                              : () async {
                                  if (_formKey.currentState!.validate()) {
                                    setState(() => _isLoading = true);
                                    try {
                                      final user =
                                          await db.getUserByCitizenship(
                                              country, citizenshipId);
                                      if (user != null) {
                                        final userRole = user['role'] as String;
                                        if (userRole == role) {
                                          Navigator.pushReplacementNamed(
                                              context, '/timetable',
                                              arguments: {
                                                'userId': user['id'] as String,
                                                'role': role,
                                              });
                                        } else {
                                          ScaffoldMessenger.of(context)
                                              .showSnackBar(const SnackBar(
                                                  content: Text(
                                                      'Role does not match credentials')));
                                        }
                                      } else {
                                        ScaffoldMessenger.of(context)
                                            .showSnackBar(const SnackBar(
                                                content: Text(
                                                    'Invalid credentials')));
                                      }
                                    } catch (e) {
                                      print('Login error: $e');
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(const SnackBar(
                                              content: Text(
                                                  'Login failed. Please try again.')));
                                    } finally {
                                      setState(() => _isLoading = false);
                                    }
                                  }
                                },
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(double.infinity, 50),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                                  color: Colors.white,
                                )
                              : const Text('Login'),
                        ),
                        const SizedBox(height: 10),
                        // Register Button with Validation
                        TextButton(
                          onPressed: () {
                            if (role == 'Please Select Your Role') {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Role Selection Required'),
                                  content: const Text(
                                      'Please select a valid role before registering.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            } else if (role == 'parent' || role == 'admin') {
                              showDialog(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title:
                                      const Text('Registration Not Available'),
                                  content: const Text(
                                      'Registration for selected role is not currently available. Please contact support.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('OK'),
                                    ),
                                  ],
                                ),
                              );
                            } else {
                              Navigator.pushNamed(
                                  context, '/${role}_registration');
                            }
                          },
                          child: const Text(
                            'Don\'t have an account? Register',
                            style: TextStyle(color: Color(0xFF1E7C8D)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Footer Credit
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Text(
                    'SchoolLMS (c) 2014-2025 (schoollms.online), powered by Grok, design by MOADEfy (moade.online), distributed by NyayoZetu (nyayozetu.online), version 1.0 released June 2025',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Extension to capitalize role names
extension StringExtension on String {
  String capitalize() {
    return "${this[0].toUpperCase()}${this.substring(1).toLowerCase()}";
  }
}
