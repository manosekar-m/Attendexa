import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../main.dart';
import '../services/database_service.dart';
import '../services/excel_service.dart';
import '../widgets/glass_card.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  List<Map<String, dynamic>> _records = [];
  bool _isLoading = true;

  // Filter state
  String? _selectedStdSec; // null = All
  List<String> _allStdSecs = [];

  late final AnimationController _listController;

  @override
  void initState() {
    super.initState();
    _listController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _loadHistory();
  }

  @override
  void dispose() {
    _listController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    setState(() => _isLoading = true);
    final dbService = context.read<DatabaseService>();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Load records AND all students in parallel
    final results = await Future.wait([
      dbService.getTodayAttendanceList(dateStr),
      dbService.getAllStudents(),
    ]);
    final records = results[0] as List<Map<String, dynamic>>;
    final allStudents = results[1] as List;

    // Collect unique std-secs from ALL students so new classes always appear
    final stdSecs = allStudents
        .map((s) => (s.stdSec as String).trim())
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList()
      ..sort();

    if (mounted) {
      setState(() {
        _records = records;
        _allStdSecs = stdSecs;
        // Reset filter if the previously selected class no longer exists
        if (_selectedStdSec != null && !stdSecs.contains(_selectedStdSec)) {
          _selectedStdSec = null;
        }
        _isLoading = false;
      });
      _listController.forward(from: 0);
    }
  }

  List<Map<String, dynamic>> get _filteredRecords {
    if (_selectedStdSec == null) return _records;
    return _records.where((r) => r['stdSec'] == _selectedStdSec).toList();
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppColors.primary,
                ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _loadHistory();
    }
  }

  Future<void> _exportDay() async {
    final excelService = context.read<ExcelService>();
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);

    // Export only what's currently visible (respects filter)
    final recordsToExport = _filteredRecords;
    if (recordsToExport.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_selectedStdSec != null
                ? "No records for $_selectedStdSec on this date"
                : "No records to export"),
            behavior: SnackBarBehavior.floating,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
      return;
    }

    // Include filter label in filename if filtered
    final suffix = _selectedStdSec != null
        ? '_${_selectedStdSec!.replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_')}'
        : '';
    final path =
        await excelService.exportAttendance('$dateStr$suffix', recordsToExport);
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
    final isDark = theme.brightness == Brightness.dark;
    final filtered = _filteredRecords;

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
          'History',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: FaIcon(FontAwesomeIcons.fileExport,
                size: 18, color: theme.colorScheme.primary),
            onPressed: _exportDay,
            tooltip: 'Export',
          ),
          IconButton(
            icon: FaIcon(FontAwesomeIcons.calendarDay,
                size: 18, color: theme.colorScheme.primary),
            onPressed: () => _selectDate(context),
            tooltip: 'Select Date',
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              AppColors.primary.withValues(alpha: isDark ? 0.06 : 0.04),
              isDark ? AppColors.darkBg : AppColors.lightBg,
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // ── Date Header ──
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: GlassCard(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  onTap: () => _selectDate(context),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const FaIcon(FontAwesomeIcons.calendarCheck,
                            size: 14, color: AppColors.primary),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        DateFormat('EEEE, MMMM d, yyyy')
                            .format(_selectedDate),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: theme.colorScheme.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '${filtered.length}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // ── Std-Sec Filter Chips ──
              if (!_isLoading && _allStdSecs.isNotEmpty)
                SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    children: [
                      // "All" chip
                      _FilterChip(
                        label: 'All',
                        isSelected: _selectedStdSec == null,
                        onTap: () {
                          setState(() => _selectedStdSec = null);
                          _listController.forward(from: 0);
                        },
                        isDark: isDark,
                      ),
                      ..._allStdSecs.map((s) => _FilterChip(
                            label: s,
                            isSelected: _selectedStdSec == s,
                            onTap: () {
                              setState(() => _selectedStdSec = s);
                              _listController.forward(from: 0);
                            },
                            isDark: isDark,
                          )),
                    ],
                  ),
                ),
              if (!_isLoading && _allStdSecs.isNotEmpty)
                const SizedBox(height: 12),

              // ── Records List ──
              Expanded(
                child: _isLoading
                    ? Center(
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: theme.colorScheme.primary,
                        ),
                      )
                    : filtered.isEmpty
                        ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.outline
                                        .withValues(alpha: 0.08),
                                    shape: BoxShape.circle,
                                  ),
                                  child: FaIcon(
                                      FontAwesomeIcons.calendarXmark,
                                      size: 40,
                                      color: theme.colorScheme.outline
                                          .withValues(alpha: 0.5)),
                                ),
                                const SizedBox(height: 20),
                                Text(
                                  _selectedStdSec != null
                                      ? 'No records for $_selectedStdSec'
                                      : 'No records for this date',
                                  style:
                                      theme.textTheme.bodyLarge?.copyWith(
                                    color: theme.colorScheme.outline,
                                  ),
                                ),
                              ],
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(horizontal: 24),
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final record = filtered[index];
                              final timeStr =
                                  (record['time'] as String?) ?? '';

                              // Stagger animation
                              final delay = index * 0.08;
                              final animation = CurvedAnimation(
                                parent: _listController,
                                curve: Interval(
                                  delay.clamp(0.0, 0.8),
                                  (delay + 0.4).clamp(0.0, 1.0),
                                  curve: Curves.easeOutCubic,
                                ),
                              );

                              return AnimatedBuilder(
                                animation: animation,
                                builder: (context, _) {
                                  return Transform.translate(
                                    offset: Offset(
                                        0, 30 * (1 - animation.value)),
                                    child: Opacity(
                                      opacity: animation.value,
                                      child: Padding(
                                        padding:
                                            const EdgeInsets.only(bottom: 12),
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
                                            borderRadius: BorderRadius.circular(20),
                                            border: Border.all(
                                              color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.05),
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withValues(alpha: 0.03),
                                                blurRadius: 10,
                                                offset: const Offset(0, 4),
                                              ),
                                            ],
                                          ),
                                          padding: const EdgeInsets.all(16),
                                          child: Row(
                                            children: [
                                              // Avatar — green for present, red for absent
                                              Container(
                                                width: 50,
                                                height: 50,
                                                decoration: BoxDecoration(
                                                  gradient: LinearGradient(
                                                    colors: record['status'] == 'Absent'
                                                        ? [AppColors.rose, const Color(0xFFE11D48)]
                                                        : [AppColors.primary, AppColors.secondary],
                                                    begin: Alignment.topLeft,
                                                    end: Alignment.bottomRight,
                                                  ),
                                                  shape: BoxShape.circle,
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: (record['status'] == 'Absent' ? AppColors.rose : AppColors.primary).withValues(alpha: 0.3),
                                                      blurRadius: 8,
                                                      offset: const Offset(0, 4),
                                                    ),
                                                  ],
                                                ),
                                                child: Center(
                                                  child: Text(
                                                    record['name'].toString().isNotEmpty ? record['name'].toString()[0].toUpperCase() : '?',
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 20,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(width: 16),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment: CrossAxisAlignment.start,
                                                  children: [
                                                    Text(
                                                      record['name'],
                                                      style: theme.textTheme.titleMedium?.copyWith(
                                                        fontWeight: FontWeight.w800,
                                                        color: theme.colorScheme.onSurface,
                                                      ),
                                                      maxLines: 1,
                                                      overflow: TextOverflow.ellipsis,
                                                    ),
                                                    const SizedBox(height: 6),
                                                    Container(
                                                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                                      decoration: BoxDecoration(
                                                        color: AppColors.secondary.withValues(alpha: 0.15),
                                                        borderRadius: BorderRadius.circular(12),
                                                      ),
                                                      child: Text(
                                                        'Class: ${record['stdSec']}',
                                                        style: theme.textTheme.labelSmall?.copyWith(
                                                          color: AppColors.secondary,
                                                          fontWeight: FontWeight.w700,
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              // Time + Status column
                                              Column(
                                                crossAxisAlignment: CrossAxisAlignment.end,
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                                    decoration: BoxDecoration(
                                                      gradient: LinearGradient(
                                                        colors: record['status'] == 'Absent'
                                                            ? [AppColors.rose, const Color(0xFFE11D48)]
                                                            : [AppColors.mint, const Color(0xFF10B981)],
                                                      ),
                                                      borderRadius: BorderRadius.circular(12),
                                                      boxShadow: [
                                                        BoxShadow(
                                                          color: (record['status'] == 'Absent' ? AppColors.rose : AppColors.mint).withValues(alpha: 0.35),
                                                          blurRadius: 6,
                                                          offset: const Offset(0, 2),
                                                        ),
                                                      ],
                                                    ),
                                                    child: Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        FaIcon(
                                                          record['status'] == 'Absent'
                                                              ? FontAwesomeIcons.xmark
                                                              : FontAwesomeIcons.check,
                                                          size: 10,
                                                          color: Colors.white,
                                                        ),
                                                        const SizedBox(width: 5),
                                                        Text(
                                                          record['status'],
                                                          style: theme.textTheme.labelSmall?.copyWith(
                                                            color: Colors.white,
                                                            fontWeight: FontWeight.w800,
                                                            letterSpacing: 0.5,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  if (timeStr.isNotEmpty) ...[
                                                    const SizedBox(height: 6),
                                                    Row(
                                                      mainAxisSize: MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons.access_time_rounded,
                                                          size: 14,
                                                          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                        ),
                                                        const SizedBox(width: 4),
                                                        Text(
                                                          timeStr,
                                                          style: theme.textTheme.labelSmall?.copyWith(
                                                            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                                                            fontWeight: FontWeight.w700,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Filter Chip Widget ──────────────────────────────────────────────────────
class _FilterChip extends StatefulWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;
  final bool isDark;

  const _FilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    required this.isDark,
  });

  @override
  State<_FilterChip> createState() => _FilterChipState();
}

class _FilterChipState extends State<_FilterChip>
    with SingleTickerProviderStateMixin {
  late final AnimationController _press;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _press = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
      lowerBound: 0.0,
      upperBound: 0.06,
    );
    _scale = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _press, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return GestureDetector(
      onTapDown: (_) => _press.forward(),
      onTapUp: (_) {
        _press.reverse();
        widget.onTap();
      },
      onTapCancel: () => _press.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeInOut,
          margin: const EdgeInsets.only(right: 8),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 0),
          decoration: BoxDecoration(
            gradient: widget.isSelected
                ? const LinearGradient(
                    colors: [AppColors.primary, Color(0xFF7B5CF0)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
            color: widget.isSelected
                ? null
                : (widget.isDark
                    ? Colors.white.withValues(alpha: 0.07)
                    : Colors.black.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(
              color: widget.isSelected
                  ? Colors.transparent
                  : AppColors.primary.withValues(alpha: 0.35),
              width: 1.4,
            ),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.35),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
                : null,
          ),
          child: Center(
            child: Text(
              widget.label,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: widget.isSelected
                    ? Colors.white
                    : theme.colorScheme.onSurface.withValues(alpha: 0.75),
                letterSpacing: 0.3,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
