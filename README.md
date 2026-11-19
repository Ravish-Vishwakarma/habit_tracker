<div align="center">

  <img src="icon.png" alt="Habit Tracker icon" width="160">

  # Habit Tracker

  **A simple local habit tracker with month-by-month check-ins and yearly activity heatmaps.**

  Create habits, track daily progress, customize each month, and keep a visual record of your consistency.

  [![Flutter](https://img.shields.io/badge/Flutter-desktop-02569B?logo=flutter)](https://flutter.dev)
  [![Dart](https://img.shields.io/badge/Dart-3.9+-0175C2?logo=dart)](https://dart.dev)
  [![SQLite](https://img.shields.io/badge/SQLite-local%20storage-003B57?logo=sqlite)](https://www.sqlite.org)
  [![License](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

</div>

## Features

| Monthly habit table | Flexible habit sets | Activity heatmaps | Data backups |
|:---:|:---:|:---:|:---:|
| Daily checkboxes for every day of the selected month | Start with global defaults, then customize habits month by month | GitHub-style yearly heatmap for each habit | Export and restore a complete SQLite backup |
| Checked items are saved by habit and date; unchecking removes the completion | Habits added to a month stay associated with that month | Navigate through previous years and resize the window | Import confirms before replacing existing data |

## Getting Started

### Requirements

- Flutter with Dart SDK `3.9.2` or newer
- For Windows builds, Visual Studio with the **Desktop development with C++** workload

### Run the app

```shell
flutter pub get
flutter run -d windows
```

### Build a Windows release

```shell
flutter build windows
```

The release executable is created under `build/windows/x64/runner/Release/`.

## Using Habit Tracker

1. Use the **+** button to create global habits. These are the default set for new months.
2. Use the month arrows to choose a month. Use **Edit Month** to add or remove habits for that month without changing other months.
3. Check a box to record a completed habit for that date. Unchecking it removes that completion from the database.
4. Select the heatmap button to view a separate activity calendar for each habit. Use the year arrows to review earlier activity; the close button returns to the table.
5. Open **Settings** to export a backup or import one. Importing replaces the current data after confirmation.

## Data Storage

Habit definitions, month-specific habit sets, and completion records are stored locally in SQLite. The database is saved as `habit_tracker.db` in the operating system's application-support directory. The app does not require an account or a network connection to track habits.

Backups are complete SQLite database files (`.db`). Keep exported backups somewhere safe; importing one replaces all current habits and completion history.

## Tech Stack

- [Flutter](https://flutter.dev) and [Dart](https://dart.dev)
- [SQLite](https://www.sqlite.org) via `sqflite_common_ffi`
- [file_picker](https://pub.dev/packages/file_picker) for backup file selection

## License

This project is distributed under the [MIT License](LICENSE).
