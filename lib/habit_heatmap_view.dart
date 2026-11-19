import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/database_helper.dart';

class HabitHeatmapView extends StatefulWidget {
  const HabitHeatmapView({super.key});

  @override
  State<HabitHeatmapView> createState() => _HabitHeatmapViewState();
}

class _HabitHeatmapViewState extends State<HabitHeatmapView> {
  final _dbHelper = DatabaseHelper();
  int _year = DateTime.now().year;
  bool _isLoading = true;
  Object? _loadError;
  List<Map<String, dynamic>> _habits = [];
  Set<String> _completedDays = {};

  @override
  void initState() {
    super.initState();
    _loadYear(_year);
  }

  Future<void> _loadYear(int year) async {
    setState(() {
      _isLoading = true;
      _loadError = null;
    });

    try {
      final data = await _dbHelper.getYearHabitActivity(year);
      if (!mounted || year != _year) return;
      setState(() {
        _habits = (data['habits'] as List)
            .map((habit) => Map<String, dynamic>.from(habit))
            .toList();
        _completedDays = (data['logs'] as List)
            .map(
              (log) =>
                  '${log['habit_id']}:${(log['date'] as String).substring(0, 10)}',
            )
            .toSet();
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted || year != _year) return;
      setState(() {
        _loadError = error;
        _isLoading = false;
      });
    }
  }

  void _changeYear(int amount) {
    setState(() {
      _year += amount;
    });
    _loadYear(_year);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'HABIT ACTIVITY',
                style: GoogleFonts.jetBrainsMono(
                  textStyle: const TextStyle(color: Colors.white, fontSize: 20),
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Previous year',
                onPressed: () => _changeYear(-1),
                color: Colors.white,
                icon: const Icon(Icons.chevron_left),
              ),
              Text(
                '$_year',
                style: GoogleFonts.jetBrainsMono(
                  textStyle: const TextStyle(color: Colors.white, fontSize: 18),
                ),
              ),
              IconButton(
                tooltip: 'Next year',
                onPressed: _year < DateTime.now().year
                    ? () => _changeYear(1)
                    : null,
                color: Colors.white,
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const Divider(color: Colors.white54),
          Expanded(child: _buildContent()),
          const SizedBox(height: 8),
          _buildLegend(),
        ],
      ),
    );
  }

  Widget _buildContent() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_loadError != null) {
      return Center(
        child: Text(
          'Could not load habit activity: $_loadError',
          style: const TextStyle(color: Colors.white),
        ),
      );
    }
    if (_habits.isEmpty) {
      return const Center(
        child: Text(
          'No habits to display for this year.',
          style: TextStyle(color: Colors.white),
        ),
      );
    }

    return ListView.separated(
      itemCount: _habits.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final habit = _habits[index];
        return Container(
          decoration: BoxDecoration(
            color: const Color(0xFF2C3930),
            borderRadius: BorderRadius.circular(5),
          ),
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                habit['habit'].toString().toUpperCase(),
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              _HabitYearGrid(
                habitId: habit['id'] as int,
                year: _year,
                completedDays: _completedDays,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildLegend() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text('Less', style: TextStyle(fontSize: 12, color: Colors.white)),
        const SizedBox(width: 6),
        const _HeatmapSquare(completed: false),
        const SizedBox(width: 4),
        const _HeatmapSquare(completed: true),
        const SizedBox(width: 6),
        const Text('Done', style: TextStyle(fontSize: 12, color: Colors.white)),
      ],
    );
  }
}

class _HabitYearGrid extends StatelessWidget {
  const _HabitYearGrid({
    required this.habitId,
    required this.year,
    required this.completedDays,
  });

  final int habitId;
  final int year;
  final Set<String> completedDays;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final firstOfYear = DateTime(year, 1, 1);
        final gridStart = firstOfYear.subtract(
          Duration(days: firstOfYear.weekday % 7),
        );
        final lastOfYear = DateTime(year, 12, 31);
        final weekCount =
            (lastOfYear.difference(gridStart).inDays + 1 + 6) ~/ 7;
        final availableWidth = constraints.maxWidth.isFinite
            ? constraints.maxWidth
            : 800.0;
        final minimumGridWidth = 24 + weekCount * 12.0;
        final gridWidth = availableWidth < minimumGridWidth
            ? minimumGridWidth
            : availableWidth;
        final weekWidth = (gridWidth - 24) / weekCount;
        final cellSize = (weekWidth - 4).clamp(7.0, 24.0).toDouble();
        final cellSpacing = (weekWidth - cellSize) / 2;
        final monthLabels = <Widget>[];

        for (var month = 1; month <= 12; month++) {
          final firstOfMonth = DateTime(year, month, 1);
          final weekIndex = firstOfMonth.difference(gridStart).inDays ~/ 7;
          monthLabels.add(
            Positioned(
              left: weekIndex * weekWidth,
              top: 0,
              child: SizedBox(
                width: 36,
                child: Text(
                  _monthAbbreviation(month),
                  style: const TextStyle(fontSize: 10, color: Colors.white70),
                ),
              ),
            ),
          );
        }

        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width: gridWidth,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(width: 24),
                    SizedBox(
                      width: weekCount * weekWidth,
                      height: 16,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: monthLabels,
                      ),
                    ),
                  ],
                ),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 24,
                      child: Column(
                        children: [
                          _WeekdayLabel('S', height: weekWidth),
                          _WeekdayLabel('M', height: weekWidth),
                          _WeekdayLabel('T', height: weekWidth),
                          _WeekdayLabel('W', height: weekWidth),
                          _WeekdayLabel('T', height: weekWidth),
                          _WeekdayLabel('F', height: weekWidth),
                          _WeekdayLabel('S', height: weekWidth),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: List.generate(weekCount, (week) {
                        return SizedBox(
                          width: weekWidth,
                          child: Column(
                            children: List.generate(7, (weekday) {
                              final date = gridStart.add(
                                Duration(days: week * 7 + weekday),
                              );
                              final inYear = date.year == year;
                              final dateLabel =
                                  '${date.year}-${date.month.toString().padLeft(2, '0')}-'
                                  '${date.day.toString().padLeft(2, '0')}';
                              final completed =
                                  inYear &&
                                  completedDays.contains('$habitId:$dateLabel');
                              return Tooltip(
                                message:
                                    '$dateLabel${completed ? ' · Done' : ''}',
                                child: _HeatmapSquare(
                                  completed: completed,
                                  visible: inYear,
                                  size: cellSize,
                                  spacing: cellSpacing,
                                ),
                              );
                            }),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  String _monthAbbreviation(int month) {
    const names = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return names[month - 1];
  }
}

class _WeekdayLabel extends StatelessWidget {
  const _WeekdayLabel(this.text, {required this.height});

  final String text;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          text,
          style: const TextStyle(fontSize: 9, color: Colors.white70),
        ),
      ),
    );
  }
}

class _HeatmapSquare extends StatelessWidget {
  const _HeatmapSquare({
    required this.completed,
    this.visible = true,
    this.size = 11,
    this.spacing = 2,
  });

  final bool completed;
  final bool visible;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      margin: EdgeInsets.all(spacing),
      decoration: BoxDecoration(
        color: !visible
            ? Colors.transparent
            : completed
            ? const Color(0xFF39D353)
            : const Color(0xFF26332B),
        borderRadius: BorderRadius.circular(2),
        border: visible && !completed
            ? Border.all(color: const Color(0xFF3B4A40), width: 0.5)
            : null,
      ),
    );
  }
}
