import 'package:data_table_2/data_table_2.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:habit_tracker/createhabitdialog.dart';
import 'package:habit_tracker/database_helper.dart';
import 'package:habit_tracker/edithabitmonthdialog.dart';

class HabitTracker extends StatefulWidget {
  const HabitTracker({super.key});

  @override
  State<HabitTracker> createState() => _HabitTrackerState();
}

class _HabitTrackerState extends State<HabitTracker> {
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
  List<String> habitColumns = [];
  List<Map<String, dynamic>> habitRows = [];
  bool _tableExists = true;
  final ScrollController _scrollController = ScrollController();
  final dbHelper = DatabaseHelper();

  Future<void> loadHabitData(month, year) async {
    final data = await dbHelper.getHabitData(month, year);
    if (mounted) {
      if (data['columns'].isEmpty) {
        setState(() {
          _tableExists = false;
          habitColumns = [];
          habitRows = [];
        });
      } else {
        setState(() {
          _tableExists = true;
          habitColumns = (data['columns'] as List)
              .skip(1)
              .map((item) => item['name'] as String)
              .toList();
          habitRows = (data['rows'] as List)
              .map((row) => Map<String, dynamic>.from(row))
              .toList();
        });
      }
    }
  }

  Future<void> createCompleteHabitTable(month, year) async {
    await dbHelper.createCompleteHabitTable(month, year);
    setState(() {
      currentmonth = month;
      currentyear = year;
      _tableExists = true;
    });
    loadHabitData(month, year);
  }

  Future<void> updateHabitScore(day, month, year, habit, score) async {
    await dbHelper.updateHabitScore(day, month, year, habit, score);
  }

  @override
  void initState() {
    super.initState();
    loadHabitData(currentmonth, currentyear);
  }

  @override
  void dispose() {
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
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                ],
              ),
              Expanded(
                child: _tableExists
                    ? DataTable2(
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
                          ...habitColumns.map(
                            (h) => DataColumn(
                              label: Text(
                                h.toString().toUpperCase(),
                                style: TextStyle(color: Colors.white),
                              ),
                            ),
                          ),
                        ],
                        rows: habitRows.map((h) {
                          final rowIndex = habitRows.indexOf(h);

                          return DataRow(
                            cells: h.keys.map((key) {
                              if (key == 'day') {
                                return DataCell(
                                  Text(
                                    h[key].toString(),
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                );
                              } else {
                                return DataCell(
                                  Checkbox(
                                    value: h[key] == 1,
                                    onChanged: (bool? value) {
                                      setState(() {
                                        habitRows[rowIndex][key] = value!
                                            ? 1
                                            : 0;
                                      });
                                      updateHabitScore(
                                        rowIndex + 1,
                                        currentmonth,
                                        currentyear,
                                        key,
                                        value! ? 1 : 0,
                                      );
                                    },
                                    activeColor: Colors.white,
                                    checkColor: Color(0xFF2C3930),
                                    side: const BorderSide(
                                      color: Colors.white,
                                      width: 2,
                                    ),
                                  ),
                                );
                              }
                            }).toList(),
                            color: WidgetStateProperty.resolveWith((states) {
                              if (rowIndex == DateTime.now().day - 1 &&
                                  currentmonth == DateTime.now().month) {
                                return Color(0xFFDAD3BE).withOpacity(0.2);
                              }
                              if (rowIndex % 2 == 0) {
                                return Color(0xFF2C3930);
                              }
                              return Colors.transparent;
                            }),
                          );
                        }).toList(),
                      )
                    : Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'TABLE FOR ${months[currentmonth - 1].toUpperCase()} $currentyear DOES NOT EXIST.',
                              style: GoogleFonts.jetBrainsMono(
                                color: Colors.white,
                                fontSize: 16,
                              ),
                            ),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () {
                                createCompleteHabitTable(
                                  currentmonth,
                                  currentyear,
                                );
                              },
                              child: Text(
                                '+ Create Table',
                                style: GoogleFonts.jetBrainsMono(
                                  color: Colors.white,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Color.fromARGB(
                                  255,
                                  34,
                                  44,
                                  38,
                                ), // button color
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                    4,
                                  ), // rounded corners
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.small(
        tooltip: "Edit Global Habit",
        onPressed: () {
          showAddHabitDialog(context);
        },
        backgroundColor: Color(0xFFDAD3BE),
        child: const Icon(Icons.add),
      ),
    );
  }

  getpreviousmonth() {
    setState(() {
      if (currentmonth != 1) {
        currentmonth -= 1;
      } else {
        currentmonth = 12;
        currentyear -= 1;
      }
      loadHabitData(currentmonth, currentyear);
    });
  }

  getnextmonth() {
    setState(() {
      if (currentmonth != 12) {
        currentmonth += 1;
      }
      else {
        currentmonth = 1;
        currentyear += 1;
      }
      loadHabitData(currentmonth, currentyear);
    });
  }
}
