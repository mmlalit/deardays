import 'package:flutter/foundation.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Checklist Task Definition (static metadata)
// ─────────────────────────────────────────────────────────────────────────────

class ChecklistTaskDef {
  final String id;
  final String title;
  final String subtitle;
  final String route;

  const ChecklistTaskDef({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.route,
  });
}

const kChecklistTaskDefs = [
  ChecklistTaskDef(
    id: 'first_memory',
    title: 'Record your first memory',
    subtitle: 'Speak or write about your day',
    route: '/record',
  ),
  ChecklistTaskDef(
    id: 'add_photo',
    title: 'Add a photo to a memory',
    subtitle: 'A picture makes it richer',
    route: '/photo-entry',
  ),
  ChecklistTaskDef(
    id: 'create_chapter',
    title: 'Create a chapter',
    subtitle: 'Organise memories into albums',
    route: '/book',
  ),
  ChecklistTaskDef(
    id: 'read_book',
    title: 'Read your life book',
    subtitle: 'See your story as a book',
    route: '/book-reader',
  ),
  ChecklistTaskDef(
    id: 'explore_themes',
    title: 'Explore your memories',
    subtitle: 'Discover memories by theme',
    route: '/explore',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// ChecklistTask (runtime state with completion timestamp)
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class ChecklistTask {
  final String id;
  final String title;
  final String subtitle;
  final String route;
  final DateTime? completedAt;

  const ChecklistTask({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.route,
    this.completedAt,
  });

  bool get isCompleted => completedAt != null;

  ChecklistTask copyWith({DateTime? completedAt}) {
    return ChecklistTask(
      id: id,
      title: title,
      subtitle: subtitle,
      route: route,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  static ChecklistTask fromDef(ChecklistTaskDef def, {DateTime? completedAt}) {
    return ChecklistTask(
      id: def.id,
      title: def.title,
      subtitle: def.subtitle,
      route: def.route,
      completedAt: completedAt,
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'completedAt': completedAt?.toIso8601String(),
      };

  factory ChecklistTask.fromMap(Map<String, dynamic> map, ChecklistTaskDef def) {
    return ChecklistTask(
      id: def.id,
      title: def.title,
      subtitle: def.subtitle,
      route: def.route,
      completedAt: map['completedAt'] != null
          ? DateTime.parse(map['completedAt'] as String)
          : null,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// OnboardingState
// ─────────────────────────────────────────────────────────────────────────────

@immutable
class OnboardingState {
  final bool sampleMemorySeeded;
  final bool wizardCompleted;
  final bool checklistDismissed;
  final List<ChecklistTask> checklistTasks;
  final Set<String> tooltipsShown;
  final Set<String> unvisitedTabs;
  final bool phase2Completed;
  final int? phase2Step;

  const OnboardingState({
    this.sampleMemorySeeded = false,
    this.wizardCompleted = false,
    this.checklistDismissed = false,
    this.checklistTasks = const [],
    this.tooltipsShown = const {},
    this.unvisitedTabs = const {},
    this.phase2Completed = false,
    this.phase2Step,
  });

  bool get allTasksComplete =>
      checklistTasks.isNotEmpty && checklistTasks.every((t) => t.isCompleted);

  int get completedTaskCount =>
      checklistTasks.where((t) => t.isCompleted).length;

  /// Returns a fully-completed state for use in tests.
  factory OnboardingState.completed() {
    return OnboardingState(
      sampleMemorySeeded: true,
      wizardCompleted: true,
      checklistDismissed: true,
      checklistTasks: kChecklistTaskDefs
          .map((def) =>
              ChecklistTask.fromDef(def, completedAt: DateTime(2026, 1, 1)))
          .toList(),
      tooltipsShown: const {
        'timeline_first',
        'explore_first',
        'chapters_tab',
        'book_story',
        'chapter_fab',
      },
      unvisitedTabs: const {},
      phase2Completed: true,
      phase2Step: null,
    );
  }

  OnboardingState copyWith({
    bool? sampleMemorySeeded,
    bool? wizardCompleted,
    bool? checklistDismissed,
    List<ChecklistTask>? checklistTasks,
    Set<String>? tooltipsShown,
    Set<String>? unvisitedTabs,
    bool? phase2Completed,
    int? phase2Step,
    bool clearPhase2Step = false,
  }) {
    return OnboardingState(
      sampleMemorySeeded: sampleMemorySeeded ?? this.sampleMemorySeeded,
      wizardCompleted: wizardCompleted ?? this.wizardCompleted,
      checklistDismissed: checklistDismissed ?? this.checklistDismissed,
      checklistTasks: checklistTasks ?? this.checklistTasks,
      tooltipsShown: tooltipsShown ?? this.tooltipsShown,
      unvisitedTabs: unvisitedTabs ?? this.unvisitedTabs,
      phase2Completed: phase2Completed ?? this.phase2Completed,
      phase2Step: clearPhase2Step ? null : (phase2Step ?? this.phase2Step),
    );
  }
}
