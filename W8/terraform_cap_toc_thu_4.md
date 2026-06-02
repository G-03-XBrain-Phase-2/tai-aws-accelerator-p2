# 🔴 Giai Đoạn 0: Ôn Thi Cấp Tốc Cho Bài Kiểm Tra Thứ 4

> **Mục tiêu:** Ôn tập nhanh các kiến thức cốt lõi, các cạm bẫy lý thuyết và các câu hỏi thực hành kinh điển trong Terraform để bạn sẵn sàng 100% cho buổi kiểm tra vào Thứ 4.

---

## ⚡ 1. Tóm Tắt Khái Niệm "Chắc Chắn Thi" (High-Yield Core Concepts)

Trong các bài thi về Terraform (như HashiCorp Certified: Terraform Associate hoặc các đề thi CloudOps trường lớp), các khái niệm sau luôn chiếm 70% số điểm lý thuyết:

### 1.1 Khai Báo (Declarative) vs Mệnh Lệnh (Imperative)
*   **Declarative (Terraform):** Bạn chỉ định nghĩa **Trạng thái mong muốn** (`desired state`). Terraform tự động so sánh trạng thái hiện tại với mong muốn và tính toán hành động (`create`, `update`, `destroy`).
*   **Imperative (Ansible, Bash, CLI):** Bạn định nghĩa **Từng bước thực hiện**. Nếu chạy lại lần 2 mà không có kiểm tra, hệ thống sẽ báo lỗi hoặc tạo trùng lặp.

### 1.2 Nhà cung cấp (Providers)
*   Provider là plugin giúp Terraform giao tiếp với API (AWS, GCP, Docker, v.v.).
*   Lệnh `terraform init` sẽ tự động tải các providers được khai báo về thư mục `.terraform/`.
*   Nếu không khai báo provider trong code nhưng sử dụng resource của nó (ví dụ: `resource "aws_instance"`), Terraform sẽ tự suy luận (implicit provider) và tải provider AWS bản mới nhất trong lúc chạy `init`.

### 1.3 File Trạng Thái (State File)
*   File `terraform.tfstate` là **nguồn sự thật duy nhất** (Single Source of Truth) giúp Terraform ánh xạ tài nguyên trong code HCL với tài nguyên thực tế trên Cloud.
*   **Local Backend:** State lưu trên máy cá nhân dưới dạng JSON. **Nguy hiểm:** Dễ mất mát, lộ secret, không thể làm việc nhóm.
*   **Remote Backend (S3, GCS, Terraform Cloud):** Lưu state tập trung. Hỗ trợ **State Locking** (thông qua DynamoDB đối với AWS S3) để ngăn 2 người chạy `apply` cùng lúc gây hỏng state.

---

## 💻 2. Bảng Tra Cứu Lệnh CLI Thần Tốc (CLI Cheat Sheet)

Khi thi trắc nghiệm hoặc thực hành, bạn cần nhớ chính xác vai trò và thứ tự chạy của các lệnh sau:

| Lệnh CLI | Vai trò chính | Có thay đổi hạ tầng thật không? | Có thay đổi file State không? |
| :--- | :--- | :--- | :--- |
| **`terraform init`** | Tải providers, cấu hình backend. | Không | Không |
| **`terraform fmt`** | Tự động định dạng (căn lề, thụt dòng) code cho chuẩn. | Không | Không |
| **`terraform validate`** | Kiểm tra lỗi cú pháp (syntax) và tính hợp lệ của code. | Không | Không |
| **`terraform plan`** | Xem trước những thay đổi sẽ diễn ra. | **Không** | Không |
| **`terraform apply`** | Thực thi thay đổi trên hạ tầng. | **Có** | **Có (Cập nhật sau khi tạo)** |
| **`terraform destroy`** | Xóa toàn bộ tài nguyên do project quản lý. | **Có** | **Có (Xóa dữ liệu trong state)** |
| **`terraform show`** | Hiển thị nội dung state file dưới dạng dễ đọc. | Không | Không |
| **`terraform import`** | Đưa tài nguyên đã có sẵn trên Cloud vào tầm quản lý của Terraform. | Không | **Có (Ghi đè vào state)** |
| **`terraform state list`** | Liệt kê các tài nguyên hiện đang có trong file state. | Không | Không |
| **`terraform state rm`** | Xóa tài nguyên ra khỏi file state (tài nguyên thật trên Cloud **không bị xóa**). | Không | **Có** |

> [!WARNING]
> **Cạm bẫy phòng thi:** 
> * Lệnh `terraform validate` **không** cần kết nối internet hay cấu hình cloud credentials. Nó chỉ kiểm tra cú pháp cục bộ.
> * Lệnh `terraform plan` **có** gửi API request lên Cloud để đọc trạng thái thực tế (refresh state) nhưng **không** tạo/sửa gì trên đó.
> * Sự khác biệt giữa `destroy` và `state rm`: `destroy` xóa sạch tài nguyên thật trên Cloud; `state rm` chỉ bảo Terraform "quên" tài nguyên đó đi (tài nguyên thật vẫn chạy bình thường).

---

## 🎯 3. Phân Biệt Các Khái Niệm Dễ Nhầm Lẫn

### 3.1 `count` vs `for_each`
Khi cần tạo nhiều tài nguyên giống nhau (ví dụ: tạo 3 máy ảo):
*   **`count`**: Dùng một số nguyên (ví dụ `count = 3`).
    *   *Cách truy cập:* Dùng index (`aws_instance.web[0]`, `aws_instance.web[1]`).
    *   *Hạn chế:* Nếu bạn xóa phần tử ở giữa (ví dụ `index[1]`), Terraform sẽ dịch chuyển phần tử `[2]` thành `[1]` và cố gắng phá hủy/tạo lại tài nguyên, gây gián đoạn dịch vụ.
*   **`for_each`**: Dùng một Set hoặc Map.
    *   *Cách truy cập:* Dùng key (`aws_instance.web["web-prod"]`, `aws_instance.web["web-dev"]`).
    *   *Ưu điểm:* Xóa một phần tử bằng key cụ thể sẽ không ảnh hưởng đến các phần tử khác. **Luôn khuyến khích dùng `for_each` cho tài nguyên thực tế.**

### 3.2 Provisioners (`local-exec` vs `remote-exec`)
Provisioner dùng để chạy lệnh script sau khi tài nguyên được tạo thành công:
*   **`local-exec`**: Chạy lệnh trực tiếp trên **máy cá nhân chạy Terraform CLI** (hoặc máy CI/CD agent).
*   **`remote-exec`**: Kết nối qua SSH/WinRM và chạy lệnh trực tiếp bên trong **máy ảo vừa tạo trên Cloud**.
*   > ⚠️ **Lưu ý:** HashiCorp khuyên dùng Provisioner là giải pháp cuối cùng (Last Resort) vì Terraform không thể theo dõi trạng thái thành bại của các script này trong file state. Thay vào đó nên dùng `user_data` (Cloud-init) hoặc công cụ như Ansible.

---

## 📝 4. Bộ Câu Hỏi Trắc Nghiệm Ôn Tập (Mock Exam Quiz)

Hãy tự trả lời các câu hỏi sau trước khi xem giải thích:

### Câu 1: Sau khi viết một đoạn code mới cấu hình một Remote Backend bằng AWS S3, bạn cần chạy lệnh nào đầu tiên?
*   A. `terraform plan`
*   B. `terraform apply`
*   C. `terraform init`
*   D. `terraform refresh`
*   > [!TIP]
> **Đáp án đúng: C.** Mỗi khi thay đổi cấu hình Backend hoặc cấu hình Provider, bạn bắt buộc phải chạy lại `terraform init` (hoặc `terraform init -reconfigure` nếu chuyển đổi backend cũ) để Terraform cấu hình lại môi trường làm việc.

### Câu 2: Đồng nghiệp của bạn vô tình xóa mất file `terraform.tfstate` cục bộ và không dùng Remote Backend. Điều gì sẽ xảy ra khi bạn chạy `terraform apply` lần kế tiếp?
*   A. Terraform tự động quét Cloud để tìm lại tài nguyên và tạo lại file state.
*   B. Terraform coi như chưa có hạ tầng nào được tạo, nó sẽ cố gắng tạo mới toàn bộ tài nguyên từ đầu, dẫn đến lỗi trùng lặp (ví dụ trùng tên hoặc IP).
*   C. Terraform báo lỗi và từ chối chạy cho đến khi bạn khôi phục file.
*   > [!TIP]
> **Đáp án đúng: B.** Terraform không có khả năng tự động "quét và nhận diện ngược" hạ tầng cũ nếu không có file state (trừ khi dùng lệnh `import` thủ công từng tài nguyên). Do đó nó sẽ cố gắng chạy tạo mới hoàn toàn.

### Câu 3: Điền vào chỗ trống: Nếu bạn muốn định nghĩa một biến trong Terraform có thể nhận giá trị từ bên ngoài truyền vào, bạn khai báo bằng khối block `________`. Nếu muốn xuất dữ liệu (như Public IP của VM) ra màn hình sau khi apply, bạn dùng khối block `________`.
*   A. `variable` / `output`
*   B. `locals` / `output`
*   C. `parameter` / `return`
*   > [!TIP]
> **Đáp án đúng: A.** `variable` dùng để định nghĩa input variables, `output` dùng để định nghĩa output values.

---

## 🏋️ 5. Bài Tập Thực Hành Điểm 10 (Thao tác nhanh trên Docker)

Hãy chạy bài lab nhỏ này trên máy của bạn để thuần thục các thao tác quản lý State.

### Bước 1: Tạo file `main.tf`
```hcl
terraform {
  required_providers {
    docker = {
      source  = "kreuzwerker/docker"
      version = "~> 3.0.1"
    }
  }
}

provider "docker" {}

resource "docker_image" "nginx" {
  name         = "nginx:alpine"
  keep_locally = false
}

resource "docker_container" "web" {
  image = docker_image.nginx.image_id
  name  = "exam-web-server"
  ports {
    internal = 80
    external = 8080
  }
}
```

### Bước 2: Chạy khởi tạo và tạo tài nguyên
1. `terraform init`
2. `terraform apply -auto-approve` (Lưu ý cờ `-auto-approve` giúp tự động đồng ý không cần gõ `yes` - cực kỳ hữu ích khi viết script CI/CD hoặc làm bài thi thực hành tiết kiệm thời gian).

### Bước 3: Thực hành lệnh State CLI (Yêu cầu thi thực hành)
1. **Liệt kê tài nguyên đang quản lý:**
   ```bash
   terraform state list
   ```
   *Kết quả mong đợi:*
   ```
   docker_container.web
   docker_image.nginx
   ```
2. **Xóa tài nguyên khỏi state (không xóa container thật):**
   ```bash
   terraform state rm docker_container.web
   ```
   *Chạy lại `terraform state list` bạn sẽ thấy container biến mất khỏi state.*
3. **Kiểm tra thực tế:** Chạy lệnh `docker ps`. Bạn sẽ thấy container `exam-web-server` **vẫn đang chạy bình thường** trên máy của bạn.
4. **Nhập lại container vào tầm quản lý của Terraform (Import):**
   Vì code cấu hình của `docker_container.web` vẫn còn trong `main.tf`, nhưng state đã mất thông tin, chúng ta dùng lệnh `import` để đồng bộ lại:
   ```bash
   terraform import docker_container.web exam-web-server
   ```
   *(Trong đó `exam-web-server` là tên container thực tế cần import)*
5. Sau khi import thành công, chạy `terraform plan` để kiểm tra. Terraform sẽ báo: `No changes. Infrastructure is up-to-date.` (Nghĩa là code và thực tế đã đồng bộ hoàn toàn).
6. Cuối cùng, dọn dẹp môi trường:
   ```bash
   terraform destroy -auto-approve
   ```

---

> [!TIP]
> **Lời khuyên đi thi:** Hãy đọc kỹ đề bài xem họ yêu cầu sửa đổi hạ tầng thật (`apply`/`destroy`) hay chỉ thay đổi file State (`state rm`/`import`). Chúc bạn đạt điểm tuyệt đối vào Thứ 4!
