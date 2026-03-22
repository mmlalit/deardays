import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive/hive.dart';
import 'onboarding_state.dart';

class OnboardingNotifier extends StateNotifier<OnboardingState> {
  static const _boxName = 'onboarding_prefs';
  static const _stateKey = 'state_v1';

  OnboardingNotifier() : super(const OnboardingState()) {
    _load();
  }

  /// Private constructor used by tests to skip Hive loading.
  OnboardingNotifier._completed() : super(OnboardingState.completed());

  /// Factory for widget/E2E tests — returns fully completed state without Hive.
  factory OnboardingNotifier.completed() => OnboardingNotifier._completed();

  Future<void> _load() async {
    try {
      final box = await Hive.openBox<dynamic>(_boxName);
      final raw = box.get(_stateKey) as Map<dynamic, dynamic>?;
      if (raw == null) {
        state = OnboardingState(
          checklistTasks:
              kChecklistTaskDefs.map((def) => ChecklistTask.fromDef(def)).toList(),
          unvisitedTabs: const {'timeline', 'chapters', 'explore'},
        );
        return;
      }
      state = _deserialize(Map<String, dynamic>.from(raw));
    } catch (_) {
      state = OnboardingState(
        checklistTasks:
            kChecklistTaskDefs.map((def) => ChecklistTask.fromDef(def)).toList(),
        unvisitedTabs: const {'timeline', 'chapters', 'explore'},
      );
    }
  }

  Future<void> _persist() async {
    try {
      final box = await Hive.openBox<dynamic>(_boxName);
      await box.put(_stateKey, _serialize(state));
    } catch (_) {}
  }

  Map<String, dynamic> _serialize(OnboardingState s) => {
        'sampleMemorySeeded': s.sampleMemorySeeded,
        'wizardCompleted': s.wizardCompleted,
        'checklistDismissed': s.checklistDismissed,
        'tooltipsShown': s.tooltipsShown.toList(),
        'unvisitedTabs': s.unvisitedTabs.toList(),
        'phase2Completed': s.phase2Completed,
        'checklistTasks': s.checklistTasks.map((t) => t.toMap()).toList(),
      };

  OnboardingState _deserialize(Map<String, dynamic> m) {
    final taskMaps = (m['checklistTasks'] as List<dynamic>?) ?? [];
    final taskMapById = <String, Map<String, dynamic>>{};
    for (final t in taskMaps) {
      final map = Map<String, dynamic>.from(t as Map);
      taskMapById[map['id'] as String] = map;
    }
    return OnboardingState(
      sampleMemorySeeded: m['sampleMemorySeeded'] as bool? ?? false,
      wizardCompleted: m['wizardCompleted'] as bool? ?? false,
      checklistDismissed: m['checklistDismissed'] as bool? ?? false,
      tooltipsShown: Set<String>.from(
          (m['tooltipsShown'] as List<dynamic>?) ?? []),
      unvisitedTabs: Set<String>.from(
          (m['unvisitedTabs'] as List<dynamic>?) ??
              ['timeline', 'chapters', 'explore']),
      phase2Completed: m['phase2Completed'] as bool? ?? false,
      checklistTasks: kChecklistTaskDefs
          .map((def) => ChecklistTask.fromMap(
              taskMapById[def.id] ?? {'id': def.id}, def))
          .toList(),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // Public mutation methods
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> markSampleMemorySeeded() async {
    state = state.copyWith(sampleMemorySeeded: true);
    await _persist();
  }

  Future<void> completeWizard() async {
    state = state.copyWith(wizardCompleted: true);
    await _persist();
  }

  Future<void> completeTask(String taskId) async {
    final updated = state.checklistTasks.map((t) {
      if (t.id == taskId && !t.isCompleted) {
        return t.copyWith(completedAt: DateTime.now());
      }
      return t;
    }).toList();
    state = state.copyWith(checklistTasks: updated);
    await _persist();
  }

  Future<void> markTooltipSeen(String tooltipId) async {
    state = state.copyWith(
        tooltipsShown: {...state.tooltipsShown, tooltipId});
    await _persist();
  }

  Future<void> markTabVisited(String tab) async {
    final remaining = Set<String>.from(state.unvisitedTabs)..remove(tab);
    state = state.copyWith(unvisitedTabs: remaining);
    await _persist();
  }

  Future<void> dismissChecklist() async {
    state = state.copyWith(checklistDismissed: true);
    await _persist();
  }

  Future<void> startPhase2() async {
    state = state.copyWith(phase2Step: 0);
    await _persist();
  }

  Future<void> advancePhase2() async {
    final next = (state.phase2Step ?? 0) + 1;
    if (next >= 6) {
      state = state.copyWith(phase2Completed: true, clearPhase2Step: true);
    } else {
      state = state.copyWith(phase2Step: next);
    }
    await _persist();
  }

  Future<void> skipPhase2() async {
    state = state.copyWith(phase2Completed: true, clearPhase2Step: true);
    await _persist();
  }

  Future<void> reset() async {
    try {
      final box = await Hive.openBox<dynamic>(_boxName);
      await box.clear();
    } catch (_) {}
    state = OnboardingState(
      checklistTasks:
          kChecklistTaskDefs.map((def) => ChecklistTask.fromDef(def)).toList(),
      unvisitedTabs: const {'timeline', 'chapters', 'explore'},
    );
  }
}
