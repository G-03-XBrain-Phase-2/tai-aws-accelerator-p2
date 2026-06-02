# AWS S3 Bucket Deployment with Terraform (Week 8)

Dự án này sử dụng Terraform để tự động khởi tạo và quản lý một AWS S3 Bucket trong vùng `ap-southeast-1` (Singapore) với các cấu hình linh hoạt.

## 📁 Cấu trúc thư mục dự án

```text
tai-aws-accelerator-p2/
├── README.md               # File hướng dẫn này
└── W8/                     # Thư mục bài tập Tuần 8
    ├── main.tf             # File cấu hình Terraform chính
    ├── .gitignore          # Cấu hình bỏ qua các file nhạy cảm và file tạm
    └── .terraform.lock.hcl # File khóa phiên bản provider AWS
```

## 🛠️ Tính năng cấu hình trong `main.tf`

- **AWS Provider:** Sử dụng phiên bản AWS Provider `~> 6.0`.
- **Region:** Mặc định triển khai tại `ap-southeast-1` (Singapore).
- **Naming Convention (Đặt tên S3 Bucket):** Tự động tạo tên Bucket động dựa theo công thức: `${project_name}-${environment}-s3-bucket`.
- **Tagging:** Tự động gắn tag quản lý `Env` và `Project` cho tài nguyên S3.
- **Output:** Trả về tên của Bucket sau khi khởi tạo thành công (`final_bucket_name`).

## ⚙️ Các biến đầu vào (Variables)

| Biến | Kiểu dữ liệu | Giá trị mặc định | Mô tả |
|------|-------------|------------------|-------|
| `project_name` | `string` | `"project1"` | Tên của dự án |
| `environment` | `string` | `"dev"` | Môi trường triển khai (`dev`, `staging`, `prod`) |

## 🚀 Hướng dẫn triển khai nhanh

### 1. Chuẩn bị
* Đã cài đặt **Terraform >= 1.10**.
* Đã cấu hình thông tin xác thực AWS CLI trên máy tính của bạn (`aws configure`).

### 2. Các lệnh khởi tạo và chạy
Di chuyển vào thư mục `W8`:
```bash
cd W8
```

Khởi tạo môi trường Terraform (tải Provider AWS):
```bash
terraform init
```

Kiểm tra trước kế hoạch triển khai (Plan):
```bash
terraform plan
```

Tiến hành tạo tài nguyên S3 Bucket trên AWS:
```bash
terraform apply
```
*(Gõ `yes` khi được hỏi để xác nhận).*
