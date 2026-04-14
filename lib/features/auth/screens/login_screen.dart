import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:tadabbur/core/providers/app_providers.dart';
import 'package:tadabbur/core/services/local_storage_service.dart';
import 'package:tadabbur/core/theme/app_colors.dart';


class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Spacer(flex: 2),

              // Logo / Title
              Text(
                'تدبر',
                style: TextStyle(
                  fontFamily: 'AmiriQuran',
                  fontSize: 56,
                  color: theme.colorScheme.primary,
                  height: 1.4,
                ),
              ).animate().fadeIn(duration: 800.ms),

              const SizedBox(height: 8),

              Text(
                'TADABBUR',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 6,
                  color: theme.colorScheme.primary,
                ),
              ).animate().fadeIn(duration: 800.ms, delay: 200.ms),

              const SizedBox(height: 12),

              Text(
                'One Ayah. Every Day. For Life.',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  fontStyle: FontStyle.italic,
                ),
              ).animate().fadeIn(duration: 800.ms, delay: 400.ms),

              const Spacer(flex: 2),

              // Login with Quran.com
              SizedBox(
                width: double.infinity,
                height: 56,
                child: FilledButton.icon(
                  onPressed: _isLoading ? null : _loginWithQuranFoundation,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.login_rounded),
                  label: Text(
                    _isLoading
                        ? 'Connecting...'
                        : 'Continue with Quran.com',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 600.ms).slideY(
                    begin: 0.1,
                    end: 0,
                    duration: 500.ms,
                    delay: 600.ms,
                  ),

              const SizedBox(height: 16),

              // Continue as guest
              SizedBox(
                width: double.infinity,
                height: 56,
                child: OutlinedButton(
                  onPressed: _continueAsGuest,
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(
                      color: theme.colorScheme.primary.withValues(alpha: 0.2),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Continue as Guest',
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface
                          .withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 700.ms),

              const SizedBox(height: 16),

              Text(
                'Sign in to sync across devices\nand save your journal securely',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.35),
                  height: 1.5,
                ),
              ).animate().fadeIn(duration: 500.ms, delay: 800.ms),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _loginWithQuranFoundation() async {
    debugPrint('[Button] LoginScreen: Continue with Quran.com tapped');
    setState(() => _isLoading = true);

    try {
      // Launch real QF OAuth2 PKCE flow
      final qfAuth = ref.read(qfAuthServiceProvider);
      await qfAuth.launchLogin();

      ref.read(isLoggedInProvider.notifier).state = true;
      if (mounted) context.go('/home');
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Login failed: $e'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _continueAsGuest() {
    final storage = ref.read(localStorageProvider);
    storage.setAuthToken('guest');
    storage.setUserId('guest');
    storage.setAuthType(AuthType.guest);
    ref.read(isLoggedInProvider.notifier).state = true;
    context.go('/home');
  }
}
