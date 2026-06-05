import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../services/auth_service.dart';
import 'dashboard_screen.dart';
import 'login_screen.dart';
import 'onboarding_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _quoteFadeAnimation;
  
  final String _title = "ATTENDEXA";
  final List<String> _quotes = [
    "Precision in Presence, Excellence in Education.",
    "Every Second Counts, Every Presence Matters.",
    "Tracking Success, One Attendance at a Time.",
    "Empowering Education through Attendance.",
    "Seamless Attendance, Limitless Learning.",
  ];
  late String _selectedQuote;
  AuthState? _nextState;

  @override
  void initState() {
    super.initState();
    _selectedQuote = _quotes[Random().nextInt(_quotes.length)];
    
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );

    _quoteFadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.6, 1.0, curve: Curves.easeIn),
    );

    _controller.forward();

    // Start auth check in background
    _checkAuth();

    // Navigate after 3 seconds
    Timer(const Duration(milliseconds: 3200), () {
      _navigateToNext();
    });
  }

  Future<void> _checkAuth() async {
    final authService = AuthService();
    _nextState = await authService.checkStartupState();
  }

  void _navigateToNext() {
    if (!mounted || _nextState == null) {
      // If auth check isn't done, wait a bit more (unlikely)
      Future.delayed(const Duration(milliseconds: 200), _navigateToNext);
      return;
    }

    Widget nextScreen;
    if (_nextState == AuthState.authenticated) {
      nextScreen = const DashboardScreen();
    } else if (_nextState == AuthState.firstTime) {
      nextScreen = const OnboardingScreen();
    } else {
      nextScreen = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => nextScreen,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 800),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkBg,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center,
            radius: 1.2,
            colors: [
              Color(0xFF1E293B), // Slate 800
              AppColors.darkBg,
            ],
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            
            // Letter by letter animation
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                return Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(_title.length, (index) {
                    // Each letter appears at a specific interval
                    double start = index * (0.5 / _title.length);
                    double end = start + 0.1;
                    
                    double opacity = Curves.easeIn.transform(
                      ((_controller.value - start) / (end - start)).clamp(0.0, 1.0),
                    );

                    return Opacity(
                      opacity: opacity,
                      child: Transform.translate(
                        offset: Offset(0, 10 * (1 - opacity)),
                        child: Text(
                          _title[index],
                          style: GoogleFonts.outfit(
                            fontSize: 42,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 8,
                            color: Colors.white,
                            shadows: [
                              Shadow(
                                color: AppColors.primary.withValues(alpha: 0.5),
                                blurRadius: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }),
                );
              },
            ),
            
            const SizedBox(height: 24),
            
            // Quote fade in
            FadeTransition(
              opacity: _quoteFadeAnimation,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Text(
                  _selectedQuote,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    fontStyle: FontStyle.italic,
                    color: Colors.white.withValues(alpha: 0.7),
                    letterSpacing: 0.5,
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
