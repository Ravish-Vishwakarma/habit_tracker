import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/createhabitdialog.dart';
import 'package:habit_tracker/database_helper.dart';
import 'package:habit_tracker/edithabitmonthdialog.dart';
import 'package:habit_tracker/habit_heatmap_view.dart';
import 'package:habit_tracker/settings_dialog.dart';
import 'package:window_manager/window_manager.dart';

class HabitTracker extends StatefulWidget {
  const HabitTracker({super.key});

  @override
  State<HabitTracker> createState() => _HabitTrackerState();
}

class _HabitTrackerState extends State<HabitTracker> with WindowListener {
  var currentmonth = DateTime.now().month;
  var currentyear = DateTime.now().year;
  var months = [
    'january',
    'february',
    'march',
    'april',
    'may',
    'june',
    'july',
    'august',
    'september',
    'october',
    'november',
    'december',
  ];
  List<Map<String, dynamic>> habitTypes = [];
  List<Map<String, dynamic>> habitRows = [];
  bool _showHeatmap = false;
  bool _isMaximized = false;
  final ScrollController _scrollController = ScrollController();
  final dbHelper = DatabaseHelper();

  Future<void> loadHabitData(int month, int year) async {
    final habits = await dbHelper.getMonthHabits(month, year);
    final statuses = await dbHelper.getMonthHabitStatuses(month, year);
    final daysInMonth = DateTime(year, month + 1, 0).day;
    if (mounted && month == currentmonth && year == currentyear) {
      setState(() {
        habitTypes = habits;
        habitRows = List.generate(daysInMonth, (index) {
          final day = index + 1;
          return {
            'day': day,
            for (final habit in habits)
              (habit['id'] as int).toString():
                  statuses['${habit['id']}:$day'] ?? 0,
          };
        });
      });
    }
  }

  @override
  void initState() {
    super.initState();
    windowManager.addListener(this);
    _loadWindowState();
    loadHabitData(currentmonth, currentyear);
  }

  Future<void> _loadWindowState() async {
    final isMaximized = await windowManager.isMaximized();
    if (mounted) {
      setState(() {
        _isMaximized = isMaximized;
      });
    }
  }

  @override
  void onWindowMaximize() {
    if (mounted) {
      setState(() {
        _isMaximized = true;
      });
    }
  }

  @override
  void onWindowUnmaximize() {
    if (mounted) {
      setState(() {
        _isMaximized = false;
      });
    }
  }

  @override
  void dispose() {
    windowManager.removeListener(this);
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Color(0xFF2C3930),
      body: Container(
        color: const Color.fromARGB(255, 63, 77, 67),
        child: Padding(
          padding: const EdgeInsets.all(15.0),
          child: Column(
            children: [
              Row(
                children: [
                  Row(
                    children: [
                      IconButton(
                        tooltip: "Jump To Today",
                        onPressed: () {
                          setState(() {
                            currentmonth = DateTime.now().month;
                            currentyear = DateTime.now().year;
                          });
                          loadHabitData(currentmonth, currentyear);
                        },
                        icon: Icon(Icons.today, color: Color(0xFFDBDBDB)),
                      ),
                      IconButton(
                        tooltip: _showHeatmap
                            ? "Back to Habits"
                            : "Habit Heatmap",
                        onPressed: () {
                          setState(() {
                            _showHeatmap = !_showHeatmap;
                          });
                        },
                        icon: Icon(
                          _showHeatmap ? Icons.close : Icons.grid_on,
                          color: const Color(0xFFDBDBDB),
                        ),
                      ),
                    ],
                  ),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: DragToMoveArea(child: SizedBox.expand()),
                    ),
                  ),
                  if (!_showHeatmap)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () {
                            getpreviousmonth();
                          },
                          icon: Icon(
                            Icons.arrow_back_ios,
                            color: Color(0xFFDBDBDB),
                          ),
                        ),
                        Text(
                          "${months[currentmonth - 1].toUpperCase()} $currentyear",
                          style: GoogleFonts.jetBrainsMono(
                            textStyle: TextStyle(
                              color: Color(0xFFDBDBDB),
                              fontSize: 20,
                            ),
                          ),
                        ),
                        IconButton(
                          onPressed: () {
                            getnextmonth();
                          },
                          icon: Icon(
                            Icons.arrow_forward_ios,
                            color: Color(0xFFDBDBDB),
                          ),
                        ),
                      ],
                    ),
                  Expanded(
                    child: SizedBox(
                      height: 48,
                      child: DragToMoveArea(child: SizedBox.expand()),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!_showHeatmap)
                        IconButton(
                          tooltip: "Edit Month",
                          onPressed: () {
                            showEditHabitMonthDialog(
                              context,
                              currentmonth,
                              currentyear,
                              () {
                                loadHabitData(currentmonth, currentyear);
                              },
                            );
                          },
                          icon: Icon(Icons.edit, color: Color(0xFFDBDBDB)),
                        ),
                      IconButton(
                        tooltip: "Settings",
                        onPressed: () {
                          showSettingsDialog(
                            context,
                            onDataImported: () {
                              loadHabitData(currentmonth, currentyear);
                            },
                          );
                        },
                        icon: const Icon(
                          Icons.settings,
                          color: Color(0xFFDBDBDB),
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFDAD3BE)),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _buildWindowControl(
                                tooltip: 'Minimize',
                                icon: Icons.remove_rounded,
                                onPressed: () => windowManager.minimize(),
                              ),
                              _buildWindowControl(
                                tooltip: _isMaximized ? 'Restore' : 'Maximize',
                                icon: _isMaximized
                                    ? Icons.filter_none_rounded
                                    : Icons.crop_square_rounded,
                                onPressed: () => _isMaximized
                                    ? windowManager.unmaximize()
                                    : windowManager.maximize(),
                              ),
                              _buildWindowControl(
                                tooltip: 'Close',
                                icon: Icons.close_rounded,
                                hoverColor: Colors.red,
                                onPressed: () => windowManager.close(),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Expanded(
                child: _showHeatmap
                    ? const HabitHeatmapView()
                    : DataTable2(
                        scrollController: _scrollController,
                        columnSpacing: 12,
                        horizontalMargin: 12,
                        minWidth: 600,
                        columns: [
                          DataColumn(
                            label: Text(
                              'Day',
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                          ...habitTypes.map(
                            (habit) => DataColumn(
                              label: Text(
                                habit['habit'].toString().toUpperCase(),
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                        rows: habitRows.asMap().entries.map((entry) {
                          final rowIndex = entry.key;
                          final row = entry.value;
                          return DataRow(
                            cells: [
                              DataCell(
                                Text(
                                  row['day'].toString(),
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                              ...habitTypes.map((habit) {
                                final habitId = habit['id'] as int;
                                final habitKey = habitId.toString();
                                return DataCell(
                                  Checkbox(
                                    value: row[habitKey] == 1,
                                    onChanged: (bool? value) async {
                                      if (value == null) return;
                                      final previousValue = row[habitKey];
                                      setState(() {
                                        row[habitKey] = value ? 1 : 0;
                                      });
                                      try {
                                        await dbHelper.updateHabitScore(
                                          row['day'] as int,
                                          currentmonth,
                                          currentyear,
                                          habitId,
                                          value ? 1 : 0,
                                        );
                                      } catch (error) {
                                        if (!context.mounted) return;
                                        setState(() {
                                          row[habitKey] = previousValue;
                                        });
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not save habit: $error',
                                            ),
                                          ),
                                        );
                                      }
                                    },
                                    activeColor: Colors.white,
                                    checkColor: Color(0xFF2C3930),
                                    side: const BorderSide(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                );
                              }),
                            ],
                            color: WidgetStateProperty.resolveWith((states) {
                              if (rowIndex == DateTime.now().day - 1 &&
                                  currentmonth == DateTime.now().month &&
                                  currentyear == DateTime.now().year) {
                                return Color(0xFFDAD3BE).withOpacity(0.2);
                              }
                              if (rowIndex % 2 == 0) {
                                return Color(0xFF2C3930);
                              }
                              return Colors.transparent;
                            }),
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: "Edit Global Habit",
        onPressed: () {
          showAddHabitDialog(
            context,
            onChanged: () => loadHabitData(currentmonth, currentyear),
          );
        },
        backgroundColor: Color(0xFFDAD3BE),
        child: const Icon(Icons.add),
      ),
    );
  }

  getpreviousmonth() {
    late int month;
    late int year;
    setState(() {
      if (currentmonth != 1) {
        currentmonth -= 1;
      } else {
        currentmonth = 12;
        currentyear -= 1;
      }
      month = currentmonth;
      year = currentyear;
    });
    loadHabitData(month, year);
  }

  getnextmonth() {
    late int month;
    late int year;
    setState(() {
      if (currentmonth != 12) {
        currentmonth += 1;
      } else {
        currentmonth = 1;
        currentyear += 1;
      }
      month = currentmonth;
      year = currentyear;
    });
    loadHabitData(month, year);
  }

  Widget _buildWindowControl({
    required String tooltip,
    required IconData icon,
    required VoidCallback onPressed,
    Color hoverColor = const Color(0xFF3F4D43),
  }) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18, weight: 700),
      style: IconButton.styleFrom(
        fixedSize: const Size(32, 32),
        padding: EdgeInsets.zero,
        foregroundColor: Colors.white,
        backgroundColor: Colors.transparent,
        hoverColor: hoverColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
    );
  }
}
