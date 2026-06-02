# 💾 Bài 6: Đưa State Lên Cloud Với AWS S3 & Khóa State Hiện Đại (use_lockfile)

> **Mục tiêu:** Giải quyết vấn đề bảo mật và cộng tác nhóm bằng cách đưa file state lên AWS S3 Remote Backend, đồng thời cấu hình tính năng khóa trạng thái (State Locking) thế hệ mới sử dụng `use_lockfile` của S3 (native locking), thay thế cho cơ chế dùng DynamoDB cũ đã lỗi thời.

---

## ⚠️ 1. Vấn Đề Của Local State

Từ Bài 1 đến Bài 5, file `terraform.tfstate` của bạn được lưu cục bộ ngay trên máy tính cá nhân (`local backend`). Khi làm dự án thực tế, cách này sẽ gây ra 3 thảm họa sau:

1.  **Mất mát dữ liệu:** Nếu máy tính của bạn bị hỏng ổ cứng hoặc vô tình xóa mất thư mục dự án, toàn bộ bản đồ ghi nhớ hạ tầng biến mất. Bạn sẽ không thể sửa đổi hay xóa hạ tầng bằng Terraform được nữa.
2.  **Không thể làm việc nhóm:** Nếu bạn tạo máy ảo EC2, file state nằm trên máy bạn. Đồng nghiệp B muốn vào thêm một ổ đĩa cứng sẽ không có file state đó. Nếu B cố chạy, Terraform của B sẽ tưởng chưa có máy ảo nào và cố tạo mới đè lên, gây sập hệ thống.
3.  **Lộ bí mật (Security Risk):** File state lưu mọi thứ dưới dạng text thuần (plaintext). Nếu bạn lưu mật khẩu database, nó sẽ nằm phơi bày trong file state. Việc commit file này lên Git là cấm kỵ tuyệt đối.

---

## ☁️ 2. S3 Remote Backend: Giải Pháp Hiện Đại

Để giải quyết, ta đưa file state lên một kho lưu trữ tập trung trên mây (Remote Backend). AWS S3 là lựa chọn hàng đầu của CloudOps vì độ bền bỉ (durability) cao và chi phí cực rẻ.

```
   [Máy Kỹ sư A] ───► Chạy plan/apply ───┐
                                         │
                                         ▼
   [Máy Kỹ sư B] ───► Chạy plan/apply ───┼───► [AWS S3 Bucket]
                                         │   (Lưu trữ tập trung, mã hóa,
                                         │    bật Versioning để backup)
   [Hệ thống CI/CD] ─────────────────────┘
```

---

## 🔒 3. Khóa State Bằng `use_lockfile` (Native S3 Locking)

Khi state nằm trên S3, nếu Kỹ sư A và Kỹ sư B đồng thời chạy `terraform apply` thì sao? Cả hai người sẽ cùng ghi dữ liệu vào file state một lúc, làm hỏng file state (state corruption). Ta cần cơ chế **Khóa State (State Locking)**: khi có người đang chạy, hệ thống sẽ khóa file state lại, người thứ hai chạy sẽ bị từ chối và phải xếp hàng đợi.

### ❌ Cơ chế cũ (DynamoDB): Phức tạp và tốn kém
Trước đây, để khóa state trên S3, bạn bắt buộc phải tạo thêm một bảng cơ sở dữ liệu **AWS DynamoDB** chỉ để lưu trạng thái khóa. Việc này tạo thêm rác hạ tầng (phải quản lý thêm 1 tài nguyên DynamoDB) và tốn công cấu hình quyền IAM.

### ✔️ Cơ chế mới từ Terraform v1.10 (`use_lockfile`): Native & Siêu gọn
Từ phiên bản **Terraform v1.10**, HashiCorp đã cập nhật S3 backend hỗ trợ **Khóa State trực tiếp ngay trên S3** mà không cần DynamoDB nữa.
*   **Cách hoạt động:** Khi bạn chạy, Terraform tận dụng tính năng ghi có điều kiện (S3 Conditional Writes) để tạo ra một file khóa nhỏ có đuôi `.tflock` (ví dụ: `terraform.tfstate.tflock`) nằm ngay cạnh file state của bạn trong S3 bucket. Khi chạy xong, file này tự động bị xóa.
*   **Yêu cầu bắt buộc:** S3 Bucket dùng làm backend **bắt buộc phải bật tính năng Versioning** để cơ chế này hoạt động.

---

## 🏋️ 4. Thực Hành Từng Bước (Lab)

Chúng ta sẽ thực hiện chuyển đổi file state hiện tại lên AWS S3 dùng cơ chế khóa mới.

### Bước 1: Chuẩn bị S3 Bucket trên AWS
Trước khi cấu hình backend, bạn cần có một S3 Bucket thực tế trên AWS đã bật tính năng **Versioning** và **Mã hóa (Encryption)**. 

> [!CAUTION]
> **Quy tắc con gà và quả trứng:** Bạn không nên dùng chính code Terraform của dự án này để tạo ra chiếc S3 Bucket này (vì nếu xóa dự án, bạn sẽ xóa mất nơi chứa file state của chính nó). Hãy tạo chiếc bucket này thủ công bằng tay trên Web Console AWS, chạy bằng lệnh AWS CLI hoặc viết một script bootstrap riêng biệt.

*Giả sử bạn đã tạo thủ công một bucket trên AWS có tên:* `my-cloudops-global-tfstate-2026` *tại vùng `ap-southeast-1`.*

---

### Bước 2: Cấu hình `backend "s3"` trong file `main.tf`

Hãy thêm khối cấu hình `backend` vào trong block `terraform {}` ở đầu file `main.tf` của bạn:

```hcl
terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }

  # Cấu hình Remote Backend lưu trữ state trên S3
  backend "s3" {
    bucket       = "my-cloudops-global-tfstate-2026" # Tên bucket S3 bạn đã tạo
    key          = "dev/network/terraform.tfstate"   # Đường dẫn lưu file state trong bucket
    region       = "ap-southeast-1"
    use_lockfile = true                              # Kích hoạt khóa state trực tiếp trên S3 (Không cần DynamoDB)
    encrypt      = true                              # Tự động mã hóa file state ở chế độ tĩnh
  }
}
```

---

### Bước 3: Di chuyển State lên Cloud (`terraform init`)

Vì bạn vừa thêm một khối cấu hình `backend` hoàn toàn mới, bạn bắt buộc phải chạy lệnh khởi tạo lại để Terraform tái cấu hình môi trường:

```bash
$ terraform init
```

Terraform sẽ phát hiện bạn đang có file state cục bộ (`terraform.tfstate` cũ) và hỏi bạn có muốn di chuyển dữ liệu cũ lên S3 mới cấu hình hay không:

```
Initializing the backend...
Do you want to copy existing state to the new backend?
  Pre-existing state was found while migrating the previous "local" backend to the
  new "s3" backend. No existing state was found in the "s3" backend. Do you want to
  write this state to the new backend? Enter "yes" to copy and "no" to start with
  an empty state.

  Enter a value: yes
```

*   Hãy gõ **`yes`** và nhấn Enter.
*   Terraform sẽ tải file state cũ lên S3 bucket, sau đó hiển thị thông báo thành công:
    ```
    Successfully configured the backend "s3"! Terraform will now
    use this backend from the physical files.
    ```
*   **Kiểm tra thư mục cục bộ:** Bạn sẽ thấy file `terraform.tfstate` cũ ở máy bạn bây giờ đã trống rỗng hoặc biến mất. Toàn bộ lịch sử hạ tầng đã được cất giữ an toàn trên AWS S3.

---

### Bước 4: Kiểm chứng cơ chế Khóa hoạt động

Để xem tính năng khóa hoạt động ra sao:
1.  Mở 2 cửa sổ terminal cùng trỏ vào thư mục dự án này.
2.  Ở terminal 1, bạn chạy một lệnh chạy chậm (như `terraform apply` không có cờ `-auto-approve` để nó dừng lại đợi bạn gõ yes).
3.  Khi terminal 1 đang dừng đợi, bạn sang terminal 2 gõ ngay `terraform plan`.
4.  **Kết quả:** Terminal 2 sẽ lập tức bị chặn lại và xuất báo lỗi:
    ```
    Error: Error acquiring the state lock
    
    Error message: S3 write conditional failed: ...
    ```
    *Terraform đã tự tạo file `.tfstate.tflock` trên S3 để bảo vệ hạ tầng của bạn.*

---

## 🧹 5. Dọn Dẹp An Toàn (Gotcha Tránh Mất Tiền)

Nếu sau khi học xong, bạn muốn xóa toàn bộ tài nguyên trên AWS:

> [!CAUTION]
> **Cạm bẫy phá hủy:** Nếu bạn chạy `terraform destroy` ngay lập tức, Terraform sẽ xóa sạch mọi thứ bao gồm cả các tài nguyên thật. Tuy nhiên, nếu bạn xóa cả S3 bucket chứa file state của chính dự án này, Terraform sẽ mất trí nhớ ở nửa chừng và báo lỗi.

### Quy trình dọn dẹp đúng chuẩn CloudOps:
1.  Chạy `terraform destroy -auto-approve` để xóa hết các tài nguyên như EC2, Security Group.
2.  **Di chuyển file state quay trở lại máy cục bộ (Migrate back to local):**
    *   Hãy comment (hoặc xóa) khối cấu hình `backend "s3"` trong file `main.tf`.
    *   Chạy lại lệnh: `terraform init -migrate-state`. Gõ `yes` để Terraform tải file state từ S3 ngược về máy cá nhân của bạn.
3.  Sau khi state đã nằm an toàn ở local, bạn mới đăng nhập vào AWS Web Console và xóa thủ công chiếc S3 Bucket chứa state đi.

---

## 📝 Tổng Kết

*   **Local State** không an toàn, không chia sẻ được và dễ lộ thông tin nhạy cảm.
*   **S3 Backend** là giải pháp lưu trữ state tập trung, hỗ trợ versioning và mã hóa bảo mật.
*   **`use_lockfile = true`** là cơ chế khóa state trực tiếp trên S3 dựa trên cơ chế ghi có điều kiện (Conditional Writes) của S3, loại bỏ hoàn toàn sự phiền phức khi phải dùng DynamoDB table như các phiên bản cũ.
*   **Khi cấu hình backend mới**, bắt buộc phải chạy `terraform init` để thực hiện quá trình di chuyển (migration).
