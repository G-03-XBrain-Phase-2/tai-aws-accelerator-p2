# ⚙️ Giai Đoạn 3: Dynamic Configurations & Modules

> **Mục tiêu:** Nắm vững kỹ thuật tham số hóa code bằng Variables/Outputs, viết code thông minh tự động điều hướng cấu hình bằng các meta-arguments (`count`, `for_each`), sử dụng khối động `dynamic block` để tối ưu hóa code lặp lại, và thiết kế các Module tái sử dụng chuẩn hóa.

---

## 🎛️ 1. Tham Số Hóa Code (Variables, Outputs & Locals)

Để tránh hardcode (nhập cứng giá trị), một CloudOps Engineer phải thiết kế code linh động:

### 1.1 Khai Báo Biến Đầu Vào (Input Variables)
Biến giúp bạn thay đổi cấu hình mà không cần sửa file logic chính.
```hcl
variable "environment" {
  description = "Tên môi trường triển khai"
  type        = string
  default     = "dev"

  # Kiểm tra tính hợp lệ của dữ liệu đầu vào (Validation)
  validation {
    condition     = contains(["dev", "staging", "prod"], var.environment)
    error_message = "Môi trường triển khai bắt buộc phải là dev, staging hoặc prod."
  }
}

variable "db_password" {
  type      = string
  sensitive = true # Che giấu mật khẩu không hiển thị trên log terminal khi apply
}
```

### 1.2 Xuất Dữ Liệu Đầu Ra (Outputs)
Dùng để trả về các thông số hữu ích sau khi khởi tạo hạ tầng.
```hcl
output "server_public_ip" {
  value       = aws_instance.web.public_ip
  description = "Địa chỉ IP công cộng của Web Server"
}
```

### 1.3 Biến Cục Bộ (Locals)
Locals hoạt động như các biến trung gian bên trong module hiện tại (tương tự như gán biến trong lập trình thông thường) để tránh tính toán lặp đi lặp lại.
```hcl
locals {
  # Kết hợp các chuỗi lại để tạo ra một nhãn thống nhất
  service_name = "${var.environment}-web-service"
  owner        = "cloudops-team"
}

resource "aws_instance" "web" {
  # Sử dụng local value
  tags = {
    Name  = local.service_name
    Owner = local.owner
  }
}
```

---

## 🔄 2. Meta-Arguments & Khối Động (Dynamic Blocks)

### 2.1 `count` vs `for_each`
Dùng để nhân bản tài nguyên.

*   **`count` dùng cho điều kiện (Conditional Resource):**
    Chỉ tạo tài nguyên nếu biến `create_bastion` được set là `true`.
    ```hcl
    variable "create_bastion" {
      type    = bool
      default = true
    }

    resource "aws_instance" "bastion" {
      count         = var.create_bastion ? 1 : 0 # Phép toán ba ngôi (Ternary Operator)
      ami           = "ami-0c55b159cbfafe1f0"
      instance_type = "t2.micro"
    }
    ```

*   **`for_each` dùng cho danh sách động (Map/Set):**
    ```hcl
    variable "user_accounts" {
      type    = list(string)
      default = ["alice", "bob", "charlie"]
    }

    resource "aws_iam_user" "users" {
      # Chuyển đổi list thành set để sử dụng cho for_each
      for_each = toset(var.user_accounts) 
      
      # each.value sẽ lần lượt là "alice", "bob", "charlie"
      name     = each.value 
    }
    ```

### 2.2 Khối Động (Dynamic Blocks)
Khi định nghĩa các tài nguyên có nhiều cấu hình lặp lại bên trong (như các luật Ingress trong Security Group của AWS hoặc luật Firewall), viết thủ công sẽ làm phình code. Ta dùng `dynamic`:

```hcl
variable "firewall_ports" {
  type        = list(number)
  default     = [80, 443, 22, 8080]
  description = "Danh sách các cổng cần mở trên Firewall"
}

resource "aws_security_group" "web_traffic" {
  name        = "allow_web_traffic"

  # Sử dụng dynamic block để sinh ra hàng loạt khối "ingress"
  dynamic "ingress" {
    for_each = var.firewall_ports
    
    content {
      description      = "Mo cong ${ingress.value}"
      from_port        = ingress.value
      to_port          = ingress.value
      protocol         = "tcp"
      cidr_blocks      = ["0.0.0.0/0"]
    }
  }
}
```

---

## 📦 3. Thiết Kế Module Chuẩn Hóa (Terraform Modules)

Module là cách đóng gói một cụm các tài nguyên lại để có thể tái sử dụng (giống như thư viện hoặc hàm trong lập trình).

### 3.1 Cấu Trúc File Thư Mục Module Mẫu:
```
my-project/
├── main.tf              # Code chính của dự án, gọi module
├── variables.tf         # Khai báo các input variables của dự án chính
├── modules/
│   └── s3_bucket/       # Module tự phát triển quản lý S3 Bucket
│       ├── main.tf      # Logic chính tạo S3 Bucket
│       ├── variables.tf # Input variables mà module yêu cầu truyền vào
│       └── outputs.tf   # Các thông tin module xuất ra ngoài
```

### 3.2 Viết Code Bên Trong Module (`modules/s3_bucket/main.tf`):
```hcl
# modules/s3_bucket/variables.tf
variable "bucket_name" {
  type = string
}

# modules/s3_bucket/main.tf
resource "aws_s3_bucket" "this" {
  bucket = var.bucket_name
}

# modules/s3_bucket/outputs.tf
output "bucket_arn" {
  value = aws_s3_bucket.this.arn
}
```

### 3.3 Gọi Module Từ Dự Án Chính (`main.tf`):
```hcl
# Gọi module vừa tạo cục bộ
module "media_storage" {
  source      = "./modules/s3_bucket" # Đường dẫn tới thư mục chứa module
  bucket_name = "my-company-media-assets-2026" # Truyền tham số vào biến của module
}

# Gọi một module có sẵn từ cộng đồng (Terraform Registry)
module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "5.0.0"

  name = "production-vpc"
  cidr = "10.0.0.0/16"

  azs             = ["ap-southeast-1a", "ap-southeast-1b"]
  private_subnets = ["10.0.1.0/24", "10.0.2.0/24"]
  public_subnets  = ["10.0.101.0/24", "10.0.102.0/24"]
}
```

> [!NOTE]
> **Tầm Vực Của Biến (Scope):** Các Module hoạt động hoàn toàn độc lập. Bạn **không thể** gọi trực tiếp các biến của dự án chính từ bên trong module con và ngược lại. Mọi luồng dữ liệu đều phải đi qua `variable` (nhận vào) và `output` (trả ra).

---

## ✍️ Bài Tập Thực Hành Giai Đoạn 3

1.  **Bài tập 1 (Dynamic Security Group):** Hãy viết một đoạn code Terraform tạo một Security Group trong AWS (hoặc luật Firewall ảo). Sử dụng `dynamic block` để mở các cổng HTTP (80), HTTPS (443), SSH (22) và API (3000) dựa trên một danh sách cổng được định nghĩa trong `variables.tf`.
2.  **Bài tập 2 (Custom Module):** Hãy đóng gói cấu hình container Docker Nginx ở các giai đoạn trước thành một custom module nằm trong thư mục `./modules/docker_web`. Module này phải cho phép người dùng cấu hình cổng ngoài (`external_port`) và tên của container (`container_name`) thông qua các biến truyền vào. Sau đó, tại file `main.tf` chính, hãy gọi module này 2 lần để tạo ra 2 container chạy trên 2 cổng khác nhau (ví dụ: `8081` và `8082`).
