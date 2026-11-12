# PageSage

PageSage is a local-first, cross-platform intelligent reader for EPUB, PDF, and Markdown.

## Documentation

Start here:

- [Project Overview](docs/00-overview.md)
- [Product Requirements](docs/01-product-requirements.md)
- [Feature Spec](docs/02-feature-spec.md)
- [Interaction Spec](docs/03-interaction-spec.md)
- [UI Design System](docs/04-ui-design-system.md)
- [Technical Architecture](docs/05-technical-architecture.md)
- [Data Model](docs/06-data-model.md)
- [Roadmap](docs/07-roadmap.md)
- [Assets Plan](docs/assets-plan.md)

Original planning draft:

- [Product Technical Document](docs/product-technical-document.md)

Recommended first implementation target:

- Flutter app for Android and Windows
- Flutter-native EPUB and Markdown rendering
- PDF rendering with `pdf_graphics` on Flutter Canvas
- SQLite plus FTS5 for local library data and full-text search

Deferred:

- MOBI/AZW import and Calibre-based conversion
- Cloud sync, accounts, online bookstores, and collaboration

A Markdown folder can be read in place as one book; other imports are copied
into the local library directory.

## Development

Common checks:

```powershell
flutter pub get
dart format .
flutter analyze
flutter test
flutter build windows
```

Android debug builds are configured, but the first `flutter build apk --debug`
run must download the Gradle distribution before it can complete.

## Linux beta builds

GitHub Actions runs analysis, the complete default test suite, and an x86_64
release build on Ubuntu 22.04. Each successful run uploads a `tar.gz` package and
SHA-256 checksum. Matching version tags also create a draft GitHub Release.

Build the same package locally:

```bash
bash tool/build_linux_release.sh
```

See [Linux installation and runtime requirements](docs/linux-distribution.md)
and [build and packaging implementation](docs/tasks/linux-distribution-2026-11-12.md).
