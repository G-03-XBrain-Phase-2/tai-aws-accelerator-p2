te# 📘 Giai Đoạn 1: Core Fundamentals & HCL Syntax

> **Mục tiêu:** Hiểu sâu về cấu trúc của ngôn ngữ HCL, cách cấu hình Providers, vòng đời của Resources, cách sử dụng Data Sources và thành thạo quy trình làm việc chuẩn với Terraform CLI.

---

## 🏗️ 1. Cú Pháp Ngôn Ngữ HCL (HashiCorp Configuration Language)

HCL là một ngôn ngữ cấu hình khai báo. Cấu trúc cơ bản của một file cấu hình Terraform gồm các khối (**Blocks**), các đối số (**Arguments**) và các thuộc tính (**Attributes**).

```hcl
# <BLOCK TYPE> "<BLOCK LABEL 1>" "<BLOCK LABEL 2>" {
#   <IDENTIFIER> = <EXPRESSION> # Argument
# }

resource "aws_instance" "web_server" {
  ami           = "ami-0c55b159cbfafe1f0" # String Argument
  instance_type = "t2.micro"              # String Argument
  tags = {
    Name = "HelloWorld"                    # Map Argument
  }
}
```

*   **Block Type:** Loại khối (ví dụ: `terraform`, `provider`, `resource`, `data`, `variable`, `output`, `locals`).
*   **Block Label:** Nhãn định danh cho khối đó. Tùy thuộc vào Block Type mà số lượng nhãn khác nhau (ví dụ: `resource` cần 2 nhãn: Loại tài nguyên và Tên tài nguyên; `provider` chỉ cần 1 nhãn là tên provider).
*   **Argument:** Cặp khóa-giá trị (`key = value`) định hình cấu hình cho tài nguyên.
*   **Attributes:** Các giá trị được trả về bởi tài nguyên sau khi được tạo ra (ví dụ: `aws_instance.web_server.id` hoặc `aws_instance.web_server.public_ip`).

---

## 🔌 2. Nhà Cung Cấp (Providers) & Kỹ Thuật Nâng Cao

Providers là cầu nối dịch thuật giúp Terraform tương tác với các APIs của Cloud/SaaS.

### 2.1 Cấu hình Provider Block
```hcl
terraform {
  required_version = ">= 1.5.0" # Ràng buộc phiên bản của Terraform CLI
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0" # Chỉ cho phép nâng cấp các bản minor update (ví dụ 5.x)
    }
  }
}

# Cấu hình cụ thể cho AWS Provider
provider "aws" {
  region = "ap-southeast-1" # Singapore
}
```

### 2.2 Kỹ thuật Đa Nhà Cung Cấp (Provider Aliases)
Trong thực tế CloudOps, bạn thường phải tạo tài nguyên ở nhiều vùng (Regions) khác nhau hoặc trên các tài khoản AWS khác nhau cùng lúc. Khi đó, ta dùng `alias`:

```hcl
# Provider mặc định (Singapore)
provider "aws" {
  region = "ap-southeast-1"
}

# Provider phụ (Mỹ - N. Virginia)
provider "aws" {
  alias  = "us_east"
  region = "us-east-1"
}

# Sử dụng provider phụ trong resource
resource "aws_instance" "us_server" {
  provider      = aws.us_east # Trỏ tới alias us_east
  ami           = "ami-007855ac798b5175e"
  instance_type = "t2.micro"
}
```

---

## 💎 3. Resource vs Data Source

Đây là sự khác biệt cơ bản nhất cần ghi nhớ:

*   **`resource` (Write/Create):** Terraform chịu trách nhiệm **khởi tạo và quản lý toàn bộ vòng đời** của tài nguyên đó. Nếu xóa block này khỏi code, tài nguyên trên Cloud sẽ bị xóa ở lần `apply` tiếp theo.
*   **`data` (Read-only):** Terraform chỉ **truy vấn thông tin** từ tài nguyên có sẵn để sử dụng trong code HCL. Terraform không quản lý vòng đời tài nguyên này (nếu xóa block data, tài nguyên trên Cloud vẫn tồn tại bình thường).

### Ví dụ thực tế kết hợp Resource và Data Source:
Bạn muốn tạo một máy ảo EC2 (`resource`) nhưng muốn tự động lấy ID của bản cài đặt Ubuntu mới nhất từ AWS (`data source`) thay vì hardcode AMI:

```hcl
# 1. Truy vấn AMI Ubuntu 22.04 LTS mới nhất
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Chủ sở hữu Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 2. Sử dụng thông tin ID tìm được để tạo máy ảo
resource "aws_instance" "web" {
  ami           = data.aws_ami.ubuntu.id # Lấy giá trị động từ data source
  instance_type = "t2.micro"
  
  tags = {
    Name = "Web-Server-From-Data-Source"
  }
}
```

---

## 🔄 4. Khối Vòng Đời Tài Nguyên (Lifecycle Block)

Mặc định, khi một tài nguyên bị thay đổi các thuộc tính không thể cập nhật tại chỗ (như đổi tên máy ảo hoặc đổi AMI), Terraform sẽ **xóa tài nguyên cũ trước, sau đó tạo tài nguyên mới**. Điều này gây gián đoạn dịch vụ (Downtime). 
Bạn có thể thay đổi hành vi này bằng khối `lifecycle`:

```hcl
resource "aws_instance" "web" {
  ami           = "ami-0c55b159cbfafe1f0"
  instance_type = "t2.micro"

  lifecycle {
    # 1. Tạo máy mới chạy ổn định rồi mới xóa máy cũ
    create_before_destroy = true 

    # 2. Ngăn chặn tuyệt đối việc vô tình xóa tài nguyên quan trọng (như Database)
    prevent_destroy = false # Đổi thành true để kích hoạt bảo vệ

    # 3. Bỏ qua các thay đổi bên ngoài không do Terraform quản lý (ví dụ: Auto Scaling tự đổi size)
    ignore_changes = [
      tags,
      instance_type
    ]
  }
}
```

---

## 🛠️ 5. Quy Trình CLI Chuyên Nghiệp (Standard Workflow)

Một Kỹ sư CloudOps luôn tuân thủ quy trình 5 bước sau khi phát triển mã nguồn hạ tầng:

```
[Write Code] ──► terraform fmt ──► terraform validate ──► terraform plan ──► terraform apply
```

1.  **Viết cấu hình:** Tạo các file `.tf`.
2.  **`terraform fmt`:** Định dạng code. Giúp toàn bộ mã nguồn của dự án đồng nhất, dễ đọc khi commit lên Git.
3.  **`terraform validate`:** Kiểm tra tính logic của code (như gọi biến chưa định nghĩa, truyền sai kiểu dữ liệu).
4.  **`terraform plan -out=tfplan`:** Xuất kế hoạch ra một file lưu trữ tạm thời `tfplan`. Điều này đảm bảo kế hoạch bạn xem trước chính là kế hoạch sẽ được áp dụng, tránh việc tài nguyên Cloud bị ai đó thay đổi giữa lúc bạn chạy `plan` và `apply`.
5.  **`terraform apply "tfplan"`:** Áp dụng chính xác kế hoạch đã lưu trong file `tfplan` mà không cần hỏi lại `yes/no`. Đây là cách làm việc chuẩn trong các hệ thống CI/CD tự động.

---

## ✍️ Bài Tập Thực Hành Giai Đoạn 1

1.  **Bài tập 1 (Provider Aliases):** Hãy cấu hình Docker Provider để kết nối đồng thời với 2 Docker Daemon khác nhau (ví dụ: máy cục bộ của bạn và một server Docker ảo từ xa bằng cách sử dụng `alias`).
2.  **Bài tập 2 (Lifecycle Block):** Viết code tạo một container Docker Nginx. Thêm cấu hình `lifecycle` có thuộc tính `prevent_destroy = true`. Thử chạy lệnh `terraform destroy` và quan sát thông báo lỗi của hệ thống. Giải thích cách xử lý khi bạn thực sự muốn xóa container này.
