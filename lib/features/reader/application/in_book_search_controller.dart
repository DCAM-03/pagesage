import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../domain/books/reading_position.dart';
import '../../../domain/search/search_models.dart';

final class InBookSearchState {
  const InBookSearchState({
    this.query = '',
    this.results = const [],
    this.selectedIndex = -1,
    this.isSearching = false,
    this.error,
  });

  final String query;
  final List<SearchResult> results;
  final int selectedIndex;
  final bool isSearching;
  final String? error;

  SearchResult? get selectedResult {
    final index = selectedIndex;
    if (index < 0 || index >= results.length) {
      return null;
    }
    return results[index];
  }

  InBookSearchState copyWith({
    String? query,
    List<SearchResult>? results,
    int? selectedIndex,
    bool? isSearching,
    Object? error = _sentinel,
  }) {
    return InBookSearchState(
      query: query ?? this.query,
      results: results ?? this.results,
      selectedIndex: selectedIndex ?? this.selectedIndex,
      isSearching: isSearching ?? this.isSearching,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }
}

const Object _sentinel = Object();

final class InBookSearchController extends ChangeNotifier {
  InBookSearchController({
    required this.bookId,
    required this.repository,
    this.currentLocator,
    this.debounceDuration = const Duration(milliseconds: 350),
  });

  final String bookId;
  final SearchRepository repository;
  final ReadingLocator? currentLocator;
  final Duration debounceDuration;
  Timer? _debounceTimer;
  int _searchGeneration = 0;

  InBookSearchState _state = const InBookSearchState();

  InBookSearchState get state => _state;

  void updateQuery(String value) {
    final query = value.trim();
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      clear();
      return;
    }
    _searchGeneration++;
    _setState(InBookSearchState(query: query, isSearching: true));
    _debounceTimer = Timer(debounceDuration, () {
      unawaited(searchNow(query));
    });
  }

  Future<void> searchNow([String? value]) async {
    final query = (value ?? _state.query).trim();
    _debounceTimer?.cancel();
    if (query.isEmpty) {
      clear();
      return;
    }

    final generation = ++_searchGeneration;
    _setState(_state.copyWith(query: query, isSearching: true, error: null));
    try {
      final response = await repository.searchResponse(
        SearchQuery(
          query: query,
          bookId: bookId,
          typeFilters: const {SearchResultType.content},
          requestEpoch: generation,
        ),
      );
      if (generation != _searchGeneration ||
          response.requestEpoch != generation) {
        return;
      }
      _setState(
        _state.copyWith(
          results: response.results,
          selectedIndex: _initialSelectedIndex(response.results),
          isSearching: false,
          error: null,
        ),
      );
    } on Object {
      if (generation != _searchGeneration) {
        return;
      }
      _setState(
        _state.copyWith(
          results: const [],
          selectedIndex: -1,
          isSearching: false,
          error: '搜索失败',
        ),
      );
    }
  }

  Future<void> retry() => searchNow();

  void clear() {
    _debounceTimer?.cancel();
    _searchGeneration++;
    _setState(const InBookSearchState());
  }

  void select(int index) {
    if (index < 0 || index >= _state.results.length) {
      return;
    }
    _setState(_state.copyWith(selectedIndex: index));
  }

  void selectNext() {
    if (_state.results.isEmpty) {
      return;
    }
    final next = (_state.selectedIndex + 1) % _state.results.length;
    select(next);
  }

  void selectPrevious() {
    if (_state.results.isEmpty) {
      return;
    }
    final previous =
        (_state.selectedIndex - 1 + _state.results.length) %
        _state.results.length;
    select(previous);
  }

  int _initialSelectedIndex(List<SearchResult> results) {
    if (results.isEmpty) {
      return -1;
    }
    final currentKey = _locatorSortKey(currentLocator);
    if (currentKey == null) {
      return 0;
    }
    var bestIndex = 0;
    var bestForwardDistance = double.infinity;
    var bestAbsoluteDistance = double.infinity;
    for (var index = 0; index < results.length; index += 1) {
      final key = _locatorSortKey(results[index].locator);
      if (key == null) {
        continue;
      }
      final forwardDistance = key - currentKey;
      final absoluteDistance = forwardDistance.abs();
      if (forwardDistance >= 0 && forwardDistance < bestForwardDistance) {
        bestForwardDistance = forwardDistance;
        bestIndex = index;
      } else if (bestForwardDistance == double.infinity &&
          absoluteDistance < bestAbsoluteDistance) {
        bestAbsoluteDistance = absoluteDistance;
        bestIndex = index;
      }
    }
    return bestIndex;
  }

  double? _locatorSortKey(ReadingLocator? locator) {
    if (locator == null) {
      return null;
    }
    return switch (locator.type) {
      ReadingLocatorType.pdf => (locator.page ?? 1).toDouble(),
      ReadingLocatorType.epub || ReadingLocatorType.markdown =>
        ((locator.chapterIndex ?? 0) * 1000000000 +
                (locator.chapterOffset ?? 0))
            .toDouble(),
    };
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _searchGeneration++;
    super.dispose();
  }

  void _setState(InBookSearchState value) {
    _state = value;
    notifyListeners();
  }
}
