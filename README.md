# iosmacs (Flutter version)

`iosmacs` is an experiment to run real GNU Emacs on iOS, iPadOS, and macOS as a cross-platform Flutter application.

Flutter owns the cross-platform application shell and terminal surface, while platform backends handle running/embedding GNU Emacs and connecting terminal bytes.

> [!NOTE]
> The original native Swift/Objective-C implementation has been moved to the [999_old/](file:///Users/seijiro/by-llms/iosmacs/999_old) directory and marked as obsolete.

## Documentation

- [ARCHITECTURE.md](file:///Users/seijiro/by-llms/iosmacs/ARCHITECTURE.md) - High-level shape, backend specifications, and implementation details.
- [PLAN.md](file:///Users/seijiro/by-llms/iosmacs/PLAN.md) - Project timeline and implementation roadmap.
- [LOG.md](file:///Users/seijiro/by-llms/iosmacs/LOG.md) - Workstream logs and diagnostic history.

## Getting Started

To prepare development tools, make sure you have Flutter SDK installed, then bootstrap the project:

```sh
make bootstrap
```

Common make tasks:
- `make flutter-doctor`: Check environment health.
- `make flutter-analyze`: Run static analysis.
- `make flutter-fake-smoke`: Run unit/widget tests with a fake backend.

For details on building platform-specific runtimes (like macOS, iOS, or Android NDK), see `ARCHITECTURE.md`.
