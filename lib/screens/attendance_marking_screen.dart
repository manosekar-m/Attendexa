import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../main.dart';
import '../services/nfc_service.dart';
import '../services/database_service.dart';
import 'package:intl/intl.dart';
import '../widgets/glass_card.dart';

class AttendanceMarkingScreen extends StatefulWidget {
  const AttendanceMarkingScreen({super.key});

  @override
  State<AttendanceMarkingScreen> createState() =>
      _AttendanceMarkingScreenState();
}

class _AttendanceMarkingScreenState extends State<AttendanceMarkingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _ring1Controller;
  late final AnimationController _ring2Controller;
  late final AnimationController _ring3Controller;
  late final AnimationController _pulseController;
  late final AnimationController _fadeController;
  
  final FlutterTts _flutterTts = FlutterTts();

  String _statusMessage = "Checking location...\nPlease wait.";
  bool _isError = false;
  bool _isSuccess = false;
  bool _isGeoChecking = true;   // true while location is being verified
  bool _isGeoBlocked = false;   // true if outside classroom boundary

  final _nfcTagController = TextEditingController();
  bool _isManualLoading = false;

  @override
  void initState() {
    super.initState();
    _initTts();

    _ring1Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat();

    _ring2Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 10),
    )..repeat(reverse: true);

    _ring3Controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
      value: 1.0,
    );

    // Geofence check first; NFC starts only if inside boundary
    _checkGeofenceAndStart();
  }

  // ── Geofence ──────────────────────────────────────────────────────────────
  Future<void> _checkGeofenceAndStart() async {
    final prefs = await SharedPreferences.getInstance();
    final geoEnabled = prefs.getBool('geo_enabled') ?? false;

    if (!geoEnabled) {
      // Geofencing not configured — skip check and start scanning
      if (mounted) setState(() => _isGeoChecking = false);
      _statusMessage = 'Ready to scan.\nPlease tap an NFC tag.';
      _startScanning();
      return;
    }

    final classLat = prefs.getDouble('geo_lat') ?? 0.0;
    final classLng = prefs.getDouble('geo_lng') ?? 0.0;
    final allowedRadius = prefs.getDouble('geo_radius') ?? 100.0;

    try {
      // 1. Check if location services are enabled on the device
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) {
          setState(() {
            _isGeoChecking = false;
            _isGeoBlocked = true;
            _isError = true;
            _statusMessage = 'Location services are disabled.\nPlease enable GPS/Location in system settings.';
          });
        }
        return;
      }

      // 2. Request and check permissions
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        if (mounted) {
          setState(() {
            _isGeoChecking = false;
            _isGeoBlocked = true;
            _isError = true;
            _statusMessage = 'Location permission denied.\nGeofencing requires location access.';
          });
        }
        return;
      }

      // 3. Retrieve current position with a timeout
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          timeLimit: Duration(seconds: 10),
        ),
      );

      // 4. Calculate distance to classroom location
      final distance = Geolocator.distanceBetween(
        position.latitude,
        position.longitude,
        classLat,
        classLng,
      );

      if (mounted) {
        if (distance <= allowedRadius) {
          setState(() {
            _isGeoChecking = false;
            _isGeoBlocked = false;
            _statusMessage = 'Ready to scan.\nPlease tap an NFC tag.';
          });
          _startScanning();
        } else {
          setState(() {
            _isGeoChecking = false;
            _isGeoBlocked = true;
            _isError = true;
            _statusMessage =
                'You are ${distance.toStringAsFixed(0)} m away.\nYou must be within ${allowedRadius.toInt()} m to mark attendance.';
          });
          _speak('You are outside the classroom boundary. Attendance cannot be marked.');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isGeoChecking = false;
          _isGeoBlocked = true;
          _isError = true;
          _statusMessage = 'Failed to verify location.\nPlease ensure you have a clear GPS signal and try again.';
        });
        _speak('Failed to verify location.');
      }
    }
  }

  Future<void> _initTts() async {
    await _flutterTts.setLanguage("en-US");
    await _flutterTts.setPitch(1.0);
    await _flutterTts.setSpeechRate(0.5);
  }

  Future<void> _speak(String text) async {
    await _flutterTts.speak(text);
  }

  void _startScanning() {
    final nfcService = context.read<NfcService>();
    nfcService.startNfcSession(
      onResult: (status, isError) {
        if (mounted) {
          _animateStatus(status, isError);
          _speak(status);
        }
      },
    );
  }

  void _animateStatus(String status, bool isError) {
    if (mounted) {
      _fadeController.reverse().then((_) {
        if (mounted) {
          setState(() {
            _statusMessage = status;
            _isError = isError;
            _isSuccess = !isError && (status.startsWith("Marked") || status.contains("already marked"));
          });
          _fadeController.forward();
        }
      });
    }
  }

  Future<void> _markManual() async {
    if (_isGeoBlocked) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: const Text('Cannot mark attendance — outside classroom boundary.'),
        backgroundColor: AppColors.rose,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ));
      return;
    }
    final nfcTagId = _nfcTagController.text.trim().toUpperCase();
    if (nfcTagId.isEmpty) return;

    setState(() => _isManualLoading = true);
    
    // Unfocus keyboard
    FocusScope.of(context).unfocus();

    final db = context.read<DatabaseService>();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    await Future.delayed(const Duration(milliseconds: 300)); // Premium feel

    try {
      final student = await db.getStudentByRfid(nfcTagId);
      if (student == null) {
        _animateStatus("NFC Tag ID $nfcTagId not found", true);
        _speak("NFC Tag ID not found");
      } else {
        final res = await db.markAttendance(student.rfid, today);
        if (res == -1) {
          _animateStatus("${student.name} is already marked", true);
          _speak("${student.name} is already marked");
        } else {
          _animateStatus("Marked Present: ${student.name}", false);
          _speak("Marked Present: ${student.name}");
          _nfcTagController.clear();
        }
      }
    } catch (e) {
      _animateStatus("Error verifying NFC Tag", true);
      _speak("Error verifying NFC Tag");
    } finally {
      if (mounted) {
        setState(() => _isManualLoading = false);
      }
    }
  }

  @override
  void dispose() {
    _ring1Controller.dispose();
    _ring2Controller.dispose();
    _ring3Controller.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    _nfcTagController.dispose();
    _flutterTts.stop();
    context.read<NfcService>().stopNfcSession();
    super.dispose();
  }

  Color get _accentColor {
    if (_isError) return AppColors.rose;
    if (_isSuccess) return AppColors.mint;
    return AppColors.primary;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: GlassCard(
            padding: const EdgeInsets.all(8),
            borderRadius: 12,
            child: Icon(Icons.arrow_back_rounded,
                size: 20, color: theme.colorScheme.onSurface),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Mark Attendance',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: const Alignment(0, -0.3),
            radius: 1.2,
            colors: [
              _accentColor.withValues(alpha: isDark ? 0.15 : 0.08),
              isDark ? AppColors.darkBg : AppColors.lightBg,
            ],
          ),
        ),
        child: SafeArea(
          child: _isGeoChecking
              ? _buildGeoLoadingState(theme)
              : _isGeoBlocked
                  ? _buildGeoBlockedState(theme)
                  : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // ── Multi-Layered Scanner Animation ──
                GestureDetector(
                  onTap: _markManual,
                  child: SizedBox(
                    width: 260,
                    height: 260,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        // Ring 3 — Outermost, dashed
                        AnimatedBuilder(
                          animation: _ring3Controller,
                          builder: (context, _) {
                            return Transform.rotate(
                              angle:
                                  -_ring3Controller.value * 2 * math.pi,
                              child: CustomPaint(
                                size: const Size(260, 260),
                                painter: _DashedRingPainter(
                                  color: _accentColor
                                      .withValues(alpha: 0.15),
                                  strokeWidth: 1.5,
                                  dashCount: 40,
                                  radius: 126,
                                ),
                              ),
                            );
                          },
                        ),

                        // Ring 2 — Middle, gradient arc
                        AnimatedBuilder(
                          animation: _ring2Controller,
                          builder: (context, _) {
                            return Transform.rotate(
                              angle:
                                  _ring2Controller.value * 2 * math.pi,
                              child: CustomPaint(
                                size: const Size(220, 220),
                                painter: _GradientArcPainter(
                                  color1: _accentColor,
                                  color2: AppColors.secondary,
                                  strokeWidth: 2.5,
                                  arcLength: math.pi * 0.8,
                                  radius: 106,
                                ),
                              ),
                            );
                          },
                        ),

                        // Ring 1 — Inner, solid with glow
                        AnimatedBuilder(
                          animation: _ring1Controller,
                          builder: (context, _) {
                            return Transform.rotate(
                              angle:
                                  _ring1Controller.value * 2 * math.pi,
                              child: CustomPaint(
                                size: const Size(190, 190),
                                painter: _GradientArcPainter(
                                  color1: _accentColor
                                      .withValues(alpha: 0.8),
                                  color2: _accentColor
                                      .withValues(alpha: 0.1),
                                  strokeWidth: 3,
                                  arcLength: math.pi * 1.2,
                                  radius: 90,
                                ),
                              ),
                            );
                          },
                        ),

                        // Center Pulse Glow
                        AnimatedBuilder(
                          animation: _pulseController,
                          builder: (context, _) {
                            final pulse = _pulseController.value;
                            return Container(
                              width: 140 + pulse * 10,
                              height: 140 + pulse * 10,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                boxShadow: [
                                  BoxShadow(
                                    color: _accentColor.withValues(
                                        alpha: 0.15 + pulse * 0.1),
                                    blurRadius: 40 + pulse * 20,
                                    spreadRadius: 5 + pulse * 10,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        // Center Circle with NFC Icon
                        ClipOval(
                          child: BackdropFilter(
                            filter:
                                ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 400),
                              width: 130,
                              height: 130,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _accentColor
                                    .withValues(alpha: isDark ? 0.12 : 0.08),
                                border: Border.all(
                                  color: _accentColor
                                      .withValues(alpha: 0.25),
                                  width: 1.5,
                                ),
                              ),
                              child: FaIcon(
                                FontAwesomeIcons.nfcSymbol,
                                size: 48,
                                color: _accentColor,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                // ── Status Text ──
                FadeTransition(
                  opacity: _fadeController,
                  child: Column(
                    children: [
                      AnimatedDefaultTextStyle(
                        duration: const Duration(milliseconds: 300),
                        style: (theme.textTheme.headlineSmall ?? const TextStyle())
                            .copyWith(
                          fontWeight: FontWeight.w700,
                          color: _isError
                              ? AppColors.rose
                              : _isSuccess
                                  ? AppColors.mint
                                  : theme.colorScheme.onSurface,
                        ),
                        child: Text(
                          _isError
                              ? 'Scan Error'
                              : _isSuccess
                                  ? 'Success!'
                                  : 'Scanning...',
                        ),
                      ),
                      const SizedBox(height: 16),
                      Padding(
                        padding:
                            const EdgeInsets.symmetric(horizontal: 48),
                        child: GlassCard(
                          borderRadius: 16,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 16),
                          borderColor: _isError
                              ? AppColors.rose.withValues(alpha: 0.2)
                              : _isSuccess
                                  ? AppColors.mint
                                      .withValues(alpha: 0.2)
                                  : null,
                          child: Text(
                            _statusMessage,
                            textAlign: TextAlign.center,
                            style:
                                theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface
                                  .withValues(alpha: 0.7),
                              height: 1.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 32),

                // ── Manual Entry ──
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: GlassCard(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    borderRadius: 16,
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _nfcTagController,
                            style: theme.textTheme.bodyLarge?.copyWith(
                              color: theme.colorScheme.onSurface,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Enter NFC Tag ID for verification...',
                              hintStyle: theme.textTheme.bodyMedium?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                              ),
                              border: InputBorder.none,
                              prefixIcon: Container(
                                padding: const EdgeInsets.all(10),
                                child: FaIcon(
                                  FontAwesomeIcons.keyboard,
                                  size: 16,
                                  color: AppColors.primary.withValues(alpha: 0.8),
                                ),
                              ),
                              prefixIconConstraints: const BoxConstraints(minWidth: 40, minHeight: 0),
                            ),
                            onSubmitted: (_) => _markManual(),
                          ),
                        ),
                        if (_isManualLoading)
                          const Padding(
                            padding: EdgeInsets.only(right: 8),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                        else
                          Material(
                            color: AppColors.primary,
                            borderRadius: BorderRadius.circular(12),
                            child: InkWell(
                              onTap: _markManual,
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Text(
                                  'VERIFY & MARK',
                                  style: theme.textTheme.labelLarge?.copyWith(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),

                const Spacer(flex: 3),
              ],
              ),
            ),
        ),
      ),
    );
  }

  // ── Geo Loading State ──────────────────────────────────────────────────────
  Widget _buildGeoLoadingState(ThemeData theme) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 64,
            height: 64,
            child: CircularProgressIndicator(
              color: AppColors.cyan,
              strokeWidth: 3,
            ),
          ),
          const SizedBox(height: 28),
          Text(
            'Verifying Location',
            style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Text(
            'Checking if you are within the\nclassroom boundary...',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  // ── Geo Blocked State ──────────────────────────────────────────────────────
  Widget _buildGeoBlockedState(ThemeData theme) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.rose.withValues(alpha: 0.12),
                border: Border.all(color: AppColors.rose.withValues(alpha: 0.3), width: 2),
              ),
              child: Center(
                child: Icon(Icons.location_off_rounded, size: 44, color: AppColors.rose),
              ),
            ),
            const SizedBox(height: 28),
            Text(
              'Outside Classroom',
              style: theme.textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: AppColors.rose,
              ),
            ),
            const SizedBox(height: 12),
            GlassCard(
              borderRadius: 16,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              borderColor: AppColors.rose.withValues(alpha: 0.2),
              child: Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  height: 1.5,
                ),
              ),
            ),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: 0,
              ),
              onPressed: () {
                setState(() {
                  _isGeoChecking = true;
                  _isGeoBlocked = false;
                  _isError = false;
                  _statusMessage = 'Checking location...\nPlease wait.';
                });
                _checkGeofenceAndStart();
              },
              icon: const FaIcon(FontAwesomeIcons.locationArrow, size: 16),
              label: const Text('Retry Location Check', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Custom Painters remain unchanged ──
class _DashedRingPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashCount;
  final double radius;

  _DashedRingPainter({
    required this.color,
    required this.strokeWidth,
    required this.dashCount,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final gapAngle = (2 * math.pi) / dashCount;
    final dashAngle = gapAngle * 0.5;

    for (int i = 0; i < dashCount; i++) {
      final startAngle = i * gapAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _GradientArcPainter extends CustomPainter {
  final Color color1;
  final Color color2;
  final double strokeWidth;
  final double arcLength;
  final double radius;

  _GradientArcPainter({
    required this.color1,
    required this.color2,
    required this.strokeWidth,
    required this.arcLength,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);

    final gradient = SweepGradient(
      colors: [color1, color2, color2.withValues(alpha: 0)],
      stops: const [0.0, 0.6, 1.0],
    );

    canvas.drawArc(
      rect,
      -math.pi / 2,
      arcLength,
      false,
      Paint()
        ..shader = gradient.createShader(rect)
        ..strokeWidth = strokeWidth
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
