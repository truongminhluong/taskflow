---
target: Home state with upcoming tasks but no tasks today
total_score: 25
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 3
target_identity: "file:/Users/truongminhluongjr/Documents/task_flow_v2/lib/features/tasks/presentation/screens/home_screen.dart"
target_fingerprint: "sha256:3e3d3699d9767ffd014eb353a77bbc4bce8cb8f4939714dba7d7e642b0aa52f0"
target_path: /Users/truongminhluongjr/Documents/task_flow_v2/lib/features/tasks/presentation/screens/home_screen.dart
timestamp: 2026-11-13T03-12-30Z
slug: sks-presentation-screens-home-screen-dart-31143841
---
# ECC Critique — Home: có việc sắp tới, không có việc hôm nay

Method: dual-agent (A: /root/design_assessment · B: /root/mechanical_assessment)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|---|---:|---|
| 1 | Visibility of System Status | 2/4 | 0/0 dễ hiểu, nhưng câu “Thêm việc mới để bắt đầu nhé!” ngụ ý chưa có task nào dù bên dưới có task sắp tới. |
| 2 | Match System / Real World | 3/4 | Tiến độ hôm nay tách khỏi công việc tương lai hợp lý; copy chưa phân biệt “hôm nay trống” với “chưa có công việc”. |
| 3 | User Control and Freedom | 3/4 | Có lối tới tất cả công việc và lịch; không có lỗi điều hướng rõ trong trạng thái này. |
| 4 | Consistency and Standards | 2/4 | Hai heading “Công việc sắp tới” và “Sắp tới” cạnh tranh cho cùng danh sách. |
| 5 | Error Prevention | 3/4 | Task card vẫn cung cấp ngày/giờ và trạng thái; empty section có thể bị hiểu nhầm thành tải thiếu. |
| 6 | Recognition Rather Than Recall | 3/4 | Card công việc hiển thị ngày cụ thể, nhưng khoảng trống làm mối liên hệ với heading không rõ. |
| 7 | Flexibility and Efficiency | 2/4 | Một tiêu đề rỗng và khoảng cách lớn đẩy nội dung sắp tới xuống thấp. |
| 8 | Aesthetic and Minimalist Design | 2/4 | Khoảng trống sau “Công việc sắp tới” và heading trùng làm bố cục rời rạc. |
| 9 | Error Recovery | 3/4 | Có liên kết “Xem lịch” và “Tất cả công việc”; trạng thái không có lỗi phục hồi đáng kể. |
| 10 | Help and Documentation | 2/4 | Câu gợi ý khuyến khích tạo việc nhưng không hướng người dùng tới việc sắp tới đang có. |
| **Total** | | **25/40** | **Cần chỉnh hierarchy và copy theo state.** |

## Design Specificity Verdict

Đây là giao diện Home TaskFlow có bản sắc riêng nhờ header tiếng Việt, thẻ tiến độ xanh và task card. Vấn đề không nằm ở nhận diện thương hiệu mà ở việc các section chưa phản ánh đúng trạng thái “không có việc hôm nay nhưng có việc sau này”.

**LLM assessment:** ảnh tham chiếu cho thấy thẻ tiến độ `0/0`, heading “Công việc sắp tới”, một khoảng trống lớn rồi heading “Sắp tới” và task card. Cấu trúc đọc thành hai section nhưng chỉ có một nhóm task.

**Deterministic scan:** `impeccable detect --json` trên `home_screen.dart` trả về `[]` (0 findings). Detector không phát hiện sự trùng lặp ngữ nghĩa hay khoảng cách rỗng; đây là vấn đề hierarchy cần đánh giá bằng source và ảnh.

## Overall Impression

Header, thẻ tiến độ và task card đều phù hợp. Cơ hội lớn nhất là gom task sắp tới thành một nhóm hiển thị ngay sau thẻ tiến độ, đồng thời nói rõ tiến độ 0/0 chỉ áp dụng cho hôm nay.

## What's Working

- Lời chào và ngày giúp người dùng định vị thời điểm.
- Thẻ tiến độ giữ được trạng thái tổng quan hôm nay.
- Task card hiển thị ngày/giờ, ưu tiên và lối mở chi tiết; “Xem lịch” vẫn là hành động liên quan.

## Priority Issues

- **[P1] Heading dẫn vào danh sách rỗng:** khi hôm nay rỗng, heading đổi thành “Công việc sắp tới” nhưng sliver kế tiếp vẫn lấy `displayedTodayTasks` nên không có card nào. Bỏ section hôm nay rỗng và đặt danh sách sắp tới ngay dưới một heading duy nhất.
- **[P1] Tiêu đề sắp tới bị lặp:** “Công việc sắp tới” rồi “Sắp tới” đặt hai nhóm thị giác cho một danh sách. Dùng một heading duy nhất (đề xuất “Công việc sắp tới”), giữ “Tất cả công việc” hoặc “Xem lịch” làm action.
- **[P1] Copy empty progress gây hiểu nhầm:** “Thêm việc mới để bắt đầu nhé!” phù hợp với tài khoản chưa có task nào, nhưng sai ngữ cảnh khi task tương lai đã tồn tại. Đổi thành lời nhắc chỉ rõ hôm nay đang trống và task sắp tới có thể xem bên dưới.
- **[P2] Nội dung chính bị đẩy thấp:** khoảng cách giữa heading đầu và task card khiến người dùng mất thời gian rà/scroll. Đặt list ngay sau heading với khoảng cách chuẩn của các task list.

## Persona Red Flags

- Người dùng chỉ mở nhanh app để xem lịch hôm nay có thể thấy `0/0` và tưởng task chưa tải.
- Người dùng mới có task tương lai nhưng chưa task hôm nay có thể hiểu “Thêm việc mới” là chưa tạo thành công task nào.

## Evidence and Limits

- Source: `home_screen.dart` và `HomeProgressOverview`; screenshot do người dùng cung cấp.
- Detector không báo lỗi layout.
- Không chụp thêm ảnh simulator trong lượt này; đánh giá thị giác dựa trên screenshot đính kèm và xác nhận cấu trúc trong source.
- Target slug: `sks-presentation-screens-home-screen-dart-31143841`; ignore list: không có.
