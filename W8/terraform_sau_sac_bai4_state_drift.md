# 💾 Bài 4: Đi Sâu Vào State, Cơ Chế Đối Chiếu 3 Chiều & Xử Lý Sai Lệch Hạ Tầng (Drift)

> **Mục tiêu:** Hiểu sâu vai trò của file state để không sợ nó, biết nó lưu gì, vì sao cần thiết, đọc hiểu thông tin bằng các lệnh `state list`/`state show`, và nắm vững cơ chế `refresh` dẫn tới việc phát hiện sai lệch hạ tầng (Drift) cùng cách xử lý.

---

## 🏗️ 1. Vì Sao Terraform Cần State?

Tại sao Terraform đã biết cấu hình bạn muốn (trong code `.tf`), AWS thì biết thực tế đang có gì, vậy cần thêm file state ở giữa làm gì? Tài liệu HashiCorp đưa ra bốn lý do cốt lõi:

1.  **Ánh xạ với thực tế (Mapping):** 
    Cấu hình của bạn viết `aws_s3_bucket.demo`, còn AWS chỉ biết một bucket thực tế có tên ngẫu nhiên như `tf-series-bai4-2026...`. State chính là cầu nối giữa hai tên đó: nó ghi nhớ *"resource local tên demo chính là bucket ID thực tế này trên AWS"*. Không có ánh xạ này, Terraform không biết khi bạn sửa block `demo` trong code thì phải cập nhật vào bucket nào trên AWS.
    *(Bản mẫu ban đầu của Terraform từng thử không dùng state mà dựa hoàn toàn vào tag để nhận diện, nhưng đã thất bại vì không phải tài nguyên nào trên Cloud cũng hỗ trợ gắn thẻ tag).*
2.  **Metadata về phụ thuộc (Dependency Metadata):**
    State lưu trữ cả quan hệ phụ thuộc giữa các tài nguyên. Điều này cực kỳ quan trọng lúc xóa (destroy): khi bạn gỡ một tài nguyên khỏi code cấu hình, nó không còn trong code để Terraform tự suy ra thứ tự xóa nữa. Do đó, thứ tự xóa an toàn phải được ghi nhớ trong file state từ trước để tránh xóa nhầm (ví dụ: xóa nhầm mạng VPC trước khi xóa máy ảo đang chạy trong đó).
3.  **Hiệu năng (Performance Cache):**
    State đóng vai trò như một bộ đệm (cache) lưu lại thuộc tính của mọi tài nguyên. Với hạ tầng lớn gồm hàng trăm, hàng nghìn tài nguyên, việc gọi API hỏi thăm từng tài nguyên một lên AWS mỗi khi chạy `plan` sẽ cực kỳ chậm do độ trễ mạng và giới hạn tần suất gọi API (rate limit) của AWS. State giúp Terraform tính toán kế hoạch nhanh chóng dựa trên bản cache này.
4.  **Đồng bộ nhóm (Team Collaboration):**
    Khi nhiều người cùng làm trên một hạ tầng, file state đặt ở nơi dùng chung (Remote Backend như AWS S3) giúp đảm bảo ai cũng làm việc trên cùng một phiên bản hạ tầng mới nhất, đồng thời khóa lại (State Locking) để hai người không thể chạy `apply` đè lên nhau gây lỗi.

---

## 📊 2. State Lưu Trữ Những Gì?

Hãy khai báo một S3 Bucket có cấu hình tag để thực hành:

```hcl
resource "aws_s3_bucket" "demo" {
  bucket_prefix = "tf-series-bai4-"
  force_destroy = true

  tags = {
    Project = "terraform-series"
    Env     = "dev"
  }
}
```

Sau khi chạy `terraform apply -auto-approve`, thay vì mở file JSON thô dễ gây rối mắt, ta dùng các câu lệnh CLI tích hợp để truy vấn state:

*   **Liệt kê các tài nguyên Terraform đang quản lý:**
    ```bash
    $ terraform state list
    aws_s3_bucket.demo
    ```
*   **Xem chi tiết thông số của tài nguyên cụ thể đã ghi trong state:**
    ```bash
    $ terraform state show aws_s3_bucket.demo
    ```
    *Kết quả hiển thị:*
    ```hcl
    # aws_s3_bucket.demo:
    resource "aws_s3_bucket" "demo" {
        bucket                      = "tf-series-bai4-20260525025632034200000001"
        hosted_zone_id              = "Z3O0J2DXBE1FTB"
        id                          = "tf-series-bai4-20260525025632034200000001"
        tags                        = {
            "Env"     = "dev"
            "Project" = "terraform-series"
        }
        # ... các thuộc tính khác
    }
    ```
    > [!NOTE]
    > Lệnh `state show` chỉ đọc dữ liệu từ tệp tin state cục bộ đã lưu trên máy, không gọi API lên AWS nên kết quả trả về tức thì.

---

## 🔄 3. Cơ Chế Refresh: So Sánh 3 Chiều

Mỗi lần chạy `terraform plan` hoặc `apply`, trước khi tính toán sự thay đổi (diff), Terraform luôn thực hiện bước **Refresh** để cập nhật thông tin mới nhất:

```
   main.tf (Code)         terraform.tfstate (State)         AWS (Thực tế)
   (Bạn MUỐN gì)          (Lần cuối ĐÃ BIẾT)               (Đang CÓ gì)
    Env = "dev"               Env = "dev"                    Env = "dev"
         │                         │                              │
         └─────────────┬───────────┴──────────────┬───────────────┘
                       ▼                          ▼
                 refresh: Đọc AWS, cập nhật bản trong bộ nhớ
                       │
                       ▼
                 So cấu hình HCL ⟷ Thực tế  ──► Đưa ra Diff (Plan)
```

Khi cả ba trạng thái khớp nhau hoàn toàn, diff sẽ rỗng và Terraform báo: `No changes. Your infrastructure matches the configuration.`

---

## 🚨 4. Xử Lý Sai Lệch Hạ Tầng (Drift Detection)

**Drift** xảy ra khi ai đó chỉnh sửa hạ tầng trực tiếp bằng tay trên giao diện Console của AWS, chạy bằng CLI thủ công hoặc một công cụ khác can thiệp ngoài sự kiểm soát của Terraform.

### Thực hành tạo Drift:
Hãy giả lập một kịch bản drift bằng cách sử dụng AWS CLI để đổi tag `Env` từ `dev` sang `production` hoàn toàn sau lưng Terraform:

```bash
$ aws s3api put-bucket-tagging --bucket tf-series-bai4-20260525025632034200000001 \
    --tagging 'TagSet=[{Key=Project,Value=terraform-series},{Key=Env,Value=production}]'
```

Bây giờ, bạn tiến hành chạy lệnh kiểm tra của Terraform:
```bash
$ terraform plan
```

Terraform sẽ thực hiện refresh, phát hiện ra sự sai lệch và đề xuất phương án khắc phục:
```diff
aws_s3_bucket.demo: Refreshing state... [id=tf-series-bai4-20260525025632034200000001]

  ~ update in-place

  # aws_s3_bucket.demo will be updated in-place
  ~ resource "aws_s3_bucket" "demo" {
        id   = "tf-series-bai4-20260525025632034200000001"
      ~ tags = {
          ~ "Env"     = "production" -> "dev"
            "Project" = "terraform-series"
        }
    }

Plan: 0 to add, 1 to change, 0 to destroy.
```

Ký hiệu `~` (update in-place) xuất hiện. Terraform thấy thực tế trên Cloud đã bị đổi thành `production` nhưng trong code bạn viết là `dev`, do đó nó đề xuất kéo giá trị thực tế quay trở về `dev` để khớp với code của bạn. Nếu bạn chạy `terraform apply` lúc này, tag trên AWS sẽ bị ghi đè ngược lại thành `dev`.

---

## 🛠️ 5. Hai Lựa Chọn Khi Gặp Drift

Khi phát hiện có thay đổi ngoài ý muốn trên Cloud, bạn có 2 hướng giải quyết:

### Lựa chọn 1: Giữ nguyên code của bạn và ghi đè lại AWS Cloud
*   **Hành động:** Chạy `terraform apply`. Terraform sẽ san phẳng các thay đổi thủ công trên Cloud để đưa hệ thống về đúng trạng thái bạn đã khai báo trong code `.tf`. (Dùng khi ai đó vô tình sửa sai hạ tầng và bạn muốn khôi phục lại).

### Lựa chọn 2: Chấp nhận sự thay đổi thực tế và cập nhật vào State
*   **Hành động:** Sử dụng chế độ **`-refresh-only`** để cập nhật trạng thái mới nhất từ Cloud vào file state mà không làm thay đổi tài nguyên thực tế:
    ```bash
    $ terraform plan -refresh-only
    ```
    *Kết quả plan:*
    ```diff
    Note: Objects have changed outside of Terraform
      ~ resource "aws_s3_bucket" "demo" {
          ~ tags = {
              ~ "Env"     = "dev" -> "production"
            }
        }
    ```
    Chiều mũi tên lúc này đã đảo ngược: `"dev" -> "production"`. Lần này Terraform không sửa AWS, nó đề xuất ghi nhận giá trị `production` vào file state của bạn. Sau khi apply lệnh này, bạn nhớ sửa lại code trong file `.tf` thành `Env = "production"` để đồng bộ hoàn toàn.

---

## 🔒 6. Lưu Ý Bảo Mật: State Là Plaintext

File state lưu trữ toàn bộ dữ liệu dưới dạng văn bản thuần (plaintext). Bất kỳ ai đọc được file state đều đọc được các thông tin nhạy cảm của bạn (như mật khẩu Database, SSH Keys). 
*   **Tuyệt đối không commit file `terraform.tfstate` lên Git.**
*   Khi làm dự án thực tế, bạn bắt buộc phải cấu hình Remote State trên AWS S3 có bật mã hóa tĩnh (Encryption at rest) và phân quyền truy cập nghiêm ngặt.

---

## 🧹 7. Dọn Dẹp (`destroy`)

```bash
$ terraform destroy -auto-approve
```
*Lệnh này đọc state, xóa sạch bucket đã tạo trên AWS và dọn dẹp file state cục bộ.*
