import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_model.dart';
import 'package:task_flow_v2/features/tasks/data/models/task_page_model.dart';

import 'task_provider.dart';

final taskScreenTaskProvider =
    NotifierProvider<TaskScreenTaskNotifier, TaskScreenTaskState>(
      TaskScreenTaskNotifier.new,
    );

final class TaskScreenTaskState {
  const TaskScreenTaskState({
    this.items = const [],
    this.totalItems = 0,
    this.isLoading = false,
    this.isLoadingMore = false,
    this.hasNextPage = false,
    this.completedItems = const [],
    this.completedTotalItems = 0,
    this.isLoadingCompleted = false,
    this.completedHasNextPage = false,
    this.completedLoaded = false,
    this.errorMessage,
    this.loadMoreErrorMessage,
  });

  final List<TaskModel> items;
  final int totalItems;
  final bool isLoading;
  final bool isLoadingMore;
  final bool hasNextPage;
  final List<TaskModel> completedItems;
  final int completedTotalItems;
  final bool isLoadingCompleted;
  final bool completedHasNextPage;
  final bool completedLoaded;
  final String? errorMessage;
  final String? loadMoreErrorMessage;

  TaskScreenTaskState copyWith({
    List<TaskModel>? items,
    int? totalItems,
    bool? isLoading,
    bool? isLoadingMore,
    bool? hasNextPage,
    List<TaskModel>? completedItems,
    int? completedTotalItems,
    bool? isLoadingCompleted,
    bool? completedHasNextPage,
    bool? completedLoaded,
    String? errorMessage,
    bool clearError = false,
    String? loadMoreErrorMessage,
    bool clearLoadMoreError = false,
  }) {
    return TaskScreenTaskState(
      items: items ?? this.items,
      totalItems: totalItems ?? this.totalItems,
      isLoading: isLoading ?? this.isLoading,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      hasNextPage: hasNextPage ?? this.hasNextPage,
      completedItems: completedItems ?? this.completedItems,
      completedTotalItems: completedTotalItems ?? this.completedTotalItems,
      isLoadingCompleted: isLoadingCompleted ?? this.isLoadingCompleted,
      completedHasNextPage: completedHasNextPage ?? this.completedHasNextPage,
      completedLoaded: completedLoaded ?? this.completedLoaded,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      loadMoreErrorMessage: clearLoadMoreError
          ? null
          : loadMoreErrorMessage ?? this.loadMoreErrorMessage,
    );
  }
}

final class TaskScreenTaskNotifier extends Notifier<TaskScreenTaskState> {
  static const _pageSize = 20;

  _TaskScreenQuery? _query;
  int _generation = 0;
  int _pendingPage = 1;
  int _completedPage = 1;
  bool _isMixedQuery = false;
  bool _isCompletedPhase = false;
  bool _pendingHasNext = false;
  bool _completedHasNext = false;
  bool _singleGroupHasNext = false;
  bool _completedLoaded = false;
  List<TaskModel> _pendingItems = const [];
  List<TaskModel> _completedItems = const [];
  Future<void>? _loadMoreInFlight;

  @override
  TaskScreenTaskState build() {
    ref.watch(taskRepositoryProvider);
    return const TaskScreenTaskState();
  }

  Future<void> loadInitial({
    String? search,
    bool? isCompleted,
    TaskPriority? priority,
    String? dueFrom,
    String? dueBefore,
  }) {
    final query = _TaskScreenQuery(
      search: search?.trim().isEmpty == true ? null : search?.trim(),
      isCompleted: isCompleted,
      priority: priority,
      dueFrom: dueFrom,
      dueBefore: dueBefore,
    );
    _query = query;
    final generation = ++_generation;
    _loadMoreInFlight = null;
    _pendingPage = 1;
    _completedPage = 1;
    _isMixedQuery = isCompleted == null;
    _isCompletedPhase = isCompleted == true;
    _pendingHasNext = false;
    _completedHasNext = false;
    _singleGroupHasNext = false;
    _pendingItems = const [];
    _completedItems = const [];
    _completedLoaded = false;

    state = const TaskScreenTaskState(isLoading: true);
    return _performInitialLoad(query, generation);
  }

  Future<void> reload() {
    final query = _query;
    if (query == null) return Future<void>.value();

    return loadInitial(
      search: query.search,
      isCompleted: query.isCompleted,
      priority: query.priority,
      dueFrom: query.dueFrom,
      dueBefore: query.dueBefore,
    );
  }

  Future<void> loadMore() {
    final inFlight = _loadMoreInFlight;
    if (inFlight != null) return inFlight;
    if (state.isLoading || !state.hasNextPage || _query == null) {
      return Future<void>.value();
    }

    final generation = _generation;
    state = state.copyWith(isLoadingMore: true, clearLoadMoreError: true);
    final load = _performLoadMore(generation);
    _loadMoreInFlight = load;
    return load.whenComplete(() {
      if (identical(_loadMoreInFlight, load)) _loadMoreInFlight = null;
    });
  }

  Future<void> loadCompletedGroup() async {
    if (_completedLoaded || state.isLoadingCompleted || _query == null) return;
    final generation = _generation;
    state = state.copyWith(isLoadingCompleted: true, clearLoadMoreError: true);
    try {
      final page = await _fetchPage(_query!, page: 1, isCompleted: true);
      if (generation != _generation) return;
      _completedItems = page.items;
      _completedPage = 1;
      _completedHasNext = page.hasNextPage;
      _completedLoaded = true;
      state = state.copyWith(
        completedItems: page.items,
        completedTotalItems: page.totalItems,
        completedHasNextPage: page.hasNextPage,
        completedLoaded: true,
        isLoadingCompleted: false,
      );
    } catch (error, stackTrace) {
      if (generation != _generation) return;
      debugPrint('Load completed TaskScreen tasks failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(
        isLoadingCompleted: false,
        loadMoreErrorMessage: 'Không thể tải công việc đã hoàn thành.',
      );
    }
  }

  Future<void> loadMoreCompleted() async {
    if (!_completedLoaded || !_completedHasNext || state.isLoadingCompleted) {
      return;
    }
    final generation = _generation;
    state = state.copyWith(isLoadingCompleted: true, clearLoadMoreError: true);
    try {
      final pageNumber = _completedPage + 1;
      final page = await _fetchPage(
        _query!,
        page: pageNumber,
        isCompleted: true,
      );
      if (generation != _generation) return;
      _completedPage = pageNumber;
      _completedHasNext = page.hasNextPage;
      _completedItems = [..._completedItems, ...page.items];
      state = state.copyWith(
        completedItems: _completedItems,
        completedHasNextPage: page.hasNextPage,
        isLoadingCompleted: false,
      );
    } catch (error, stackTrace) {
      if (generation != _generation) return;
      debugPrint('Load more completed TaskScreen tasks failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(
        isLoadingCompleted: false,
        loadMoreErrorMessage: 'Không thể tải thêm công việc đã hoàn thành.',
      );
    }
  }

  /// Reflects a checkbox change without moving the row in the current query.
  void updateTaskCompletionInPlace(String taskId, bool isCompleted) {
    TaskModel update(TaskModel task) =>
        task.id == taskId ? task.copyWith(isCompleted: isCompleted) : task;

    _pendingItems = _pendingItems.map(update).toList();
    _completedItems = _completedItems.map(update).toList();
    state = state.copyWith(
      items: state.items.map(update).toList(),
      completedItems: state.completedItems.map(update).toList(),
    );
  }

  Future<void> _performInitialLoad(
    _TaskScreenQuery query,
    int generation,
  ) async {
    try {
      if (query.isCompleted != null) {
        final page = await _fetchPage(
          query,
          page: 1,
          isCompleted: query.isCompleted,
        );
        if (generation != _generation) return;

        _singleGroupHasNext = page.hasNextPage;
        if (query.isCompleted == true) {
          _completedItems = page.items;
        } else {
          _pendingItems = page.items;
        }
        state = TaskScreenTaskState(
          items: page.items,
          totalItems: page.totalItems,
          hasNextPage: page.hasNextPage,
        );
        return;
      }

      final pendingPage = await _fetchPage(query, page: 1, isCompleted: false);
      if (generation != _generation) return;
      _pendingItems = pendingPage.items;
      _pendingHasNext = pendingPage.hasNextPage;
      _isCompletedPhase = false;
      state = TaskScreenTaskState(
        items: _pendingItems,
        totalItems: pendingPage.totalItems,
        hasNextPage: _pendingHasNext,
      );
    } catch (error, stackTrace) {
      if (generation != _generation) return;
      debugPrint('Load TaskScreen task page failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = const TaskScreenTaskState(
        errorMessage: 'Không thể tải danh sách công việc.',
      );
    }
  }

  Future<void> _performLoadMore(int generation) async {
    try {
      final query = _query!;
      if (_isMixedQuery && !_isCompletedPhase) {
        final nextPage = _pendingPage + 1;
        final result = await _fetchPage(
          query,
          page: nextPage,
          isCompleted: false,
        );
        if (generation != _generation) return;

        _pendingPage = nextPage;
        _pendingHasNext = result.hasNextPage;
        _pendingItems = [..._pendingItems, ...result.items];
        state = state.copyWith(
          items: _pendingItems,
          hasNextPage: _hasMixedNextPage,
          isLoadingMore: false,
          clearLoadMoreError: true,
        );
        return;
      }

      if (_isMixedQuery) {
        final nextPage = _completedPage + 1;
        final result = await _fetchPage(
          query,
          page: nextPage,
          isCompleted: true,
        );
        if (generation != _generation) return;

        _completedPage = nextPage;
        _completedHasNext = result.hasNextPage;
        _completedItems = [..._completedItems, ...result.items];
        state = state.copyWith(
          items: [..._pendingItems, ..._completedItems],
          hasNextPage: _completedHasNext,
          isLoadingMore: false,
          clearLoadMoreError: true,
        );
        return;
      }

      final nextPage = (_isCompletedPhase ? _completedPage : _pendingPage) + 1;
      final result = await _fetchPage(
        query,
        page: nextPage,
        isCompleted: query.isCompleted,
      );
      if (generation != _generation) return;

      if (_isCompletedPhase) {
        _completedPage = nextPage;
        _completedItems = [..._completedItems, ...result.items];
      } else {
        _pendingPage = nextPage;
        _pendingItems = [..._pendingItems, ...result.items];
      }
      _singleGroupHasNext = result.hasNextPage;
      state = state.copyWith(
        items: result.items.isEmpty
            ? state.items
            : [...state.items, ...result.items],
        hasNextPage: _singleGroupHasNext,
        isLoadingMore: false,
        clearLoadMoreError: true,
      );
    } catch (error, stackTrace) {
      if (generation != _generation) return;
      debugPrint('Load more TaskScreen tasks failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      state = state.copyWith(
        isLoadingMore: false,
        loadMoreErrorMessage: 'Không thể tải thêm công việc.',
      );
    }
  }

  Future<TaskPageModel> _fetchPage(
    _TaskScreenQuery query, {
    required int page,
    required bool? isCompleted,
  }) {
    return ref
        .read(taskRepositoryProvider)
        .getTaskPage(
          page: page,
          limit: _pageSize,
          search: query.search,
          isCompleted: isCompleted,
          priority: query.priority?.name,
          dueFrom: query.dueFrom,
          dueBefore: query.dueBefore,
          sort: isCompleted == true ? 'completedAtDesc' : 'dueDateAsc',
        );
  }

  bool get _hasMixedNextPage => _isCompletedPhase
      ? _completedHasNext
      : _pendingHasNext || _completedItems.isNotEmpty || _completedHasNext;
}

final class _TaskScreenQuery {
  const _TaskScreenQuery({
    required this.search,
    required this.isCompleted,
    required this.priority,
    required this.dueFrom,
    required this.dueBefore,
  });

  final String? search;
  final bool? isCompleted;
  final TaskPriority? priority;
  final String? dueFrom;
  final String? dueBefore;
}
