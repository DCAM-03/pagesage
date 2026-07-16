# PageSage

PageSage is a local-first, cross-platform intelligent reader for EPUB and PDF.

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
- EPUB rendering with epub.js
- PDF rendering with PDF.js
- SQLite plus FTS5 for local library data and full-text search

Deferred:

- MOBI/AZW import and Calibre-based conversion

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
