import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../main.dart';
import '../providers/theme_provider.dart';
import '../services/auth_service.dart';
import 'login_screen.dart';

// ═══════════════════════════════════════════════════════════════════════════════
// ── Avatar Data ──
// ═══════════════════════════════════════════════════════════════════════════════

class AvatarData {
  final String emoji;
  final Color bgColor;
  final String label;

  const AvatarData(this.emoji, this.bgColor, this.label);
}

const List<AvatarData> kAvatars = [
  AvatarData('👤', Color(0xFF78909C), 'Default'),
  AvatarData('🧑‍🚀', Color(0xFF1E3A5F), 'Astronaut'),
  AvatarData('🐻', Color(0xFF8D6E63), 'Bear'),
  AvatarData('🐱', Color(0xFF42A5F5), 'Cat'),
  AvatarData('🐤', Color(0xFF66BB6A), 'Duck'),
  AvatarData('🦊', Color(0xFFFF7043), 'Fox'),
  AvatarData('🐔', Color(0xFF8D6E63), 'Chicken'),
  AvatarData('👦', Color(0xFFFFB74D), 'Boy'),
  AvatarData('👨', Color(0xFFFFCC80), 'Man'),
  AvatarData('🤖', Color(0xFFEF5350), 'Robot'),
  AvatarData('🐼', Color(0xFFFDD835), 'Panda'),
  AvatarData('👩', Color(0xFFEC407A), 'Woman'),
  AvatarData('🦸', Color(0xFF7E57C2), 'Hero'),
  AvatarData('🎓', Color(0xFF26A69A), 'Graduate'),
];

// ═══════════════════════════════════════════════════════════════════════════════
// ── Onboarding Screen ──
// ═══════════════════════════════════════════════════════════════════════════════

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  int _selectedAvatar = 4; // Duck selected by default (matching reference)

  late final AnimationController _fadeController;
  late final Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _fadeController,
      curve: Curves.easeOut,
    );
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _nextPage() {
    if (_currentPage < 2) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOutCubic,
      );
    }
  }

  Future<void> _finish() async {
    final authService = AuthService();
    await authService.saveAvatar(_selectedAvatar);
    await authService.completeOnboarding();
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = context.watch<ThemeProvider>();
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: isDark
                ? [AppColors.darkBg, AppColors.darkSurface]
                : [AppColors.lightBg, const Color(0xFFEEF2F7)],
          ),
        ),
        child: SafeArea(
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: Column(
              children: [
                // ── Top Bar (theme toggle) ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () =>
                            themeProvider.toggleTheme(!themeProvider.isDarkMode),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isDark
                                ? Colors.white.withValues(alpha: 0.08)
                                : Colors.black.withValues(alpha: 0.05),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.12)
                                  : Colors.black.withValues(alpha: 0.08),
                            ),
                          ),
                          child: Icon(
                            isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                            size: 22,
                            color: isDark
                                ? const Color(0xFFFFD54F)
                                : const Color(0xFFFF9800),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Page View ──
                Expanded(
                  child: PageView(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() => _currentPage = index);
                    },
                    children: [
                      _WelcomePage(isDark: isDark, theme: theme),
                      _AttendancePage(isDark: isDark, theme: theme),
                      _AvatarSelectionPage(
                        isDark: isDark,
                        theme: theme,
                        selectedAvatar: _selectedAvatar,
                        onAvatarSelected: (index) {
                          setState(() => _selectedAvatar = index);
                        },
                      ),
                    ],
                  ),
                ),

                // ── Page Indicator ──
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(3, (index) {
                      final isActive = index == _currentPage;
                      return AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: isActive ? 28 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: isActive
                              ? AppColors.primary
                              : isDark
                                  ? Colors.white.withValues(alpha: 0.2)
                                  : Colors.black.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
                ),

                // ── Action Button ──
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 48, vertical: 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: _currentPage < 2
                          ? _OnboardingButton(
                              key: const ValueKey('next'),
                              label: 'Next',
                              onTap: _nextPage,
                              isDark: isDark,
                            )
                          : _OnboardingButton(
                              key: const ValueKey('save'),
                              label: 'Save',
                              onTap: _finish,
                              isDark: isDark,
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Onboarding Button ──
// ═══════════════════════════════════════════════════════════════════════════════

class _OnboardingButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool isDark;

  const _OnboardingButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.primary.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primary.withValues(alpha: 0.15),
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Page 1: Welcome  ──
// ═══════════════════════════════════════════════════════════════════════════════

class _WelcomePage extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _WelcomePage({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          // Illustration
          SizedBox(
            height: 260,
            width: 260,
            child: CustomPaint(
              painter: _WelcomeIllustrationPainter(isDark: isDark),
            ),
          ),
          const Spacer(),
          // Title
          Text(
            'Welcome',
            style: GoogleFonts.outfit(
              fontSize: 30,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          // Description
          Text(
            'Manage your Smart attendance and track\nstudent records — all with one simple login.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Page 2: Effortless Attendance ──
// ═══════════════════════════════════════════════════════════════════════════════

class _AttendancePage extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;

  const _AttendancePage({required this.isDark, required this.theme});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Spacer(flex: 2),
          // Illustration
          SizedBox(
            height: 260,
            width: 260,
            child: CustomPaint(
              painter: _AttendanceIllustrationPainter(isDark: isDark),
            ),
          ),
          const Spacer(),
          // Title
          Text(
            'Effortless Attendance',
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.w800,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 16),
          // Description
          Text(
            'Scan NFC tags, import student data, and\nexport attendance reports all in one place.\nStay organized effortlessly.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Page 3: Avatar Selection ──
// ═══════════════════════════════════════════════════════════════════════════════

class _AvatarSelectionPage extends StatelessWidget {
  final bool isDark;
  final ThemeData theme;
  final int selectedAvatar;
  final ValueChanged<int> onAvatarSelected;

  const _AvatarSelectionPage({
    required this.isDark,
    required this.theme,
    required this.selectedAvatar,
    required this.onAvatarSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          const SizedBox(height: 8),
          // Title
          Text(
            'Select an Avatar',
            style: GoogleFonts.outfit(
              fontSize: 26,
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Choose a profile picture that represents you.\nYou can change it anytime from your profile settings.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Large preview
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) => ScaleTransition(
              scale: animation,
              child: child,
            ),
            child: Container(
              key: ValueKey(selectedAvatar),
              width: 96,
              height: 96,
              decoration: BoxDecoration(
                color: kAvatars[selectedAvatar].bgColor,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: kAvatars[selectedAvatar]
                        .bgColor
                        .withValues(alpha: 0.4),
                    blurRadius: 20,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Text(
                  kAvatars[selectedAvatar].emoji,
                  style: const TextStyle(fontSize: 48),
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Avatar grid
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              physics: const BouncingScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 4,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1,
              ),
              itemCount: kAvatars.length,
              itemBuilder: (context, index) {
                final avatar = kAvatars[index];
                final isSelected = index == selectedAvatar;
                return GestureDetector(
                  onTap: () => onAvatarSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    curve: Curves.easeOutCubic,
                    decoration: BoxDecoration(
                      color: avatar.bgColor,
                      shape: BoxShape.circle,
                      border: isSelected
                          ? Border.all(
                              color: AppColors.primary,
                              width: 3,
                            )
                          : Border.all(
                              color: isDark
                                  ? Colors.white.withValues(alpha: 0.1)
                                  : Colors.black.withValues(alpha: 0.06),
                              width: 2,
                            ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color:
                                    AppColors.primary.withValues(alpha: 0.35),
                                blurRadius: 12,
                                spreadRadius: 1,
                              ),
                            ]
                          : [],
                    ),
                    child: Center(
                      child: Text(
                        avatar.emoji,
                        style: const TextStyle(fontSize: 30),
                      ),
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
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Welcome Illustration (CustomPainter) ──
// ═══════════════════════════════════════════════════════════════════════════════

class _WelcomeIllustrationPainter extends CustomPainter {
  final bool isDark;
  _WelcomeIllustrationPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Ground line
    final groundPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.08)
          : Colors.black.withValues(alpha: 0.06)
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    canvas.drawLine(
      Offset(cx - 100, cy + 80),
      Offset(cx + 100, cy + 80),
      groundPaint,
    );

    // Small grass marks
    final grassPaint = Paint()
      ..color = isDark
          ? const Color(0xFF4CAF50).withValues(alpha: 0.3)
          : const Color(0xFF4CAF50).withValues(alpha: 0.4)
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final xOff in [-70.0, -40.0, 50.0, 80.0]) {
      canvas.drawLine(
        Offset(cx + xOff, cy + 80),
        Offset(cx + xOff - 3, cy + 70),
        grassPaint,
      );
      canvas.drawLine(
        Offset(cx + xOff, cy + 80),
        Offset(cx + xOff + 3, cy + 72),
        grassPaint,
      );
    }

    // Mountain/destination in background
    final mountainPath = Path()
      ..moveTo(cx + 30, cy - 50)
      ..lineTo(cx + 80, cy + 20)
      ..lineTo(cx - 20, cy + 20)
      ..close();
    canvas.drawPath(
      mountainPath,
      Paint()..color = AppColors.primary.withValues(alpha: 0.25),
    );
    // Snow cap
    final snowPath = Path()
      ..moveTo(cx + 30, cy - 50)
      ..lineTo(cx + 45, cy - 25)
      ..lineTo(cx + 15, cy - 25)
      ..close();
    canvas.drawPath(
      snowPath,
      Paint()..color = AppColors.cyan.withValues(alpha: 0.4),
    );

    // Second smaller mountain
    final mt2 = Path()
      ..moveTo(cx + 70, cy - 20)
      ..lineTo(cx + 110, cy + 20)
      ..lineTo(cx + 30, cy + 20)
      ..close();
    canvas.drawPath(
      mt2,
      Paint()..color = AppColors.secondary.withValues(alpha: 0.2),
    );

    // Winding path from person to mountain
    final pathPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.15)
          : Colors.black.withValues(alpha: 0.1)
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    final windingPath = Path()
      ..moveTo(cx - 30, cy + 60)
      ..cubicTo(cx - 10, cy + 30, cx + 20, cy + 40, cx + 10, cy + 10)
      ..cubicTo(cx, cy - 10, cx + 40, cy - 5, cx + 30, cy - 30);
    canvas.drawPath(windingPath, pathPaint);

    // Dots along the path
    final dotPaint = Paint()..color = AppColors.primary.withValues(alpha: 0.5);
    canvas.drawCircle(Offset(cx - 30, cy + 60), 4, dotPaint);
    canvas.drawCircle(Offset(cx - 25, cy + 62), 2, dotPaint);

    // Pin/marker at start
    final pinPaint = Paint()..color = AppColors.cyan;
    canvas.drawCircle(Offset(cx - 30, cy + 48), 6, pinPaint);
    canvas.drawLine(
      Offset(cx - 30, cy + 54),
      Offset(cx - 30, cy + 65),
      Paint()
        ..color = AppColors.cyan
        ..strokeWidth = 2.5,
    );

    // Person (walking with backpack)
    final personX = cx - 55.0;
    final personY = cy + 30.0;

    // Body
    canvas.drawLine(
      Offset(personX, personY),
      Offset(personX, personY + 30),
      Paint()
        ..color = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1A1A2E)
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );

    // Head
    canvas.drawCircle(
      Offset(personX, personY - 8),
      10,
      Paint()
        ..color = const Color(0xFFFFCC80),
    );
    // Hair
    canvas.drawArc(
      Rect.fromCircle(center: Offset(personX, personY - 11), radius: 10),
      3.14,
      3.14,
      true,
      Paint()..color = const Color(0xFF3E2723),
    );

    // Backpack
    final bpRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(personX + 3, personY - 2, 12, 18),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      bpRect,
      Paint()..color = AppColors.primary.withValues(alpha: 0.8),
    );

    // Legs (walking pose)
    final legPaint = Paint()
      ..color = isDark ? Colors.white.withValues(alpha: 0.85) : const Color(0xFF1A1A2E)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(personX, personY + 30),
      Offset(personX - 8, personY + 48),
      legPaint,
    );
    canvas.drawLine(
      Offset(personX, personY + 30),
      Offset(personX + 10, personY + 48),
      legPaint,
    );

    // Arms
    canvas.drawLine(
      Offset(personX, personY + 5),
      Offset(personX - 12, personY + 20),
      legPaint,
    );

    // Little birds in sky
    final birdPaint = Paint()
      ..color = isDark
          ? Colors.white.withValues(alpha: 0.3)
          : Colors.black.withValues(alpha: 0.2)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    _drawBird(canvas, Offset(cx + 50, cy - 70), birdPaint);
    _drawBird(canvas, Offset(cx + 65, cy - 60), birdPaint);
    _drawBird(canvas, Offset(cx + 40, cy - 55), birdPaint);

    // Small boat silhouette midway
    final boatX = cx + 5.0;
    final boatY = cy + 25.0;
    final boatPath = Path()
      ..moveTo(boatX - 12, boatY)
      ..quadraticBezierTo(boatX, boatY + 8, boatX + 12, boatY);
    canvas.drawPath(
      boatPath,
      Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF1A1A2E).withValues(alpha: 0.6)
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
    // Boat mast
    canvas.drawLine(
      Offset(boatX, boatY),
      Offset(boatX, boatY - 14),
      Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.5)
            : const Color(0xFF1A1A2E).withValues(alpha: 0.6)
        ..strokeWidth = 1.5,
    );
    // Sail
    final sailPath = Path()
      ..moveTo(boatX, boatY - 14)
      ..lineTo(boatX + 10, boatY - 4)
      ..lineTo(boatX, boatY - 2)
      ..close();
    canvas.drawPath(
      sailPath,
      Paint()..color = AppColors.primary.withValues(alpha: 0.35),
    );
  }

  void _drawBird(Canvas canvas, Offset pos, Paint paint) {
    canvas.drawLine(
      Offset(pos.dx - 5, pos.dy + 3),
      pos,
      paint,
    );
    canvas.drawLine(
      pos,
      Offset(pos.dx + 5, pos.dy + 3),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Attendance Illustration (CustomPainter) ──
// ═══════════════════════════════════════════════════════════════════════════════

class _AttendanceIllustrationPainter extends CustomPainter {
  final bool isDark;
  _AttendanceIllustrationPainter({required this.isDark});

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Stack of books
    final bookBaseY = cy + 40.0;
    final bookColors = [
      AppColors.primary.withValues(alpha: 0.6),
      AppColors.cyan.withValues(alpha: 0.5),
      AppColors.secondary.withValues(alpha: 0.5),
    ];

    for (int i = 0; i < 3; i++) {
      final y = bookBaseY - i * 14.0;
      final bookRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(cx - 70, y, 140, 12),
        const Radius.circular(3),
      );
      canvas.drawRRect(bookRect, Paint()..color = bookColors[i]);
      // Book spine lines
      canvas.drawLine(
        Offset(cx + 65, y + 2),
        Offset(cx + 65, y + 10),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.3)
          ..strokeWidth = 1,
      );
    }

    // Open book on top (pages)
    final openBookY = bookBaseY - 48.0;
    // Left page
    final leftPage = Path()
      ..moveTo(cx, openBookY + 8)
      ..quadraticBezierTo(cx - 40, openBookY, cx - 55, openBookY + 5)
      ..lineTo(cx - 55, openBookY + 35)
      ..quadraticBezierTo(cx - 40, openBookY + 30, cx, openBookY + 38)
      ..close();
    canvas.drawPath(
      leftPage,
      Paint()..color = isDark ? const Color(0xFFE8EAF0) : Colors.white,
    );
    canvas.drawPath(
      leftPage,
      Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Right page
    final rightPage = Path()
      ..moveTo(cx, openBookY + 8)
      ..quadraticBezierTo(cx + 40, openBookY, cx + 55, openBookY + 5)
      ..lineTo(cx + 55, openBookY + 35)
      ..quadraticBezierTo(cx + 40, openBookY + 30, cx, openBookY + 38)
      ..close();
    canvas.drawPath(
      rightPage,
      Paint()..color = isDark ? const Color(0xFFE0E3E9) : const Color(0xFFF5F5F5),
    );
    canvas.drawPath(
      rightPage,
      Paint()
        ..color = isDark
            ? Colors.white.withValues(alpha: 0.2)
            : Colors.black.withValues(alpha: 0.08)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );

    // Lines on pages
    final linePaint = Paint()
      ..color = isDark
          ? Colors.grey.withValues(alpha: 0.3)
          : Colors.grey.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    for (int i = 0; i < 4; i++) {
      final y = openBookY + 14 + i * 6.0;
      canvas.drawLine(Offset(cx - 45, y), Offset(cx - 12, y), linePaint);
      canvas.drawLine(Offset(cx + 12, y), Offset(cx + 45, y), linePaint);
    }

    // Person standing on books
    final personX = cx - 15.0;
    final personY = bookBaseY - 52.0;

    // Legs
    final legPaint = Paint()
      ..color = isDark ? const Color(0xFF263238) : const Color(0xFF1A1A2E)
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(personX, personY),
      Offset(personX - 6, personY + 22),
      legPaint,
    );
    canvas.drawLine(
      Offset(personX, personY),
      Offset(personX + 8, personY + 22),
      legPaint,
    );

    // Body/torso
    canvas.drawLine(
      Offset(personX, personY),
      Offset(personX, personY - 28),
      Paint()
        ..color = const Color(0xFFBDBDBD)
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round,
    );

    // Shirt
    final shirtRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(personX - 10, personY - 28, 20, 16),
      const Radius.circular(4),
    );
    canvas.drawRRect(
      shirtRect,
      Paint()..color = const Color(0xFFBDBDBD),
    );

    // Head
    canvas.drawCircle(
      Offset(personX, personY - 38),
      10,
      Paint()..color = const Color(0xFFFFCC80),
    );
    // Hair
    canvas.drawArc(
      Rect.fromCircle(center: Offset(personX, personY - 41), radius: 10),
      3.14,
      3.14,
      true,
      Paint()..color = const Color(0xFF1A1A2E),
    );

    // Arms (one up holding graduation cap)
    final armPaint = Paint()
      ..color = const Color(0xFFBDBDBD)
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    // Left arm up
    canvas.drawLine(
      Offset(personX - 8, personY - 22),
      Offset(personX - 25, personY - 50),
      armPaint,
    );
    // Right arm out
    canvas.drawLine(
      Offset(personX + 8, personY - 22),
      Offset(personX + 18, personY - 14),
      armPaint,
    );

    // Graduation cap
    final capX = personX - 30.0;
    final capY = personY - 60.0;

    // Cap board (square top)
    final capBoard = Path()
      ..moveTo(capX - 18, capY + 5)
      ..lineTo(capX, capY - 5)
      ..lineTo(capX + 18, capY + 5)
      ..lineTo(capX, capY + 10)
      ..close();
    canvas.drawPath(
      capBoard,
      Paint()..color = AppColors.primary,
    );
    // Cap base
    canvas.drawLine(
      Offset(capX - 8, capY + 8),
      Offset(capX + 8, capY + 8),
      Paint()
        ..color = AppColors.secondary
        ..strokeWidth = 5
        ..strokeCap = StrokeCap.round,
    );
    // Tassel
    canvas.drawLine(
      Offset(capX + 14, capY + 5),
      Offset(capX + 20, capY + 18),
      Paint()
        ..color = AppColors.gold
        ..strokeWidth = 1.5,
    );
    canvas.drawCircle(
      Offset(capX + 20, capY + 20),
      2.5,
      Paint()..color = AppColors.gold,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════════════════════════════════════
// ── Avatar Picker Dialog (reusable for Settings) ──
// ═══════════════════════════════════════════════════════════════════════════════

class AvatarPickerDialog extends StatefulWidget {
  final int currentAvatar;

  const AvatarPickerDialog({super.key, required this.currentAvatar});

  @override
  State<AvatarPickerDialog> createState() => _AvatarPickerDialogState();
}

class _AvatarPickerDialogState extends State<AvatarPickerDialog> {
  late int _selected;

  @override
  void initState() {
    super.initState();
    _selected = widget.currentAvatar;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.darkCard : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      insetPadding: const EdgeInsets.all(24),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Change Avatar',
              style: GoogleFonts.outfit(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 20),
            // Preview
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: Container(
                key: ValueKey(_selected),
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: kAvatars[_selected].bgColor,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: kAvatars[_selected]
                          .bgColor
                          .withValues(alpha: 0.4),
                      blurRadius: 16,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    kAvatars[_selected].emoji,
                    style: const TextStyle(fontSize: 36),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            // Grid
            SizedBox(
              height: 280,
              child: GridView.builder(
                physics: const BouncingScrollPhysics(),
                gridDelegate:
                    const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                ),
                itemCount: kAvatars.length,
                itemBuilder: (context, index) {
                  final avatar = kAvatars[index];
                  final isSelected = index == _selected;
                  return GestureDetector(
                    onTap: () => setState(() => _selected = index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      decoration: BoxDecoration(
                        color: avatar.bgColor,
                        shape: BoxShape.circle,
                        border: isSelected
                            ? Border.all(color: AppColors.primary, width: 3)
                            : Border.all(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.1)
                                    : Colors.black.withValues(alpha: 0.06),
                                width: 2,
                              ),
                        boxShadow: isSelected
                            ? [
                                BoxShadow(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.3),
                                  blurRadius: 10,
                                ),
                              ]
                            : [],
                      ),
                      child: Center(
                        child: Text(
                          avatar.emoji,
                          style: const TextStyle(fontSize: 26),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context, _selected),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: Text(
                  'Save',
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
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
