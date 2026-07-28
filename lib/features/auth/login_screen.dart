import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:quickalert/quickalert.dart';

import '../../core/connectivity/connectivity_provider.dart';
import '../../core/error/app_logger.dart';
import '../../core/error/user_facing_error.dart';
import '../../core/theme/app_theme.dart';
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
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _signInSectionExpanded = false;

  @override
  void dispose() {
    debugPrint('LoginScreen.dispose: disposing controllers');
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  /// Primary path for this app: skip auth entirely and open the catalog
  /// using whatever was last downloaded to this device. If nothing has ever
  /// been synced, there's nothing to show offline, so send the user to the
  /// sign-in section instead.
  Future<void> _continueOffline() async {
    debugPrint('LoginScreen._continueOffline: checking for cached catalog data');
    final hasData = await ref.read(productRepositoryProvider).hasCachedCatalog();
    debugPrint('LoginScreen._continueOffline: hasCachedCatalog returned hasData=$hasData');
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
    debugPrint('LoginScreen._login: form submitted, username=${_emailController.text.trim()}');
    if (!_formKey.currentState!.validate()) return;

    debugPrint('LoginScreen._login: calling authController.signIn');
    await ref.read(authControllerProvider.notifier).signIn(
          _emailController.text.trim(),
          _passwordController.text.trim(),
        );
    if (!mounted) return;

    final authState = ref.read(authControllerProvider);
    if (authState.hasError) {
      debugPrint('LoginScreen._login: signIn failed error=${authState.error}');
      final message = UserFacingError.describe(authState.error!);
      QuickAlert.show(context: context, type: QuickAlertType.error, title: 'Sign-in error', text: message);
      return;
    }
    debugPrint('LoginScreen._login: signIn succeeded');

    // Reuse the same sync path as the in-catalog sync button, so the very
    // first sign-in also downloads the catalog for later offline use.
    try {
      debugPrint('LoginScreen._login: calling catalogController.sync');
      await ref.read(catalogControllerProvider.notifier).sync();
      debugPrint('LoginScreen._login: catalog sync succeeded');
      if (!mounted) return;
      await QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'Synced',
        text: 'Data synced successfully.',
      );
    } catch (error, stackTrace) {
      debugPrint('LoginScreen._login: post-signin sync failed error=$error');
      AppLogger.error('Login', 'post-signin sync failed', error: error, stackTrace: stackTrace);
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

  /// Only works for a real email — Firebase can only send a reset link to an
  /// actual inbox. An MR without a real email on file (logging in via
  /// username) has no inbox behind their synthetic account email, so that
  /// case is directed to the admin instead (see Manage Employees > Reset
  /// Password).
  Future<void> _forgotPassword() async {
    debugPrint('LoginScreen._forgotPassword: opening forgot-password dialog');
    final controller = TextEditingController(text: _emailController.text.trim());
    final input = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Forgot password?'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Email or Username'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text.trim()), child: const Text('Send')),
        ],
      ),
    );
    if (input == null || input.isEmpty || !mounted) return;

    if (!input.contains('@')) {
      QuickAlert.show(
        context: context,
        type: QuickAlertType.info,
        title: 'Contact your admin',
        text: 'Accounts that sign in with a username (not an email) can only have their password reset by the '
            'admin — ask them to reset it from Manage Employees.',
      );
      return;
    }

    try {
      debugPrint('LoginScreen._forgotPassword: calling authController.sendPasswordResetEmail');
      await ref.read(authControllerProvider.notifier).sendPasswordResetEmail(input);
      debugPrint('LoginScreen._forgotPassword: sendPasswordResetEmail succeeded');
      if (!mounted) return;
      QuickAlert.show(
        context: context,
        type: QuickAlertType.success,
        title: 'Check your email',
        text: 'If $input is registered, a password reset link has been sent to it.',
      );
    } catch (error, stackTrace) {
      debugPrint('LoginScreen._forgotPassword: sendPasswordResetEmail failed error=$error');
      if (!mounted) return;
      // Don't reveal whether the email is registered (enumeration risk) —
      // show the same generic success message for "not found" as for a
      // genuine success, and only surface real problems (bad format,
      // network, rate limit).
      if (error is FirebaseAuthException && error.code == 'user-not-found') {
        QuickAlert.show(
          context: context,
          type: QuickAlertType.success,
          title: 'Check your email',
          text: 'If $input is registered, a password reset link has been sent to it.',
        );
        return;
      }
      AppLogger.error('Login', 'sendPasswordResetEmail failed', error: error, stackTrace: stackTrace);
      QuickAlert.show(
        context: context,
        type: QuickAlertType.error,
        title: 'Could not send reset email',
        text: UserFacingError.describe(error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final connectivity = ref.watch(connectivityProvider);
    final isSigningIn = ref.watch(authControllerProvider).isLoading;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            children: <Widget>[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(24, 64, 24, 40),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [scheme.primaryContainer, Theme.of(context).scaffoldBackgroundColor],
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                    bottomRight: Radius.circular(32),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                      child: Image.asset('assets/blogo.png', height: 56, width: 56),
                    ),
                    const SizedBox(height: 16),
                    connectivity.when(
                      loading: () => const SizedBox.shrink(),
                      error: (error, _) => const SizedBox.shrink(),
                      data: (results) {
                        final offline = NetworkStatus.isOffline(results);
                        final statusColor = offline ? AppTheme.warning : AppTheme.success;
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            NetworkStatus.describe(results),
                            style: TextStyle(color: statusColor, fontSize: 13, fontWeight: FontWeight.w600),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 20),
                    Text('Offline Mode', style: Theme.of(context).textTheme.headlineSmall),
                    const SizedBox(height: 8),
                    Text(
                      'This app works fully offline using the last data you synced.',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _continueOffline,
                      child: const Text('Continue Offline'),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
                child: Column(
                  children: [
                    if (!_signInSectionExpanded)
                      TextButton(
                        onPressed: () => setState(() => _signInSectionExpanded = true),
                        child: const Text('Sign in to download / sync data'),
                      )
                    else
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Text('Sign in to sync data', style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 16),
                            TextFormField(
                              controller: _emailController,
                              decoration: const InputDecoration(
                                labelText: 'Email or Username',
                                helperText: 'Admin: your email. Medical Reps: the username your admin gave you.',
                              ),
                              validator: Validators.loginIdentifier,
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _passwordController,
                              decoration: const InputDecoration(labelText: 'Password'),
                              obscureText: true,
                              validator: Validators.password,
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: _forgotPassword,
                                child: const Text('Forgot password?'),
                              ),
                            ),
                            const SizedBox(height: 4),
                            Center(
                              child: ElevatedButton(
                                onPressed: isSigningIn ? null : _login,
                                child: isSigningIn
                                    ? const SizedBox(
                                        height: 16,
                                        width: 16,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Sign In & Sync'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 24),
                    Wrap(
                      alignment: WrapAlignment.center,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text('By continuing, you agree to our', style: TextStyle(fontSize: 12)),
                        TextButton(
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                          onPressed: () => context.push('/legal/terms'),
                          child: const Text(
                            'Terms & Conditions',
                            style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                          ),
                        ),
                        const Text('and', style: TextStyle(fontSize: 12)),
                        TextButton(
                          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 4)),
                          onPressed: () => context.push('/legal/privacy'),
                          child: const Text(
                            'Privacy Policy',
                            style: TextStyle(fontSize: 12, decoration: TextDecoration.underline),
                          ),
                        ),
                        const Text('.', style: TextStyle(fontSize: 12)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
