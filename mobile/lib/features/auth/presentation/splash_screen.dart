import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sayurpintar/app/theme.dart';
import 'package:sayurpintar/features/auth/providers/auth_provider.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _fadeAnimation;
  late final Animation<double> _scaleAnimation;
  late final Animation<double> _subtitleFade;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.5, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.6, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0, 0.6, curve: Curves.elasticOut),
      ),
    );

    _subtitleFade = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.4, 0.8, curve: Curves.easeIn),
      ),
    );

    _controller.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for auth state changes after initial delay
    _navigateAfterDelay();
  }

  Future<void> _navigateAfterDelay() async {
    await Future.delayed(const Duration(seconds: 2));
    if (!mounted || _navigated) return;

    final authState = ref.read(authProvider);

    // If auth is still initializing, wait for it
    if (authState.status == AuthStatus.initial ||
        authState.status == AuthStatus.loading) {
      // Use ref.listen properly
      final sub = ref.listenManual<AuthState>(authProvider, (prev, next) {
        if (_navigated) return;
        if (next.isAuthenticated) {
          _navigate('/home');
        } else if (next.needsRole) {
          _navigate('/role-selection');
        } else if (next.isUnauthenticated) {
          _navigate('/login');
        }
      });
      // Auto-cleanup after 5 seconds
      Future.delayed(const Duration(seconds: 5), () => sub.close());
    } else if (authState.isAuthenticated) {
      _navigate('/home');
    } else if (authState.needsRole) {
      _navigate('/role-selection');
    } else {
      _navigate('/login');
    }
  }

  void _navigate(String path) {
    if (_navigated || !mounted) return;
    _navigated = true;
    context.go(path);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.primaryGreen,
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [AppTheme.primaryDark, AppTheme.primaryGreen],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Center(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Logo ─────────────────────
                  Container(
                    width: 110,
                    height: 110,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius:
                          BorderRadius.circular(AppTheme.radiusXL),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 24,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        '🥬',
                        style: TextStyle(fontSize: 56),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space24),

                  // ── App name ─────────────────
                  const Text(
                    'SayurPintar',
                    style: TextStyle(
                      fontSize: 34,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      fontFamily: 'Nunito',
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: AppTheme.space8),

                  // ── Subtitle ─────────────────
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: const Text(
                      'Jualan sayur jadi lebih mudah',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white70,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ),
                  const SizedBox(height: AppTheme.space48),

                  // ── Loading indicator ────────
                  FadeTransition(
                    opacity: _subtitleFade,
                    child: const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
