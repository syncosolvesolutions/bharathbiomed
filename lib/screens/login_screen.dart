import 'dart:async';

import 'package:bharathbiomedpharma/services/firebase_auth_service.dart';
import 'package:bharathbiomedpharma/services/firebase_firestore_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:quickalert/quickalert.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController(
    text: "bharathbiomedpharma@gmail.com",
  );
  final _passwordController = TextEditingController(
    text: "Bharath@2024",
  );
  final _formKey = GlobalKey<FormState>();
  final FirebaseAuthService _authService = FirebaseAuthService();
  bool _isOffline = false;
  String _networkStatus = 'Checking network status...';
  late StreamSubscription<List<ConnectivityResult>> subscription;

  Future<void> _checkNetworkStatus() async {
    final List<ConnectivityResult> connectivityResult =
        await (Connectivity().checkConnectivity());
    debugPrint('Connectivity results: $connectivityResult');

    setState(() {
      _isOffline = connectivityResult.contains(ConnectivityResult.none);
      _networkStatus = _determineNetworkStatus(connectivityResult);
      debugPrint('Offline: $_isOffline');
    });
  }

  String _determineNetworkStatus(List<ConnectivityResult> results) {
    if (results.contains(ConnectivityResult.none)) {
      return 'No available network types';
    } else if (results.contains(ConnectivityResult.mobile)) {
      return 'Mobile network available';
    } else if (results.contains(ConnectivityResult.wifi)) {
      return 'Wi-Fi available';
    } else if (results.contains(ConnectivityResult.ethernet)) {
      return 'Ethernet connection available';
    } else if (results.contains(ConnectivityResult.vpn)) {
      return 'VPN connection active';
    } else if (results.contains(ConnectivityResult.bluetooth)) {
      return 'Bluetooth connection available';
    } else if (results.contains(ConnectivityResult.other)) {
      return 'Connected to an unknown network';
    }
    return 'Unknown network status';
  }

  Future<void> _login(BuildContext context) async {
    if (_formKey.currentState!.validate()) {
      User? user = await _authService.signInWithEmailAndPassword(
        _emailController.text.trim(),
        _passwordController.text.trim(),
      );
      if (user != null) {
        await FirebaseFirestoreService().syncData(
          (successMessage) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(successMessage)),
            );
          },
          (errorMessage) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(errorMessage)),
            );
          },
        );
        // ignore: use_build_context_synchronously
        Navigator.pushReplacementNamed(context, '/productList');
      } else {
        QuickAlert.show(
          // ignore: use_build_context_synchronously
          context: context,
          type: QuickAlertType.error,
          title: 'SignIn Error',
          text:
              'Failed to sign in. Please check your credentials and try again.',
        );
      }
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      FlutterNativeSplash.remove();
      subscription = Connectivity()
          .onConnectivityChanged
          .listen((List<ConnectivityResult> result) {
        debugPrint('Received changes in available connectivity types: $result');
        _checkNetworkStatus();
        setState(() {
          _networkStatus = _determineNetworkStatus(result);
        });
      });
    });
  }

  @override
  void dispose() {
    subscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset('assets/blogo.png', height: 50, width: 50),
                const SizedBox(height: 20),
                Text(
                  _networkStatus,
                  style: TextStyle(
                    color: _isOffline ? Colors.red : Colors.green,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 20),
                if (_isOffline) ...[
                  const Text(
                    'Offline Mode',
                    style: TextStyle(color: Colors.red, fontSize: 18),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    child: const Text('Continue in Offline Mode'),
                    onPressed: () async {
                      await FirebaseFirestoreService().getAllProducts(
                        (successMessage) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(successMessage)),
                          );
                        },
                        (errorMessage) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text(errorMessage)),
                          );
                        },
                      );
                      // ignore: use_build_context_synchronously
                      Navigator.pushReplacementNamed(context, '/productList');
                    },
                  ),
                ] else ...[
                  const Text(
                    'Live Mode',
                    style: TextStyle(color: Colors.red, fontSize: 18),
                  ),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your email';
                      } else if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'Please enter a valid email address';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter your password';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    child: const Text('Login'),
                    onPressed: () => _formKey.currentState!.validate()
                        ? _login(context)
                        : null,
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
