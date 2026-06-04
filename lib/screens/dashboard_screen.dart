import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/auth_service.dart';
import '../services/database_service.dart';
import '../services/excel_service.dart';
import '../widgets/glass_card.dart';
import 'attendance_marking_screen.dart';
import 'import_students_screen.dart';
import 'history_screen.dart';
import 'onboarding_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen>
    with TickerProviderStateMixin {
  int _currentIndex = 0;
  int _presentCount = 0;
  int _totalStudents = 0;
  bool _isLoading = true;
  int _avatarIndex = 0;
  String _userName = 'Teacher';
  List<Map<String, dynamic>> _recentScans = [];

  late final AnimationController _bgController;
  late final AnimationController _staggerController;
  late final AnimationController _pulseController;

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Color _getStudentColor(String name) {
    final colors = [
      const Color(0xFF2563EB), // Primary Blue
      const Color(0xFF059669), // Emerald Mint
      const Color(0xFFCA8A04), // Gold
      const Color(0xFF0EA5E9), // Cyan
      const Color(0xFF8B5CF6), // Violet
      const Color(0xFFEC4899), // Pink
      const Color(0xFFF97316), // Orange
    ];
    int hash = 0;
    for (int i = 0; i < name.length; i++) {
      hash = name.codeUnitAt(i) + ((hash << 5) - hash);
    }
    return colors[hash.abs() % colors.length];
  }

  String _getInitials(String name) {
    if (name.isEmpty) return '';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length > 1) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  @override
  void initState() {
    super.initState();

    _bgController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    )..repeat();

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);

    _loadStats();
    _loadUserDetails();
  }

  @override
  void dispose() {
    _bgController.dispose();
    _staggerController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  Future<void> _loadStats() async {
    try {
      final dbService = context.read<DatabaseService>();
      final today = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final count = await dbService.getPresentCountToday(today);
      final students = await dbService.getAllStudents();
      final records = await dbService.getTodayAttendanceList(today);
      final recent = List<Map<String, dynamic>>.from(records).reversed.take(4).toList();

      if (mounted) {
        setState(() {
          _presentCount = count;
          _totalStudents = students.length;
          _recentScans = recent;
          _isLoading = false;
        });
        _staggerController.forward();
      }
    } catch (e) {
      // Mock data if database is unavailable (e.g., on Web)
      if (mounted) {
        setState(() {
          _presentCount = 0;
          _totalStudents = 0;
          _recentScans = [];
          _isLoading = false;
        });
        _staggerController.forward();
      }
    }
  }

  Future<void> _loadUserDetails() async {
    final name = await AuthService().getUserName();
    final avatar = await AuthService().getAvatar();
    if (mounted) {
      setState(() {
        _userName = name;
        _avatarIndex = avatar;
      });
    }
  }

  Future<void> _exportToday() async {
    final dbService = context.read<DatabaseService>();
    final excelService = context.read<ExcelService>();
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    final records = await dbService.getTodayAttendanceList(today);
    if (records.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text("No records to export today"),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    final path = await excelService.exportAttendance(today, records);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(path != null ? "Exported to: $path" : "Export failed"),
          behavior: SnackBarBehavior.floating,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      extendBody: true,
      bottomNavigationBar: BottomNavigationBar(
        backgroundColor: theme.brightness == Brightness.dark
            ? AppColors.darkBg.withValues(alpha: 0.9)
            : AppColors.lightBg.withValues(alpha: 0.9),
        elevation: 0,
        selectedItemColor: AppColors.secondary,
        unselectedItemColor: theme.colorScheme.onSurface.withValues(alpha: 0.4),
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() => _currentIndex = index);
        },
        items: const [
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.house, size: 20),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: FaIcon(FontAwesomeIcons.gear, size: 20),
            label: 'Settings',
          ),
        ],
      ),
      body: Stack(
        children: [
          // ── Animated Mesh Background ──
          _AnimatedMeshBackground(controller: _bgController),

          // ── Content ──
          SafeArea(
            child: IndexedStack(
              index: _currentIndex,
              children: [
                RefreshIndicator(
                  onRefresh: _loadStats,
                  color: AppColors.primary,
                  backgroundColor: theme.cardTheme.color,
                  child: CustomScrollView(
                    physics: const BouncingScrollPhysics(
                        parent: AlwaysScrollableScrollPhysics()),
                  slivers: [
                    // ── Header ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 0),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _getGreeting(),
                                  style: theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.onSurface
                                        .withValues(alpha: 0.6),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                InkWell(
                                  onTap: _loadStats,
                                  borderRadius: BorderRadius.circular(8),
                                  child: ShaderMask(
                                    shaderCallback: (bounds) =>
                                        const LinearGradient(
                                      colors: [
                                        AppColors.primary,
                                        AppColors.secondary,
                                        AppColors.cyan,
                                      ],
                                    ).createShader(bounds),
                                    child: Text(
                                      '$_userName 👋',
                                      style:
                                          theme.textTheme.headlineLarge?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            // Date chip & Avatar
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  onPressed: _loadStats,
                                  icon: GlassCard(
                                    padding: const EdgeInsets.all(10),
                                    borderRadius: 12,
                                    child: FaIcon(
                                      FontAwesomeIcons.arrowsRotate,
                                      size: 16,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                                  tooltip: 'Refresh',
                                ),
                                const SizedBox(width: 12),
                                GlassCard(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  borderRadius: 16,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      FaIcon(FontAwesomeIcons.calendarDay,
                                          size: 14,
                                          color: theme.colorScheme.primary),
                                      const SizedBox(width: 8),
                                      Text(
                                        DateFormat('MMM d').format(DateTime.now()),
                                        style:
                                            theme.textTheme.labelLarge?.copyWith(
                                          color: theme.colorScheme.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                // Avatar
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    color: kAvatars[_avatarIndex.clamp(0, kAvatars.length - 1)].bgColor,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: AppColors.primary.withValues(alpha: 0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Center(
                                    child: Text(
                                      kAvatars[_avatarIndex.clamp(0, kAvatars.length - 1)].emoji,
                                      style: const TextStyle(fontSize: 20),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                        const SizedBox(height: 28),
                      ],
                    ),
                  ),
                ),

                // ── Stats Card ──
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: Column(
                      children: [
                        _buildHeroStatsCard(theme),
                        const SizedBox(height: 16),
                        _buildSecondaryStatsRow(theme),
                      ],
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: 32)),

                // ── Separator ──
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  sliver: SliverToBoxAdapter(
                    child: Text(
                      'QUICK ACTIONS',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.4),
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),

                const SliverToBoxAdapter(
                    child: SizedBox(height: 16)),

                // ── Menu Grid with Staggered Animation ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
                  sliver: SliverGrid(
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      mainAxisSpacing: 16,
                      crossAxisSpacing: 16,
                      childAspectRatio: 1.0,
                    ),
                    delegate: SliverChildListDelegate([
                      _buildStaggeredCard(
                        index: 0,
                        child: _buildMenuCard(
                          context,
                          'Mark Attendance',
                          'Scan student NFC tags',
                          FontAwesomeIcons.nfcSymbol,
                          AppColors.primary,
                          [AppColors.primary, AppColors.secondary],
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const AttendanceMarkingScreen()),
                          ).then((_) => _loadStats()),
                        ),
                      ),
                      _buildStaggeredCard(
                        index: 1,
                        child: _buildMenuCard(
                          context,
                          'Import Students',
                          'Excel spreadsheet import',
                          FontAwesomeIcons.fileImport,
                          AppColors.gold,
                          [const Color(0xFFF59E0B), AppColors.gold],
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const ImportStudentsScreen()),
                          ).then((_) => _loadStats()),
                        ),
                      ),
                      _buildStaggeredCard(
                        index: 2,
                        child: _buildMenuCard(
                          context,
                          'View History',
                          'Browse attendance logs',
                          FontAwesomeIcons.clockRotateLeft,
                          AppColors.mint,
                          [const Color(0xFF10B981), AppColors.mint],
                          () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const HistoryScreen()),
                          ).then((_) => _loadStats()),
                        ),
                      ),
                      _buildStaggeredCard(
                        index: 3,
                        child: _buildMenuCard(
                          context,
                          'Export Today',
                          'Download today\'s Excel',
                          FontAwesomeIcons.fileExport,
                          AppColors.cyan,
                          [const Color(0xFF0EA5E9), AppColors.cyan],
                          _exportToday,
                        ),
                      ),
                    ]),
                  ),
                ),

                // ── Recent Activity Section ──
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 0, 24, 80),
                  sliver: SliverToBoxAdapter(
                    child: _buildStaggeredCard(
                      index: 4,
                      child: _buildRecentActivitySection(theme),
                    ),
                  ),
                ),
                    ],
                  ),
                ),
                SettingsScreen(
                  onAvatarChanged: (newIndex) {
                    setState(() => _avatarIndex = newIndex);
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero Stats Card ──
  Widget _buildHeroStatsCard(ThemeData theme) {
    final percentage =
        _totalStudents > 0 ? (_presentCount / _totalStudents) : 0.0;
    final pctText = _totalStudents > 0
        ? '${(percentage * 100).toStringAsFixed(1)}%'
        : '0.0%';

    String subtitleMessage;
    if (_totalStudents == 0) {
      subtitleMessage = 'No students imported yet';
    } else if (_presentCount == _totalStudents) {
      subtitleMessage = 'Perfect attendance today! 🌟';
    } else {
      subtitleMessage = '${_totalStudents - _presentCount} pending NFC scan';
    }

    return GlowingGlassCard(
      glowColors: const [AppColors.primary, AppColors.secondary],
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          // Left: Text info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppColors.mint,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.mint.withValues(alpha: 0.6),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'ATTENDANCE RATE',
                      style: theme.textTheme.labelLarge?.copyWith(
                        color: theme.colorScheme.onSurface
                            .withValues(alpha: 0.5),
                        letterSpacing: 1.5,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _isLoading
                    ? SizedBox(
                        height: 56,
                        child: Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      )
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            pctText,
                            style: theme.textTheme.displayMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.onSurface,
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '$_presentCount of $_totalStudents present today',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                const SizedBox(height: 8),
                Text(
                  subtitleMessage,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),

          // Right: Circular progress
          const SizedBox(width: 16),
          SizedBox(
            width: 90,
            height: 90,
            child: AnimatedBuilder(
              animation: _pulseController,
              builder: (context, child) {
                return CustomPaint(
                  painter: _CircularProgressPainter(
                    progress: _isLoading ? 0 : percentage,
                    pulseValue: _pulseController.value,
                    primaryColor: AppColors.primary,
                    secondaryColor: AppColors.secondary,
                    trackColor: theme.colorScheme.onSurface
                        .withValues(alpha: 0.08),
                  ),
                  child: Center(
                    child: Text(
                      _isLoading
                          ? '--'
                          : '${(percentage * 100).toInt()}%',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: theme.colorScheme.onSurface,
                        fontSize: 18,
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

  // ── Secondary Stats Row ──
  Widget _buildSecondaryStatsRow(ThemeData theme) {
    final pendingCount = math.max(0, _totalStudents - _presentCount);

    return Row(
      children: [
        Expanded(
          child: _buildStatItem(
            label: 'Enrolled',
            value: '$_totalStudents',
            icon: FontAwesomeIcons.users,
            color: AppColors.primary,
            theme: theme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            label: 'Scanned',
            value: '$_presentCount',
            icon: FontAwesomeIcons.circleCheck,
            color: AppColors.mint,
            theme: theme,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildStatItem(
            label: 'Pending',
            value: '$pendingCount',
            icon: FontAwesomeIcons.solidClock,
            color: AppColors.gold,
            theme: theme,
          ),
        ),
      ],
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required dynamic icon,
    required Color color,
    required ThemeData theme,
  }) {
    final isDark = theme.brightness == Brightness.dark;
    return GlassCard(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
      borderRadius: 20,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: isDark ? 0.20 : 0.10),
              shape: BoxShape.circle,
            ),
            child: FaIcon(icon, color: color, size: 16),
          ),
          const SizedBox(height: 12),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.45),
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  // ── Recent Activity Section ──
  Widget _buildRecentActivitySection(ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'RECENT ACTIVITY',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                letterSpacing: 2,
              ),
            ),
            if (_recentScans.isNotEmpty)
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  ).then((_) => _loadStats());
                },
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'View Logs',
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const FaIcon(
                      FontAwesomeIcons.arrowRight,
                      size: 10,
                      color: AppColors.primary,
                    ),
                  ],
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),

        // Content Feed
        _recentScans.isEmpty
            ? GlassCard(
                padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                borderRadius: 24,
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.05),
                          shape: BoxShape.circle,
                        ),
                        child: FaIcon(
                          FontAwesomeIcons.towerBroadcast,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                          size: 20,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No activity today',
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Start scanning student tags to see live logs.',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            : GlassCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                borderRadius: 24,
                child: Column(
                  children: [
                    for (int i = 0; i < _recentScans.length; i++) ...[
                      if (i > 0)
                        Divider(
                          height: 1,
                          thickness: 0.5,
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.08),
                        ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          children: [
                            // Student Avatar with initials and name-hashed color
                            Container(
                              width: 36,
                              height: 36,
                              decoration: BoxDecoration(
                                color: _getStudentColor(_recentScans[i]['name'] ?? ''),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _getInitials(_recentScans[i]['name'] ?? ''),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            // Name & StdSec / Time
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _recentScans[i]['name'] ?? '',
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: theme.colorScheme.onSurface,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 2),
                                  Row(
                                    children: [
                                      Text(
                                        _recentScans[i]['stdSec'] ?? '',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                      Container(
                                        margin: const EdgeInsets.symmetric(horizontal: 6),
                                        width: 3,
                                        height: 3,
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Text(
                                        _recentScans[i]['time'] ?? '',
                                        style: theme.textTheme.bodyMedium?.copyWith(
                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            // Status Badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.mint.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                  color: AppColors.mint.withValues(alpha: 0.25),
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const FaIcon(
                                    FontAwesomeIcons.circleCheck,
                                    color: AppColors.mint,
                                    size: 8,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Present',
                                    style: theme.textTheme.labelSmall?.copyWith(
                                      color: AppColors.mint,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
      ],
    );
  }

  // ── Staggered Animation Wrapper ──
  Widget _buildStaggeredCard({required int index, required Widget child}) {
    final begin = index * 0.15;
    final end = begin + 0.6;
    final animation = CurvedAnimation(
      parent: _staggerController,
      curve: Interval(begin.clamp(0.0, 1.0), end.clamp(0.0, 1.0),
          curve: Curves.easeOutCubic),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, _) {
        return Transform.translate(
          offset: Offset(0, 40 * (1 - animation.value)),
          child: Opacity(
            opacity: animation.value,
            child: child,
          ),
        );
      },
    );
  }

  // ── Menu Card ──
  Widget _buildMenuCard(
    BuildContext context,
    String title,
    String subtitle,
    dynamic icon,
    Color color,
    List<Color> gradientColors,
    VoidCallback onTap,
  ) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return GlassCard(
      onTap: onTap,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon container & chevron
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      gradientColors[0].withValues(alpha: isDark ? 0.25 : 0.15),
                      gradientColors[1].withValues(alpha: isDark ? 0.10 : 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: color.withValues(alpha: 0.2),
                  ),
                ),
                child: FaIcon(icon, color: color, size: 18),
              ),
              FaIcon(
                FontAwesomeIcons.chevronRight,
                size: 11,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3),
              ),
            ],
          ),
          const Spacer(),
          // Title
          Text(
            title,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w800,
              color: theme.colorScheme.onSurface,
              fontSize: 14,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 4),
          // Subtitle
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              fontSize: 10,
              height: 1.2,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Animated Mesh Background ──
// ══════════════════════════════════════════════════════════════════════════════

class _AnimatedMeshBackground extends StatelessWidget {
  final AnimationController controller;

  const _AnimatedMeshBackground({required this.controller});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return CustomPaint(
          painter: _MeshGradientPainter(
            animationValue: controller.value,
            isDark: isDark,
          ),
          size: Size.infinite,
        );
      },
    );
  }
}

class _MeshGradientPainter extends CustomPainter {
  final double animationValue;
  final bool isDark;

  _MeshGradientPainter({
    required this.animationValue,
    required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Base fill
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, size.height),
      Paint()
        ..color = isDark ? AppColors.darkBg : AppColors.lightBg,
    );

    final t = animationValue * 2 * math.pi;

    // Orb 1 — Indigo
    _drawOrb(
      canvas,
      Offset(
        size.width * (0.2 + 0.15 * math.sin(t)),
        size.height * (0.15 + 0.1 * math.cos(t * 0.7)),
      ),
      size.width * 0.6,
      isDark
          ? AppColors.primary.withValues(alpha: 0.12)
          : AppColors.primary.withValues(alpha: 0.06),
    );

    // Orb 2 — Purple
    _drawOrb(
      canvas,
      Offset(
        size.width * (0.8 + 0.1 * math.cos(t * 1.3)),
        size.height * (0.3 + 0.12 * math.sin(t * 0.9)),
      ),
      size.width * 0.5,
      isDark
          ? AppColors.secondary.withValues(alpha: 0.10)
          : AppColors.secondary.withValues(alpha: 0.05),
    );

    // Orb 3 — Cyan accent
    _drawOrb(
      canvas,
      Offset(
        size.width * (0.5 + 0.2 * math.sin(t * 0.5)),
        size.height * (0.75 + 0.08 * math.cos(t * 1.1)),
      ),
      size.width * 0.45,
      isDark
          ? AppColors.cyan.withValues(alpha: 0.06)
          : AppColors.cyan.withValues(alpha: 0.03),
    );
  }

  void _drawOrb(Canvas canvas, Offset center, double radius, Color color) {
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 80),
    );
  }

  @override
  bool shouldRepaint(covariant _MeshGradientPainter old) =>
      old.animationValue != animationValue;
}

// ══════════════════════════════════════════════════════════════════════════════
// ── Circular Progress Painter ──
// ══════════════════════════════════════════════════════════════════════════════

class _CircularProgressPainter extends CustomPainter {
  final double progress;
  final double pulseValue;
  final Color primaryColor;
  final Color secondaryColor;
  final Color trackColor;

  _CircularProgressPainter({
    required this.progress,
    required this.pulseValue,
    required this.primaryColor,
    required this.secondaryColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = (size.shortestSide / 2) - 6;
    const strokeWidth = 6.0;

    // Track
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = trackColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth,
    );

    // Progress arc
    final sweepAngle = 2 * math.pi * progress;
    if (sweepAngle > 0) {
      final rect = Rect.fromCircle(center: center, radius: radius);
      final gradient = SweepGradient(
        startAngle: -math.pi / 2,
        endAngle: -math.pi / 2 + sweepAngle,
        colors: [primaryColor, secondaryColor],
        stops: const [0.0, 1.0],
      );

      canvas.drawArc(
        rect,
        -math.pi / 2,
        sweepAngle,
        false,
        Paint()
          ..shader = gradient.createShader(rect)
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );

      // Glow dot at end
      final dotAngle = -math.pi / 2 + sweepAngle;
      final dotCenter = Offset(
        center.dx + radius * math.cos(dotAngle),
        center.dy + radius * math.sin(dotAngle),
      );

      canvas.drawCircle(
        dotCenter,
        4 + pulseValue * 2,
        Paint()
          ..color = secondaryColor.withValues(alpha: 0.4 + pulseValue * 0.3)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        dotCenter,
        3,
        Paint()..color = Colors.white,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _CircularProgressPainter old) =>
      old.progress != progress || old.pulseValue != pulseValue;
}
