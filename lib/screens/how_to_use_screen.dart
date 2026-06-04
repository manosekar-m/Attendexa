import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import '../main.dart';
import '../widgets/glass_card.dart';

class HowToUseScreen extends StatelessWidget {
  const HowToUseScreen({super.key});

  Widget _buildBulletPoint(BuildContext context, String title, String description, dynamic icon) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: GlassCard(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isDark
                    ? AppColors.secondary.withValues(alpha: 0.2)
                    : AppColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: FaIcon(
                icon,
                size: 16,
                color: isDark ? AppColors.secondary : AppColors.primary,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('How to use Attendexa'),
        centerTitle: true,
        leading: IconButton(
          icon: FaIcon(
            FontAwesomeIcons.chevronLeft,
            color: theme.colorScheme.onSurface,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [AppColors.darkBg, AppColors.primary.withValues(alpha: 0.05), AppColors.darkBg]
                : [AppColors.lightBg, AppColors.secondary.withValues(alpha: 0.05), AppColors.lightBg],
          ),
        ),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(24),
            physics: const BouncingScrollPhysics(),
            children: [
              _buildBulletPoint(
                context,
                '1. Import Student Data',
                'Start by importing your class excel file. Ensure your .xlsx file contains columns for "NFC ID" (or "rfid"), "Name", and "std-sec". Tap "Import Students" on the Dashboard to load them into the database.',
                FontAwesomeIcons.fileExcel,
              ),
              _buildBulletPoint(
                context,
                '2. Configure Geofencing',
                'Go to Settings and tap "Classroom Location". Set your latitude, longitude, and allowed scanning radius to ensure students can only be marked present when they are inside the classroom.',
                FontAwesomeIcons.locationCrosshairs,
              ),
              _buildBulletPoint(
                context,
                '3. Mark Attendance',
                'Tap "Mark Attendance". When the scanning ring appears, have students tap their NFC tags against the back of your device. The system will verify the location before marking them present.',
                FontAwesomeIcons.nfcSymbol,
              ),
              _buildBulletPoint(
                context,
                '4. Manual Entry (Fallback)',
                'If a student forgot their NFC tag, simply type their exact NFC Tag ID into the manual entry box at the bottom of the Mark Attendance screen and tap "Mark". Location verification still applies.',
                FontAwesomeIcons.keyboard,
              ),
              _buildBulletPoint(
                context,
                '5. Real-time Dashboard',
                'Return to the Dashboard at any time to monitor the percentage of students present today and view overall attendance statistics dynamically.',
                FontAwesomeIcons.chartPie,
              ),
              _buildBulletPoint(
                context,
                '6. Review History logs',
                'Tap "History" to select any past date from the calendar and review the detailed presence records for that specific operational day.',
                FontAwesomeIcons.clockRotateLeft,
              ),
              _buildBulletPoint(
                context,
                '7. Export Daily Records',
                'At the end of the day, tap "Export Today" on the Dashboard. This securely bundles all marked attendance into an Excel (.xlsx) file and saves it locally to your device.',
                FontAwesomeIcons.fileExport,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
