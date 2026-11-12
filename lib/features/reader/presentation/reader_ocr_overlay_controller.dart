import 'package:flutter/widgets.dart';

typedef OcrOverlayBlocks = List<Map<String, Object?>>;
typedef OcrOverlay = ({int page, OcrOverlayBlocks blocks});

/// The overlay currently sent to the PDF renderer.
@immutable
final class ReaderOcrOverlayState {
  const ReaderOcrOverlayState({
    required this.token,
    this.page,
    this.blocks = const <Map<String, Object?>>[],
  });

  static const empty = ReaderOcrOverlayState(token: 0);

  /// Bumped for every overlay so the renderer knows to repaint.
  final int token;
  final int? page;
  final OcrOverlayBlocks blocks;
}

/// Owns the OCR overlays painted over PDF pages.
///
/// Recognition and cache lookup stay in the reader's application layer; this
/// controller only sequences what the renderer should show, including the
/// double-page queue and the "already restored in this session" set. Keeping
/// it out of the page means the overlay token cannot drift away from the
/// blocks it belongs to.
final class ReaderOcrOverlayController extends ChangeNotifier {
  ReaderOcrOverlayState _state = ReaderOcrOverlayState.empty;
  final List<OcrOverlay> _pending = <OcrOverlay>[];
  final Set<int> _restoredPages = <int>{};
  int _restoreGeneration = 0;
  bool _disposed = false;
  bool _frameScheduled = false;

  ReaderOcrOverlayState get state => _state;

  /// Starts a cache lookup pass. A newer pass invalidates an older one, so a
  /// slow disk read cannot paint a page the reader has already left.
  int beginRestore() => ++_restoreGeneration;

  bool isRestoreCurrent(int generation) =>
      !_disposed && generation == _restoreGeneration;

  bool isRestored(int page) => _restoredPages.contains(page);

  /// Shows the first overlay now and the rest one per frame.
  ///
  /// A double-page spread has two overlays but the renderer paints one page
  /// per token; queueing the second avoids replacing the first before it is
  /// drawn.
  void show(Iterable<OcrOverlay> overlays) {
    if (_disposed) {
      return;
    }
    final visible = overlays
        .where((overlay) => overlay.blocks.isNotEmpty)
        .toList(growable: false);
    if (visible.isEmpty) {
      return;
    }
    for (final overlay in visible) {
      _pending.removeWhere((pending) => pending.page == overlay.page);
      _pending.add(overlay);
    }
    if (!_frameScheduled) {
      _apply(_pending.removeAt(0));
    }
    _schedulePending();
  }

  void _schedulePending() {
    if (_frameScheduled || _disposed) {
      return;
    }
    _frameScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _frameScheduled = false;
      if (_disposed || _pending.isEmpty) {
        return;
      }
      _apply(_pending.removeAt(0));
      _schedulePending();
    });
    // A listener normally schedules this frame by rebuilding, but the queue
    // must also drain when nothing is listening yet.
    WidgetsBinding.instance.scheduleFrame();
  }

  void _apply(OcrOverlay overlay) {
    _restoredPages.add(overlay.page);
    _state = ReaderOcrOverlayState(
      token: _state.token + 1,
      page: overlay.page,
      blocks: overlay.blocks,
    );
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _pending.clear();
    super.dispose();
  }
}
