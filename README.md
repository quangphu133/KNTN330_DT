# HUIT — Ứng dụng nhân viên

Ứng dụng Android giúp nhân viên gửi bản ghi cuộc gọi tới hệ thống phân tích của nhóm, theo dõi phiên âm, xác nhận người nói và xem điểm tuân thủ.

Repository ứng dụng: [quangphu133/KNTN330_DT](https://github.com/quangphu133/KNTN330_DT).

Repository web và backend đi kèm: [quangphu133/KLTN330_FE_BE](https://github.com/quangphu133/KLTN330_FE_BE). HUIT gọi backend này; backend tiếp tục gọi dịch vụ AI. Ứng dụng không kết nối trực tiếp cơ sở dữ liệu hoặc dịch vụ AI.

Giao diện Flutter được phát triển dựa trên phần ứng dụng nhân viên của [NexTask](https://github.com/Samanyu-dev/NexTask), phát hành theo giấy phép MIT (xem LICENSE). Mã nguồn Flutter ban đầu lấy từ commit 61934d0fae8341978eb420ce109caab38c83297f.

## Chức năng

- Năm mục: Trang chủ, Cuộc gọi của tôi, Kết quả đánh giá, Thông báo và Hồ sơ.
- Chọn WAV, MP3, M4A, OGG, AAC hoặc FLAC, nghe thử rồi gửi phân tích.
- Theo dõi tác vụ, nghe bản ghi, tua theo câu phiên âm và xem lỗi cùng thời điểm phát hiện.
- Xác nhận giọng nhân viên khi kết quả có đúng hai người nói; điểm được tính theo engine hiện có của backend.
- Chỉ đọc cuộc gọi thuộc tài khoản nhân viên đang đăng nhập.

## Cấu trúc

- lib/: mã nguồn giao diện và tích hợp Flutter.
- android/: cấu hình Android, package vn.edu.huit.callreview.
- backend/, admin/ và một số thư mục nền tảng khác còn trong checkout NexTask ban đầu; HUIT không gọi hay dùng chúng. Backend cần chạy là repository [KLTN330_FE_BE](https://github.com/quangphu133/KLTN330_FE_BE), thư mục `backend/`.
- SOURCE_REVISION.txt: địa chỉ và commit của mẫu giao diện.

Các tài liệu `RENDER_DEPLOYMENT.md`, `SETUP_LOG.md` và `render.yaml` thuộc mẫu NexTask gốc, không phải hướng dẫn triển khai hệ thống HUIT. Phiên bản này tập trung Android; các nền tảng khác chưa được kiểm thử tích hợp.

## Lấy mã nguồn và chuẩn bị backend

Clone hai repository vào cùng một thư mục làm việc. Tên repo GitHub là `KNTN330_DT`; lệnh dưới giữ tên thư mục local là `KLTN330_DT`:

```powershell
git clone https://github.com/quangphu133/KNTN330_DT.git KLTN330_DT
git clone https://github.com/quangphu133/KLTN330_FE_BE.git KLTN330_FE_BE
```

Cài môi trường Python, cơ sở dữ liệu và cấu hình local theo README của repo `KLTN330_FE_BE`. Tài khoản nhân viên do quản trị viên cấp. Chạy backend ở cổng `8001` và kiểm tra `/health`; để phân tích audio, backend còn cần kết nối được dịch vụ AI. Các lệnh migration bên dưới chạy từ thư mục gốc **KLTN330_FE_BE**, không phải `backend/` của mẫu NexTask trong repo ứng dụng.

## Chạy trên Android Emulator

Máy cần Flutter SDK, Android SDK và Android Emulator. Từ PowerShell chạy:

    cd KLTN330_DT
    flutter doctor
    flutter pub get
    flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8001

Backend nhóm cần lắng nghe cổng 8001. Android Emulator truy cập máy phát triển qua 10.0.2.2; localhost trong emulator không phải máy tính.

## Chạy trên điện thoại Android thật

Kết nối điện thoại và máy backend cùng mạng LAN. Thay <IP_LAN_MAY_BACKEND> bằng IPv4 của máy backend:

    flutter run --dart-define=API_BASE_URL=http://<IP_LAN_MAY_BACKEND>:8001

Backend và firewall phải cho phép kết nối LAN tới cổng 8001. Chỉ bản debug cho phép HTTP phục vụ demo local; bản release mặc định chặn HTTP cleartext và cần dùng HTTPS.

## Tài khoản và API

- Đăng nhập bằng tài khoản nhân viên hiện có. App không có đăng ký công khai.
- App gọi API trên cổng 8001 với tiền tố /api; HF_TOKEN, khóa ASR và thông tin cơ sở dữ liệu chỉ nằm phía máy chủ.
- Địa chỉ mặc định cho emulator là http://10.0.2.2:8001.
- `API_BASE_URL` chỉ chứa địa chỉ gốc server, không thêm `/api`; ứng dụng đã khai báo tiền tố trong từng endpoint. Thay đổi địa chỉ này cần chạy/build lại ứng dụng.
- Tài khoản admin dành cho trang quản trị; HUIT hướng tới tài khoản nhân viên.

## Backend: migration và khởi chạy

Trong repo **KLTN330_FE_BE**, migration `backend/migrations/003_add_call_notifications.sql` tạo bảng thông báo. Với cơ sở dữ liệu đang dùng, sao lưu trước và áp dụng migration một lần. Chạy từ thư mục gốc repo đó; ví dụ PostgreSQL, thay các giá trị giữ chỗ bằng cấu hình riêng của nhóm:

    pg_dump -Fc -h <DB_HOST> -U <DB_USER> -d <DB_NAME> -f .\backup-before-huit-notifications.dump
    psql -h <DB_HOST> -U <DB_USER> -d <DB_NAME> -v ON_ERROR_STOP=1 -f .\backend\migrations\003_add_call_notifications.sql

Hoàn tác bằng backend/migrations/003_add_call_notifications_rollback.sql; thao tác này xóa bảng thông báo. Chỉ rollback nếu đã chấp nhận mất các thông báo trong bảng.

Backend bổ sung GET /api/analytics/me, GET /api/transcribe/, GET /api/notifications/, PATCH /api/notifications/{id}/read và API admin PATCH /api/mediafile/{id}/owner?telesale_id=<id>. Nhân viên upload được gán chủ sở hữu theo JWT; ID do app gửi không quyết định chủ sở hữu. Bản ghi cũ chưa có chủ sở hữu chỉ admin xem được cho tới khi admin gán lại.

## Kiểm tra và tạo APK

    flutter analyze
    flutter test
    flutter build apk --release --dart-define=API_BASE_URL=https://<DOMAIN_API_NHOM>

APK sau khi build nằm tại build\app\outputs\flutter-apk\app-release.apk. Kiểm thử tích hợp Android cần backend hoạt động, tài khoản nhân viên và audio mẫu được phép dùng. Đối chiếu điểm và lỗi với backend/web.

## Backend tests

Từ thư mục KLTN330_FE_BE\backend, chạy:

    ..\.venv-doan\Scripts\python.exe -m pytest

## Git

Mã HUIT được đăng tại [KNTN330_DT](https://github.com/quangphu133/KNTN330_DT); nguồn giao diện và commit NexTask được ghi trong `SOURCE_REVISION.txt`, giữ nguyên giấy phép MIT trong `LICENSE`.

## Repository liên quan

Ứng dụng HUIT này phụ thuộc API backend của nhóm tại [KLTN330_FE_BE](https://github.com/quangphu133/KLTN330_FE_BE). Clone và chạy backend theo hướng dẫn của repository đó trước khi chạy ứng dụng; cấu hình `API_BASE_URL` của HUIT phải trỏ tới máy đang chạy backend.
