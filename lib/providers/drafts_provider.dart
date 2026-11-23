import 'dart:async';
import 'package:flutter/foundation.dart';
import 'async_session_notifier.dart';
import '../models/order_draft.dart';
import '../repositories/local_repository.dart';

class DraftsProvider with ChangeNotifier, AsyncSessionNotifier {
  final LocalRepository _localRepository;

  List<OrderDraft> _drafts = [];
  bool _isLoading = false;
  SaveStatus _saveStatus = SaveStatus.none;
  String? _error;
  Timer? _debounceTimer;
  Future<void> _writeQueue = Future<void>.value();

  DraftsProvider(this._localRepository);

  List<OrderDraft> get drafts => _drafts;
  bool get isLoading => _isLoading;
  SaveStatus get saveStatus => _saveStatus;
  String? get error => _error;

  Future<T> _queueWrite<T>(Future<T> Function() operation) {
    final scope = _localRepository.draftScope;
    final result = _writeQueue.then((_) {
      if (_localRepository.draftScope != scope) {
        throw StateError('تغير الحساب قبل حفظ المسودة');
      }
      return operation();
    });
    _writeQueue =
        result.then<void>((_) {}, onError: (Object _, StackTrace __) {});
    return result;
  }

  Future<void> loadDrafts() async {
    _isLoading = true;
    notifyListeners();
    try {
      _drafts = await _localRepository.getAllDrafts();
      _error = null;
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<int> saveDraft(OrderDraft draft, {bool immediate = true}) async {
    if (immediate) {
      _debounceTimer?.cancel();
      _saveStatus = SaveStatus.saving;
      notifyListeners();
      try {
        final id = await _queueWrite(() => _localRepository.saveDraft(draft));
        _saveStatus = SaveStatus.saved;
        await loadDrafts();
        return id;
      } catch (e) {
        _saveStatus = SaveStatus.error;
        if (e.toString().contains('DISK_FULL')) {
          _error = 'المساحة ممتلئة، لا يمكن حفظ المسودة';
        } else {
          _error = e.toString();
        }
        notifyListeners();
        rethrow;
      }
    } else {
      // Auto-save logic with debounce
      _saveStatus = SaveStatus.saving;
      notifyListeners();
      _debounceTimer?.cancel();
      final scope = _localRepository.draftScope;
      _debounceTimer = Timer(const Duration(seconds: 2), () async {
        try {
          if (_localRepository.draftScope != scope) {
            throw StateError('تغير الحساب قبل حفظ المسودة');
          }
          await _queueWrite(() => _localRepository.saveDraft(draft));
          _saveStatus = SaveStatus.saved;
          await loadDrafts();
        } catch (e) {
          _saveStatus = SaveStatus.error;
          _error = e.toString();
          notifyListeners();
        }
      });
      return draft.id ?? 0;
    }
  }

  Future<void> deleteDraft(int id) async {
    _debounceTimer?.cancel();
    _error = null;
    try {
      await _queueWrite(() => _localRepository.deleteDraft(id));
      await loadDrafts();
    } catch (e) {
      _error = e.toString();
      notifyListeners();
    }
  }

  Future<void> updateNote(int id, String note) async {
    _saveStatus = SaveStatus.saving;
    notifyListeners();
    try {
      await _localRepository.updateDraftNote(id, note);
      _saveStatus = SaveStatus.saved;
      // Partial update local list to avoid full reload
      final index = _drafts.indexWhere((d) => d.id == id);
      if (index != -1) {
        final old = _drafts[index];
        _drafts[index] = OrderDraft(
          id: old.id,
          customerId: old.customerId,
          customerName: old.customerName,
          items: old.items,
          updatedAt: DateTime.now(),
          note: note,
          currency: old.currency,
          customTitle: old.customTitle,
          clientRequestId: old.clientRequestId,
        );
      }
    } catch (e) {
      _saveStatus = SaveStatus.error;
    } finally {
      notifyListeners();
    }
  }

  void resetStatus() {
    _saveStatus = SaveStatus.none;
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}
