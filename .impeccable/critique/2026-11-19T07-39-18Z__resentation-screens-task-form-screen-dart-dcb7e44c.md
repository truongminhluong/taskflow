---
target: recurring task UI in task form
total_score: 26
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
target_identity: "file:/Users/truongminhluongjr/Documents/task_flow_v2/lib/features/tasks/presentation/screens/task_form_screen.dart"
target_fingerprint: "sha256:26b2a64df23fdfba0c8aa26a845573c9f91c618cd634407eaf7c543da6200928"
target_path: /Users/truongminhluongjr/Documents/task_flow_v2/lib/features/tasks/presentation/screens/task_form_screen.dart
timestamp: 2026-11-19T07-39-18Z
slug: resentation-screens-task-form-screen-dart-dcb7e44c
---
# Recurring UI critique

## Design health score

| Heuristic | Score |
|---|---:|
| Visibility of system status | 3/4 |
| Match with real world | 3/4 |
| User control and freedom | 3/4 |
| Consistency and standards | 3/4 |
| Error prevention | 2/4 |
| Recognition rather than recall | 3/4 |
| Flexibility and efficiency | 3/4 |
| Aesthetic and minimalist design | 3/4 |
| Error recovery | 2/4 |
| Help and documentation | 1/4 |
| Total | 26/40 |

## Design specificity

The recurring UI fits TaskFlow's calm, practical task-form language and uses the existing spacing, color, bottom-sheet, chip, and radio patterns. It is usable, but the duplicated weekly choices and nested sheets make it feel more like a generic configuration flow than a deliberately authored reminder experience.

## Strengths

- The parent form shows the current repeat summary.
- Repeat rows have clear selected styling and adequate touch targets.
- Weekday, end-date, and occurrence controls are progressively revealed.

## Priority issues

- [P1] “Hằng tuần” and “Ngày trong tuần” create the same weekly config; remove one or define a real difference.
- [P1] The nested sheet flow makes users move from picker to editor to form; use one clearly titled editor with Cancel/Save.
- [P1] There is no live natural-language preview combining interval, weekdays, and end condition.
- [P2] Numeric validation is delayed and interval is silently clamped; show inline constraints and errors.
- [P2] Monthly anchoring to the due-date day is implicit; explain it as “Ngày 15 mỗi tháng” or expose the day choice.

## Accessibility and edge cases

The repeat row combines an InkWell and a separate Radio interaction, which can expose duplicate actions to assistive technologies. The end-date and occurrence-count controls also use different interaction patterns without explaining their effect.

## Detector

The Impeccable detector returned no deterministic findings for the target file.
