---
target: Profile screen UI review
total_score: 24
max_score: 40
na_heuristics: 
p0_count: 0
p1_count: 1
target_identity: "file:/Users/truongminhluongjr/Documents/task_flow_v2/lib/features/tasks/presentation/screens/profile_screen.dart"
target_fingerprint: "sha256:c54cca4accb412d35db76111ecec22bce81cb3d39a80929fd4b049a682aef2f0"
target_path: /Users/truongminhluongjr/Documents/task_flow_v2/lib/features/tasks/presentation/screens/profile_screen.dart
timestamp: 2026-11-07T02-45-49Z
slug: presentation-screens-profile-screen-dart-8e7b59df
---
## Rà soát giao diện Profile

### Điểm sức khỏe thiết kế

| # | Heuristic | Điểm | Nhận xét |
|---|---|---:|---|
| 1 | Hiển thị trạng thái hệ thống | 3/4 | Trạng thái giao diện và thông báo hiện rõ; trạng thái lỗi thay mô tả mặc định. |
| 2 | Khớp với ngôn ngữ đời thực | 3/4 | Nhãn gần gũi; “Thông tin khác” còn chung. |
| 3 | Quyền kiểm soát người dùng | 3/4 | Có thể đổi cài đặt và hủy xác nhận đăng xuất. |
| 4 | Nhất quán và tiêu chuẩn | 2/4 | Icon thông báo khác cách trình bày; hàng Giới thiệu có chevron nhưng chưa có hành động. |
| 5 | Ngăn ngừa lỗi | 3/4 | Đăng xuất có xác nhận; các cài đặt ít rủi ro. |
| 6 | Nhận biết thay vì ghi nhớ | 3/4 | Tùy chọn và nhãn hiển thị; dock có nhãn. |
| 7 | Linh hoạt và hiệu quả | 2/4 | Không thấy đường thao tác nhanh hoặc tùy chỉnh sâu tại màn này. |
| 8 | Thẩm mỹ và tối giản | 2/4 | FAB thu hút chú ý khỏi nội dung Profile và vùng đăng xuất. |
| 9 | Nhận biết và khôi phục lỗi | 2/4 | Có lỗi và đường mở cài đặt, nhưng lỗi chiếm chỗ mô tả chức năng. |
| 10 | Trợ giúp và hướng dẫn | 1/4 | Tooltip chỉnh sửa có ích; thiếu trợ giúp theo ngữ cảnh. |
| **Tổng** |  | **24/40** | **Chấp nhận được; ưu tiên bố cục và affordance.** |

### Nhận xét

Màn Profile có ngôn ngữ hình ảnh TaskFlow: xanh dương, nền chuyển sắc nhẹ, dock bo viên thuốc. Thông tin tài khoản dễ quét; ba lựa chọn giao diện đặt cạnh nhau; đăng xuất có xác nhận.

Ảnh có ô nền xanh quanh chuông, nhưng source hiện tại đặt icon 24×24 trong Container 24×24 không nền. Ảnh và code không khớp hoàn toàn.

### Vấn đề ưu tiên

1. **[P1] FAB tạo việc không hợp ngữ cảnh Profile.** Nó hiển thị ở mọi tab và trong ảnh che gần vùng đăng xuất. Ẩn trên tab Profile. `$impeccable layout`.
2. **[P2] Hàng “Giới thiệu TaskFlow” gợi ý điều hướng nhưng không có hành động.** Thêm đích đến hoặc bỏ chevron nếu chỉ là thông tin tĩnh. `$impeccable clarify`.
3. **[P2] Icon thông báo không đồng bộ.** Ảnh có nền riêng, source là icon trần; đồng nhất kích thước, nền và cách căn với các mục khác. `$impeccable polish`.
4. **[P2] Lỗi quyền thông báo thay thế mô tả cài đặt.** Giữ mô tả và trình bày lỗi thành dòng riêng cùng hành động khắc phục. `$impeccable harden`.

### Persona red flags

- Người dùng mới có thể nhấn hàng Giới thiệu do chevron nhưng không có phản hồi.
- Người xử lý quyền thông báo mất ngữ cảnh khi mô tả bị thay bởi lỗi.
- Người thao tác nhanh trên điện thoại bị FAB gây phân tâm hoặc che nội dung cuối trang.

### Ghi chú nhỏ

Tooltip “Sửa trang cá nhân” có ích. So ảnh và source cùng một bản build để xác nhận trạng thái icon. Impeccable v4.8.0 mới hơn bản skill v4.5.0 đang cài.

### Câu hỏi gợi mở

Profile có nên tiếp tục hiển thị nút tạo công việc nổi, hay chỉ nên có nút đó ở các tab làm việc?
