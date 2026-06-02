# 💾 Giai Đoạn 2: State Management & Backend Architecture

> **Mục tiêu:** Hiểu rõ bản chất của file trạng thái (State file), cấu hình Remote Backend nâng cao với tính năng khóa trạng thái (State Locking), và thành thạo các câu lệnh thao tác trực tiếp với State để xử lý các bài toán thực tế của CloudOps.

---

## 🔍 1. Bản Chất Của File State (`terraform.tfstate`)

File State là một file định dạng **JSON** được Terraform tự động sinh ra sau khi chạy `terraform apply`. 

### 1.1 Nhiệm vụ cốt lõi của State:
1.  **Ánh xạ (Mapping):** Kết nối giữa tài nguyên khai báo trong code HCL với tài nguyên thực tế trên Cloud (dựa trên ID thực tế như `i-0a1b2c3d4e5f6g7h8` trên AWS).
2.  **Theo dõi Metadata:** Lưu trữ thông tin về các mối quan hệ phụ thuộc giữa các tài nguyên (`dependencies`) để Terraform biết tài nguyên nào cần tạo trước, tài nguyên nào cần tạo sau.
3.  **Bộ đệm hiệu năng (Performance Cache):** Khi chạy `plan` hoặc `apply`, Terraform sẽ truy vấn thông tin từ file state thay vì gọi hàng nghìn API request lên Cloud để kiểm tra tất cả tài nguyên, giúp tăng tốc độ làm việc.

### 🔴 Cảnh báo bảo mật:
File state lưu trữ toàn bộ dữ liệu dưới dạng **văn bản thuần (plaintext)**, bao gồm cả các thông tin nhạy cảm như mật khẩu database, SSH Keys hay API Access Keys. 
*   **Không bao giờ commit file `.tfstate` lên GitHub công khai.**
*   Hãy luôn đưa `.tfstate`, `.tfstate.backup` và `.terraform/` vào file `.gitignore`.

---

## ☁️ 2. Remote Backend & Cơ Chế State Locking

Trong môi trường doanh nghiệp CloudOps, nhiều kỹ sư cùng phát triển một hệ thống hạ tầng. Nếu lưu state cục bộ (Local State), hạ tầng sẽ bị xung đột lập tức. Do đó, ta cần cấu hình **Remote Backend**.

```
┌──────────────┐     Chạy apply      ┌─────────────────────────┐
│ Kỹ sư A (VM) ├───────────────────►│                         │
└──────────────┘                    │      REMOTE STATE       │
                                    │ (S3 / Google Cloud / Cloudflare)
┌──────────────┐     Báo bận (Lock)  │                         │
│ Kỹ sư B (VM) ├───────────────────►│                         │
└──────────────┘                    └────────────┬────────────┘
                                                 │
                                                 ▼
                                     ┌───────────────────────┐
                                     │   STATE LOCK TABLE    │
                                     │ (DynamoDB / Consul)   │
                                     └───────────────────────┘
```

### 2.1 Tại sao cần State Locking?
Nếu Kỹ sư A và Kỹ sư B đồng thời chạy `terraform apply`:
*   Không có Lock: Cả hai người cùng ghi dữ liệu vào file state một lúc. File state sẽ bị hỏng (corrupted), hoặc tài nguyên bị tạo trùng/xóa nhầm lẫn nhau.
*   Có Lock: Khi Kỹ sư A chạy `apply`, Terraform sẽ gửi một tín hiệu khóa (Lock) lên Database quản lý khóa (như DynamoDB). Kỹ sư B chạy `apply` cùng lúc sẽ nhận được thông báo lỗi: `Error: Error acquiring the state lock` và phải đợi đến khi Kỹ sư A hoàn thành.

### 2.2 Cấu hình Remote Backend mẫu với AWS S3 & DynamoDB
```hcl
terraform {
  backend "s3" {
    bucket         = "my-cloudops-tfstate-bucket" # Tên S3 bucket đã tạo sẵn
    key            = "global/s3/terraform.tfstate" # Đường dẫn lưu file state trong bucket
    region         = "ap-southeast-1"
    
    # DynamoDB Table để thực hiện tính năng khóa (Locking)
    dynamodb_table = "my-tfstate-locks" 
    encrypt        = true # Mã hóa file state trên S3 ở chế độ tĩnh (at rest)
  }
}
```

---

## 🛠️ 3. Quản Trị State Bằng Các Lệnh CLI Nâng Cao

> [!CAUTION]
> **Tuyệt đối không sửa thủ công file JSON `.tfstate`.** Bất kỳ hành động sửa đổi thủ công nào cũng có thể khiến file bị lỗi cú pháp JSON hoặc sai lệch cấu trúc dữ liệu, làm Terraform mất hoàn toàn kiểm soát. Hãy sử dụng các lệnh CLI tích hợp dưới đây để chỉnh sửa an toàn:

### 3.1 `terraform state mv` (Di chuyển / Đổi tên tài nguyên)
Dùng khi bạn muốn đổi tên định danh của một resource trong code HCL mà không muốn Terraform xóa tài nguyên thực tế đi để tạo lại với tên mới.

*   *Tình huống:* Bạn đổi tên resource trong code từ `web_server` thành `production_web`:
    ```hcl
    # Trước: resource "aws_instance" "web_server"
    # Sau:  resource "aws_instance" "production_web"
    ```
*   *Lệnh đồng bộ State:*
    ```bash
    terraform state mv aws_instance.web_server aws_instance.production_web
    ```

### 3.2 `terraform state rm` (Xóa quyền quản lý tài nguyên)
Dùng khi bạn muốn đưa một tài nguyên ra khỏi tầm quản lý của Terraform (ví dụ bàn giao tài nguyên đó cho một đội khác quản lý thủ công).

*   *Lệnh:*
    ```bash
    terraform state rm aws_instance.old_database
    ```
    *Sau khi chạy lệnh này, bạn có thể xóa code của resource `old_database` trong file `.tf`. Tài nguyên thực tế trên AWS vẫn hoạt động bình thường.*

### 3.3 `terraform import` (Nhập tài nguyên có sẵn)
Dùng khi bạn có một tài nguyên được tạo bằng tay (click chuột trên giao diện Console) từ trước, giờ muốn đưa nó vào quản lý bằng Terraform.

*   **Bước 1:** Khai báo một block rỗng trong code HCL:
    ```hcl
    resource "aws_instance" "legacy_web" {
      # Để trống các thuộc tính trước
    }
    ```
*   **Bước 2:** Chạy lệnh `import` liên kết block trên với ID thực tế trên Cloud:
    ```bash
    terraform import aws_instance.legacy_web i-0123456789abcdef0
    ```
*   **Bước 3:** Chạy `terraform show` để xem cấu hình thực tế của tài nguyên vừa được import vào state. copy các thông số đó điền lại vào block code rỗng ở Bước 1. Chạy `terraform plan` cho đến khi báo: `No changes. Infrastructure is up-to-date.`

---

## ✍️ Bài Tập Thực Hành Giai Đoạn 2

1.  **Bài tập 1 (Drift Detection):** 
    *   Tạo một container Docker Apache bằng Terraform.
    *   Truy cập bằng Docker CLI và xóa container đó đi theo cách thủ công (`docker rm -f <container_id>`).
    *   Chạy lệnh `terraform plan`. Quan sát xem Terraform làm thế nào để phát hiện ra sự sai lệch (Drift) giữa thực tế và code, và hành động tiếp theo của Terraform là gì.
2.  **Bài tập 2 (State Migration):**
    *   Tạo một dự án cục bộ sử dụng Local Backend thông thường.
    *   Sau khi apply thành công, hãy viết thêm block cấu hình `backend "s3"` (hoặc sử dụng một directory-based backend/local path giả lập nếu chưa có tài khoản Cloud).
    *   Chạy lệnh `terraform init` và quan sát cách Terraform hỏi bạn có muốn tự động di chuyển toàn bộ dữ liệu (Migrate) từ file state cũ sang backend mới hay không.
