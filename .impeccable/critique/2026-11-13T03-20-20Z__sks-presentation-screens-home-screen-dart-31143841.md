---
target: Home state with tasks today and no upcoming tasks
total_score: 29
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 0
target_identity: "file:/Users/truongminhluongjr/Documents/task_flow_v2/lib/features/tasks/presentation/screens/home_screen.dart"
target_fingerprint: "sha256:3e3d3699d9767ffd014eb353a77bbc4bce8cb8f4939714dba7d7e642b0aa52f0"
target_path: /Users/truongminhluongjr/Documents/task_flow_v2/lib/features/tasks/presentation/screens/home_screen.dart
timestamp: 2026-11-13T03-20-20Z
slug: sks-presentation-screens-home-screen-dart-31143841
---
# ECC Critique — Home: có việc hôm nay, không có việc sắp tới

Method: dual-agent (A: /root/today_only_design · B: /root/today_only_mechanical)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|---|---:|---|
| 1 | Visibility of System Status | 3/4 | Progress card and empty upcoming note communicate current state. |
| 2 | Match System / Real World | 3/4 | “Việc hôm nay” and progress map to the user's daily planning task. |
| 3 | User Control and Freedom | 3/4 | Task detail, completion, all-tasks, and calendar actions are available. |
| 4 | Consistency and Standards | 3/4 | Task list and progress use consistent Home patterns; upcoming empty section is heavier than its content. |
| 5 | Error Prevention | 3/4 | Task cards expose schedule metadata and completion action. |
| 6 | Recognition Rather Than Recall | 3/4 | The user sees task details in each card; empty upcoming state is explicit. |
| 7 | Flexibility and Efficiency | 3/4 | Today's tasks are accessible directly; empty upcoming section adds a small amount of extra scanning. |
| 8 | Aesthetic and Minimalist Design | 2/4 | Empty upcoming section carries a heading, action, and vertical padding despite having no cards. |
| 9 | Error Recovery | 3/4 | Calendar and all-tasks routes remain available. |
| 10 | Help and Documentation | 3/4 | “Chưa có công việc sắp tới” is clear; “Xem lịch” may still be useful for planning. |
| **Total** | | **29/40** | **Mostly coherent; compact the empty upcoming state.** |

## Design Specificity Verdict

The state fits TaskFlow's daily planning use: a progress card leads into today's actionable list. Its product character is clear from Vietnamese copy and the blue overview card. The only mismatch is giving the empty upcoming group the same section weight as a populated list.

**LLM assessment:** Keep the progress card, “Việc hôm nay” heading, today's task cards, and “Tất cả công việc” action as the primary path. The later “Sắp tới” heading, “Xem lịch” action, and empty note create a hollow section after the main content.

**Deterministic scan:** `impeccable detect --json` on `home_screen.dart` returned `[]` (0 findings). The detector does not assess whether an empty section deserves its own heading and padding.

## Overall Impression

The main task path is clear and useful. The opportunity is to make the no-upcoming state quieter so today's work remains the visual focus.

## What's Working

- Progress overview immediately summarizes today's completion.
- Today's task list supports opening details and marking work complete.
- The all-tasks route remains available even when there are no future tasks.

## Priority Issues

- **[P2] Empty upcoming group gets too much visual weight:** after the task list, the screen always adds “Sắp tới”, “Xem lịch”, and a padded empty note. Collapse this into a compact one-line status after today's list; retain “Xem lịch” only if the calendar is still a useful next action in this state.
- **[P2] Calendar action's value is ambiguous here:** “Xem lịch” is useful if users can plan/add work from the calendar; otherwise it adds a low-value action beside an empty-state message. Confirm its current flow before retaining it.

## Persona Red Flags

- A user checking today's schedule may scan past the empty upcoming heading, but the explicit no-upcoming note prevents a false belief that tasks are still loading.
- A user planning future work may benefit from “Xem lịch”; removing it without checking calendar affordances could hide a useful route.

## Evidence and Limits

- Source: `home_screen.dart` and `HomeProgressOverview`.
- Detector: 0 findings.
- No screenshot of this exact state was supplied or captured; visual assessment uses source layout and spacing values. The previously supplied screenshot shows the opposite state (upcoming work, no work today).
- Target slug: `sks-presentation-screens-home-screen-dart-31143841`; ignore list: none.
