---
target: Edit Profile avatar UI screenshot
total_score: 32
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 1
target_identity: "file:/Users/truongminhluongjr/Documents/task_flow_v2/lib/features/tasks/presentation/screens/edit_profile_screen.dart"
target_fingerprint: "sha256:c2c6d09c968b9a13f96bf6eb42f9b8fe6d10c564a1bd035a0c0ae6445b220b6d"
target_path: /Users/truongminhluongjr/Documents/task_flow_v2/lib/features/tasks/presentation/screens/edit_profile_screen.dart
timestamp: 2026-11-18T02-52-48Z
slug: entation-screens-edit-profile-screen-dart-3a36803c
---
# Edit Profile / Avatar — Design Critique

Method: dual-agent (A: `/root/design_review` · B: `/root/detector_review`)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|---|---:|---|
| 1 | Visibility of System Status | 3 | Current initials are clear; selecting/uploading an image will need progress and error states. |
| 2 | Match System / Real World | 4 | Vietnamese labels and familiar profile-editing controls match the task. |
| 3 | User Control and Freedom | 3 | The edit affordance is visible, but the UI-only button is not wired to image selection yet. |
| 4 | Consistency and Standards | 3 | Read-only email resembles an editable, focused field. |
| 5 | Error Prevention | 3 | Name validation exists; the displayed email value should be checked against the label. |
| 6 | Recognition Rather Than Recall | 4 | Avatar initials, edit glyph, and save action are easy to recognize. |
| 7 | Flexibility and Efficiency | 3 | The helper instruction can be shortened; no image selection behavior yet. |
| 8 | Aesthetic and Minimalist Design | 3 | Navy/blue palette is coherent, but the input fill appears green-tinted and the edit badge competes with the avatar. |
| 9 | Error Recovery | 3 | Save errors have feedback; avatar selection will need its own failure state. |
| 10 | Help and Documentation | 3 | The instruction is clear, though it repeats the edit glyph's meaning. |
| **Total** | | **32/40** | Strong foundation; refine avatar action and read-only account details. |

## Design Specificity Verdict

**LLM assessment:** The screen fits TaskFlow's navy and blue theme and keeps the main task simple. Its centered initials avatar is clear but category-standard; the blue edit badge is oversized relative to the portrait, and the read-only email field looks focused. Keep the composition, reduce visual competition, and make account data look non-editable.

**Deterministic scan:** `impeccable detect --json lib/features/tasks/presentation/screens/edit_profile_screen.dart` returned `[]`. The detector did not flag static patterns; it cannot evaluate Flutter's rendered layout. No browser review or overlay was used because the evidence is a user-provided iOS screenshot and this is a native Flutter surface.

## Overall Impression

The screen is calm, legible, and already close to the app's visual language. The biggest opportunity is to make the avatar itself feel primary while keeping the edit action obvious and making the email's read-only status unmistakable.

## What's Working

- Centered avatar creates a clear visual anchor above the form.
- Initials provide a useful fallback before a photo is selected.
- Navy background and blue action color feel consistent with TaskFlow's current palette.

## Priority Issues

1. **[P1] The edit badge competes with the avatar.** In the screenshot, its visible circle covers a substantial part of the 104-ish-pixel avatar and competes with “TM.” Reduce the avatar to about 96 logical pixels, remove the floating badge, and place a labeled “Thay ảnh” button below. Keep the tap target at least 44×44 points. Suggested command: `$impeccable layout`.
2. **[P2] The Email field looks editable and displays a name.** The screenshot shows a blue focused outline and “Truong Minh Luong” below the Email label. Source passes `user.email`, so verify the actual value supplied to `EditProfileScreen`; render the email as subdued read-only account information rather than a focused text input. Suggested command: `$impeccable clarify`.

## Persona Red Flags

- **Jordan (First-Timer):** The pencil icon is recognizable, but the helper text repeats it; a text button labeled “Thay ảnh” would make the action explicit. The Email row currently looks editable even though it is read-only.
- **Morgan (Accessibility-Focused User):** The current floating badge may be harder to target reliably than a labeled 44×44 action; preserve a large touch target and provide a semantic label such as “Chọn ảnh đại diện.”

## Minor Observations

- The dark input fill appears green-tinted against the navy/blue theme; use a dark color-scheme surface container for closer palette alignment.
- Initials derive from `widget.name`; bind the preview to the current name controller so it stays in sync while typing.
- The empty image callback is acceptable for this UI-only stage, but should later open the image picker and expose loading/error feedback.

## Questions to Consider

- Would a labeled “Thay ảnh” button below the avatar feel clearer than the floating pencil badge?
- Should the email be displayed as a quiet account detail or remain in a read-only field?
