import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/connectivity/connectivity_provider.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/utils/validators.dart';
import '../../data/providers.dart';
import '../catalog/catalog_controller.dart';
import 'auth_controller.dart';

/// The app is used offline by default, so this screen always leads with the
/// offline path (uses whatever catalog data was last synced). Signing in is
/// a secondary action, only needed to download/refresh that data.
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  // For local testing only: uncomment the two lines below to pre-fill the
  // test account, then re-comment (or discard the change) before committing.
  // Real credentials must never land in a commit — git history keeps them
  // forever, even after a later commit removes them again.
  final _emailController = TextEditingController(
    // text: 'bharathbiomedpharma@gmail.com',
  );
  final _passwordController = TextEditingController(
    // text: 'Bharath@2024',
  );
  final _formKey = GlobalKey<FormState>();
  bool _signInSectionExpanded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => FlutterNativeSplash.remove());
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Primary path for this app: skip auth entirely and open the catalog
  /// using whatever was last downloaded to this device. If nothing has ever
  /// been synced, there's nothing to show offline, so send the user to the
  /// sign-in section instead.
  Future<void> _continueOffline() async {
    final hasData = await ref.read(productRepositoryProvider).hasCachedCatalog();
    if (!mounted) return;

    if (!hasData) {
      setState(() => _signInSectionExpanded = true);
      QuickAlert.show(
        context: context,
        type: QuickAlertType.info,
        title: 'No data yet',
        text: 'No catalog data has been downloaded to this device yet. Please sign in and sync data first.',
      );
      return;
    }

    await ref.read(catalogControllerProvider.future);
    if (!mounted) return;
    context.go('/catalog');
  }

  /// Secondary path: authenticate against Firebase, then immediately sync
  /// so the freshly-signed-in user has current data available offline
  /// afterwards.
  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    await ref.read(authControllerProvider.notifier).signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    if (authState.hasError) {
      final message = UserFacingError.describe(authState.error!);
      QuickAlert.show(context: context, type: QuickAlertType.error, title: 'Sign-in error', text: message);
      return;
    }

    // Reuse the same sync path as the in-catalog sync button, so the very
    // first sign-in also downloads the catalog for later offline use.
    try {
      await ref.read(catalogControllerProvider.notifier).sync();
      if (!mounted) return;
      await QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'Synced',
        text: 'Data synced successfully.',
        autoCloseDuration: const Duration(seconds: 1),
      );
    } catch (error) {
      if (!mounted) return;
      await QuickAlert.show(
        context: context,
        type: QuickAlertType.warning,
        title: 'Signed in, but sync failed',
        text: '${UserFacingError.describe(error)} You can retry from the sync button.',
      );
    }
    if (!mounted) return;
    context.go('/catalog');
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final isSigningIn = ref.watch(authControllerProvider).isLoading;

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Image.asset('assets/blogo.png', height: 50, width: 50),
                const SizedBox(height: 16),
                connectivity.when(
                  loading: () => const SizedBox.shrink(),
                  error: (error, _) => const SizedBox.shrink(),
                  data: (results) => Text(
                    NetworkStatus.describe(results),
                    style: TextStyle(
                      color: NetworkStatus.isOffline(results) ? Colors.orange : Colors.green,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Offline Mode',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This app works fully offline using the last data you synced.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _continueOffline,
                  child: const Text('Continue Offline'),
                ),
                const SizedBox(height: 32),
                if (!_signInSectionExpanded)
                  TextButton(
                    onPressed: () => setState(() => _signInSectionExpanded = true),
                    child: const Text('Sign in to download / sync data'),
                  )
                else ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  const Text(
                    'Sign in to sync data',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _emailController,
                    decoration: const InputDecoration(labelText: 'Email'),
                    keyboardType: TextInputType.emailAddress,
                    validator: Validators.email,
                  ),
                  TextFormField(
                    controller: _passwordController,
                    decoration: const InputDecoration(labelText: 'Password'),
                    obscureText: true,
                    validator: Validators.password,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isSigningIn ? null : _login,
                    child: isSigningIn
                        ? const SizedBox(
                            height: 16,
                            width: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Sign In & Sync'),
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
