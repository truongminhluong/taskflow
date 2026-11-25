---
target: TaskFlow home overview screenshot
total_score: 29
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 1
target_identity: "file:/Users/truongminhluongjr/Documents/task_flow_v2/lib/features/tasks/presentation/screens/home_screen.dart"
target_fingerprint: "sha256:be062a6bae223b7aa27ad5aa7419a66e995807b48779c8818e0d65489b2f90f0"
target_path: /Users/truongminhluongjr/Documents/task_flow_v2/lib/features/tasks/presentation/screens/home_screen.dart
timestamp: 2026-11-18T03-26-31Z
slug: sks-presentation-screens-home-screen-dart-31143841
---
# TaskFlow Home Overview — Design Critique

Method: dual-agent (`/root/home_design_review` · `/root/home_detector_review`)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|---|---:|---|
| 1 | Visibility of System Status | 3 | Progress and unread count are visible. |
| 2 | Match System / Real World | 2 | Upcoming card says “Hôm nay” while showing Thursday 19; header says Wednesday 18 November 2026. |
| 3 | User Control and Freedom | 3 | Completion control and create action are recognizable. |
| 4 | Consistency and Standards | 3 | Priority appears both as a colored edge rail and a colored chip. |
| 5 | Error Prevention | 2 | Date/time contradiction can lead users to plan incorrectly. |
| 6 | Recognition Rather Than Recall | 4 | Today and upcoming work are separated clearly. |
| 7 | Flexibility and Efficiency | 3 | Progress is communicated in both a ring and percentage bar. |
| 8 | Aesthetic and Minimalist Design | 3 | Navy and blue are coherent, but several decorative layers compete with the task list. |
| 9 | Error Recovery | 3 | No failure state is visible in the concept screenshot. |
| 10 | Help and Documentation | 3 | Most controls use familiar visual conventions. |
| **Total** | | **29/40** | Correct date contradiction and reduce duplicated hierarchy. |

## Design Specificity Verdict

**LLM assessment:** The navy, blue accent, Vietnamese task language, and “Việc hôm nay / Sắp tới” grouping fit TaskFlow. The warm desk photography gives the concept a daily-planning mood, but glass panels and the large “Hôm nay” hero remain common productivity-app patterns. Concrete task timing and next actions are the best opportunity to make this screen feel more specific to TaskFlow.

**Screenshot-to-source mismatch:** The attachment appears to be a visual concept, not a capture of the current implementation. It shows a photo hero, logo, search control, floating navigation dock, circular progress ring, and horizontal progress bar. `home_screen.dart` currently renders a gradient background, greeting/date/notification header, and a compact horizontal progress widget with an illustration.

**Deterministic scan:** `.agents/skills/impeccable/scripts/impeccable detect --json lib/features/tasks/presentation/screens/home_screen.dart` returned `[]`. The detector does not evaluate the Flutter layout in the supplied screenshot. No browser review or overlay was used because this is a native iOS surface and the evidence is a user-provided image.

## Overall Impression

The concept is polished and easy to scan, but a date contradiction undermines trust in scheduling. The main opportunity is to simplify repeated progress and priority cues so the task list remains the screen's center of gravity.

## What's Working

- Greeting and date give the overview immediate time context.
- Today and upcoming work have clear section separation.
- The center create action is easy to find; completion controls are recognizable.

## Priority Issues

1. **[P1] The upcoming task contradicts the current date.** The header says Wednesday, November 18, 2026; the card says Thursday 19 but also “Hôm nay · 15:00.” Correct the relative-date label or verify the underlying date/time data. Suggested command: `$impeccable clarify`.
2. **[P2] Repeated visual cues compete with the task list.** “1/2” and “50%” communicate one ratio; the colored rail and chip both communicate priority. Keep one progress indicator as primary, reduce one priority cue, and let the task title and completion action lead. Suggested command: `$impeccable distill`.

## Persona Red Flags

- **First-time user:** The plus action is prominent, but the screenshot does not label it; provide a semantic label such as “Tạo công việc.”
- **Accessibility-focused user:** Small task metadata and reliance on color for priority are harder to scan; preserve text labels and check the layout at larger text sizes.

## Minor Observations

- The photo, greeting, large title, and header actions occupy substantial space above the list.
- The floating dock and central create button draw more attention than the task cards.
- The screenshot is visually distinct from the current `home_screen.dart`; confirm whether it is an intended redesign target before implementing its photographic hero and dock.
