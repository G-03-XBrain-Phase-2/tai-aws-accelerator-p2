# ☁️ Hướng Dẫn Thực Hành: Triển Khai Hạ Tầng Lên AWS Bằng Terraform

> **Mục tiêu:** Từng bước viết cấu hình Terraform để tạo lập một hệ thống mạng ảo (VPC) bảo mật, một máy chủ ảo (EC2 Instance) cài sẵn web server, và lưu trữ tệp tin trên S3 Bucket thực tế trên AWS.

---

## 🛠️ 1. Kiến Trúc Hạ Tầng Cần Tạo (AWS Architecture)

Chúng ta sẽ sử dụng Terraform để tự động hóa việc click chuột và tạo ra mô hình mạng chuẩn bảo mật dưới đây:

```
AWS Cloud (ap-southeast-1 - Singapore)
└── VPC (10.0.0.0/16)
    ├── Internet Gateway (Kết nối internet cho mạng)
    └── Public Subnet (10.0.1.0/24)
        ├── Security Group (Firewall ảo: Mở cổng 80 & 22)
        └── EC2 Instance (Ubuntu 22.04 LTS chạy Web Nginx)
```

---

## 💻 2. Viết Code Cấu Hình Chi Tiết (`main.tf`)

Hãy copy toàn bộ đoạn code dưới đây và lưu vào file `main.tf` của bạn. Đây là code hoàn chỉnh, không dùng hardcode và tuân thủ các best practices của AWS:

```hcl
# 1. Cấu hình Terraform & Provider AWS
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
  }
}

provider "aws" {
  region = "ap-southeast-1" # Singapore
}

# 2. Tạo Mạng Ảo VPC (Virtual Private Cloud)
resource "aws_vpc" "main" {
  cidr_block           = "10.0.0.0/16"
  enable_dns_hostnames = true
  enable_dns_support   = true

  tags = {
    Name = "cloudops-vpc"
    Env  = "dev"
  }
}

# 3. Tạo Internet Gateway (Cổng kết nối Internet cho VPC)
resource "aws_internet_gateway" "gw" {
  vpc_id = aws_vpc.main.id

  tags = {
    Name = "cloudops-igw"
  }
}

# 4. Tạo Public Subnet (Phân mạng công cộng)
resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.main.id
  cidr_block              = "10.0.1.0/24"
  availability_zone       = "ap-southeast-1a"
  map_public_ip_on_launch = true # Tự động cấp Public IP cho máy ảo khi tạo

  tags = {
    Name = "cloudops-public-subnet"
  }
}

# 5. Tạo Route Table (Bảng định tuyến để dẫn luồng ra Internet)
resource "aws_route_table" "public_rt" {
  vpc_id = aws_vpc.main.id

  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.gw.id
  }

  tags = {
    Name = "cloudops-public-route-table"
  }
}

# Liên kết Route Table với Subnet
resource "aws_route_table_association" "public_assoc" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public_rt.id
}

# 6. Tạo Security Group (Firewall ảo cho EC2)
resource "aws_security_group" "web_sg" {
  name        = "allow-web-traffic"
  description = "Cho phep truy cap HTTP port 80 va SSH port 22"
  vpc_id      = aws_vpc.main.id

  # Cho phép truy cập Web Port 80 từ mọi nơi
  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Cho phép SSH Port 22 (Bạn nên giới hạn IP cá nhân ở đây thay vì 0.0.0.0/0)
  ingress {
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Luật ngõ ra (Egress): Cho phép máy ảo kết nối ra ngoài Internet
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1" # Tất cả các giao thức
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "web-traffic-security-group"
  }
}

# 7. Truy vấn AMI Ubuntu 22.04 LTS mới nhất
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical (Ubuntu)

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }
}

# 8. Tạo Máy Chủ Ảo EC2
resource "aws_instance" "web_server" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t2.micro" # Loại máy ảo miễn phí thuộc Free Tier
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.web_sg.id]

  # User Data: Script tự động chạy để cài đặt Nginx ngay khi tạo máy
  user_data = <<-EOF
              #!/bin/bash
              sudo apt-get update -y
              sudo apt-get install nginx -y
              sudo systemctl start nginx
              sudo systemctl enable nginx
              echo "<h1>Chao mung den voi CloudOps Web Server tao bang Terraform!</h1>" | sudo tee /var/www/html/index.html
              EOF

  tags = {
    Name = "web-production-server"
    Role = "WebServer"
  }
}

# 9. Xuất dữ liệu Public IP ra màn hình sau khi tạo xong
output "web_public_ip" {
  value       = aws_instance.web_server.public_ip
  description = "Dia chi IP de truy cap vao Web Server"
}
```

---

## 🚀 3. Quy Trình Các Bước Triển Khai Thực Tế

Sau khi cấu hình xong file `main.tf`, bạn mở terminal tại thư mục đó và chạy tuần tự các lệnh sau:

### Bước 1: Khởi tạo (`init`)
```bash
terraform init
```
*   **Mục tiêu:** Tải provider AWS từ Registry về máy cục bộ và khởi tạo môi trường làm việc.

### Bước 2: Kiểm tra cú pháp (`validate`)
```bash
terraform validate
```
*   **Mục tiêu:** Đảm bảo không viết sai chính tả hoặc truyền thiếu các tham số bắt buộc.

### Bước 3: Xem trước kế hoạch (`plan`)
```bash
terraform plan
```
*   **Mục tiêu:** Đọc kỹ danh sách tài nguyên chuẩn bị tạo (sẽ có 7 tài nguyên được thêm mới ký hiệu màu xanh `+`).

### Bước 4: Áp dụng triển khai (`apply`)
```bash
terraform apply
```
*   **Hành động:** Gõ `yes` khi được hỏi. Chờ khoảng 1-2 phút để AWS tạo xong VPC, Subnet, Security Group và khởi chạy EC2.
*   **Kiểm tra kết quả:** Terminal sẽ xuất ra dòng:
    `web_public_ip = "<địa_chỉ_IP_máy_chủ>"`
    Hãy mở trình duyệt web và truy cập vào IP đó, bạn sẽ thấy trang chào mừng của Nginx!

### Bước 5: Hủy tài nguyên để tránh mất phí (`destroy`)
```bash
terraform destroy
```
*   **Hành động:** Gõ `yes`. Lệnh này sẽ xóa sạch toàn bộ 7 tài nguyên vừa tạo trên AWS để bảo vệ túi tiền của bạn.
