import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/database_helper.dart';

Future<void> showSettingsDialog(
  BuildContext context, {
  VoidCallback? onDataImported,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _SettingsDialog(onDataImported: onDataImported),
  );
}

class _SettingsDialog extends StatefulWidget {
  const _SettingsDialog({this.onDataImported});

  final VoidCallback? onDataImported;

  @override
  State<_SettingsDialog> createState() => _SettingsDialogState();
}

class _SettingsDialogState extends State<_SettingsDialog> {
  final _dbHelper = DatabaseHelper();
  bool _isBusy = false;
  String? _message;
  String? _error;

  Future<void> _exportBackup() async {
    setState(() {
      _isBusy = true;
      _message = null;
      _error = null;
    });

    try {
      final bytes = await _dbHelper.exportDatabase();
      if (!mounted) return;
      final location = await FilePicker.platform.saveFile(
        dialogTitle: 'Export Habit Tracker data',
        fileName: 'habit_tracker_backup.db',
        type: FileType.custom,
        allowedExtensions: ['db'],
        bytes: bytes,
        lockParentWindow: true,
      );
      if (!mounted || location == null) return;
      setState(() {
        _message = 'Backup exported to $location';
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _importBackup() async {
    setState(() {
      _isBusy = true;
      _message = null;
      _error = null;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'Import Habit Tracker data',
        type: FileType.custom,
        allowedExtensions: ['db', 'sqlite', 'sqlite3'],
        allowMultiple: false,
        lockParentWindow: true,
      );
      if (!mounted || result == null || result.files.isEmpty) return;
      final backup = result.files.single;
      final backupPath = backup.path;
      if (backupPath == null) {
        throw const FormatException('Could not read the selected backup file.');
      }

      final shouldReplace = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Replace current data?'),
          content: const Text(
            'Importing this backup will replace all current habits and '
            'completion history. This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Replace data'),
            ),
          ],
        ),
      );
      if (!mounted || shouldReplace != true) return;

      await _dbHelper.importDatabase(backupPath);
      widget.onDataImported?.call();
      if (mounted) {
        setState(() {
          _message = 'Backup imported successfully.';
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _error = error.toString();
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      alignment: Alignment.center,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(5)),
      backgroundColor: const Color.fromARGB(255, 228, 228, 230),
      child: Container(
        width: 400,
        padding: const EdgeInsets.all(12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'SETTINGS',
                  style: GoogleFonts.jetBrainsMono(
                    textStyle: const TextStyle(fontSize: 22),
                  ),
                ),
                IconButton(
                  tooltip: 'Close',
                  onPressed: _isBusy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.cancel_outlined),
                  hoverColor: Colors.red.withValues(alpha: 0.2),
                ),
              ],
            ),
            const Divider(color: Colors.black54, thickness: 1.2),
            const SizedBox(height: 8),
            const Text(
              'Export or restore a complete backup of your habits and history.',
            ),
            const SizedBox(height: 16),
            _settingsAction(
              icon: Icons.file_upload_outlined,
              title: 'EXPORT DATA',
              subtitle: 'Save a full database backup',
              onTap: _exportBackup,
            ),
            const SizedBox(height: 8),
            _settingsAction(
              icon: Icons.file_download_outlined,
              title: 'IMPORT DATA',
              subtitle: 'Replace data from a backup',
              onTap: _importBackup,
            ),
            if (_isBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(
                color: Color(0xFF2C3930),
                backgroundColor: Color(0xFFDAD3BE),
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 12),
              _statusMessage(
                icon: Icons.check_circle_outline,
                message: _message!,
                color: const Color(0xFF2C6B3F),
              ),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              _statusMessage(
                icon: Icons.error_outline,
                message: _error!,
                color: Colors.red.shade800,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _settingsAction({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ListTile(
        enabled: !_isBusy,
        onTap: _isBusy ? null : onTap,
        leading: Icon(icon, color: const Color(0xFF2C3930), size: 28),
        title: Text(
          title,
          style: GoogleFonts.jetBrainsMono(
            textStyle: const TextStyle(
              color: Color(0xFF2C3930),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        subtitle: Text(subtitle),
        trailing: const Icon(Icons.chevron_right, color: Color(0xFF2C3930)),
      ),
    );
  }

  Widget _statusMessage({
    required IconData icon,
    required String message,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(message, style: TextStyle(color: color)),
          ),
        ],
      ),
    );
  }
}
