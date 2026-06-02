# 🗺️ Bài 5: Đồ Thị Phụ Thuộc (Dependency Graph) - Bản Đồ Hành Trình Của Terraform

> **Mục tiêu:** Thấy được đồ thị phụ thuộc Terraform dựng từ cấu hình của bạn, hiểu phụ thuộc ngầm đến từ đâu, biết khi nào phải khai báo phụ thuộc thủ công bằng `depends_on`, và vì sao `-target` chỉ nên dùng trong tình huống ngặt nghèo.

---

Từ Bài 1 ta đã nghe câu *"Terraform thực hiện các thao tác theo đúng thứ tự, tôn trọng mọi quan hệ phụ thuộc"*. Bài 3 nói thứ tự dòng trong file không quyết định gì. Bài 4 nhắc state lưu cả metadata phụ thuộc để xóa đúng thứ tự. Giờ ta mổ cái cơ chế chung phía sau tất cả: **đồ thị phụ thuộc**. Hiểu nó thì việc Terraform tạo cái gì trước, xóa cái gì sau sẽ không còn bí ẩn.

---

## 🔌 1. Phụ Thuộc Ngầm: Tham Chiếu Là Tất Cả

Dựng hai tài nguyên (resource) có mối quan hệ: một bucket S3, và cấu hình versioning được bật trên bucket đó.

```hcl
resource "aws_s3_bucket" "data" {
  bucket_prefix = "tf-series-bai5-"
  force_destroy = true
}

resource "aws_s3_bucket_versioning" "data" {
  bucket = aws_s3_bucket.data.id

  versioning_configuration {
    status = "Enabled"
  }
}
```

Mấu chốt nằm ở dòng `bucket = aws_s3_bucket.data.id`. Resource versioning cần biết tên bucket, và nó lấy bằng cách tham chiếu thuộc tính `id` của resource bucket. 

Chính tham chiếu này tạo ra một **phụ thuộc ngầm định (implicit dependency)**: Terraform thấy versioning đọc giá trị từ bucket, nên tự hiểu rằng bucket phải tồn tại trước. Bạn không khai báo thứ tự ở đâu cả — nó tự suy ra từ việc *ai tham chiếu ai*.

### Chạy Apply và quan sát thứ tự:

```yaml
$ terraform apply -auto-approve
aws_s3_bucket.data: Creating...
aws_s3_bucket.data: Creation complete after 3s [id=tf-series-bai5-20260525025940839300000001]
aws_s3_bucket_versioning.data: Creating...
aws_s3_bucket_versioning.data: Creation complete after 2s [id=...]
Apply complete! Resources: 2 added, 0 changed, 0 destroyed.
```

Bucket được tạo xong hẳn rồi versioning mới bắt đầu. Dù trong file ta viết versioning sau cũng không phải lý do — nếu đảo hai block này cho nhau, kết quả vẫn y hệt.

---

## 📊 2. Xem Đồ Thị Tận Mắt

Lệnh `terraform graph` xuất đồ thị ở định dạng mã DOT của Graphviz:

```dot
$ terraform graph
digraph G {
  rankdir = "RL";
  node [shape = rect, fontname = "sans-serif"];
  "aws_s3_bucket.data" [label="aws_s3_bucket.data"];
  "aws_s3_bucket_versioning.data" [label="aws_s3_bucket_versioning.data"];
  "aws_s3_bucket_versioning.data" -> "aws_s3_bucket.data";
}
```

Dòng quan trọng là cạnh `"aws_s3_bucket_versioning.data" -> "aws_s3_bucket.data"`: versioning trỏ tới bucket, nghĩa là *"versioning phụ thuộc bucket"*. Đây là cách Terraform mô hình hóa toàn bộ cấu hình của bạn — một đồ thị có hướng, mỗi resource là một đỉnh, mỗi tham chiếu là một cạnh. 
*(Mã DOT này có thể vẽ ra ảnh trực quan bằng Graphviz: `terraform graph | dot -Tpng > graph.png`, cực kỳ hữu ích khi hạ tầng lớn).*

Có đồ thị rồi, Terraform sắp xếp topo (topological sort) để ra thứ tự thao tác: đỉnh nào không phụ thuộc ai thì làm trước, đỉnh phụ thuộc thì chờ thứ nó cần xong đã. 

> [!TIP]
> **Cơ chế chạy song song:** Những resource không có cạnh nối nhau là độc lập, nên Terraform sẽ tạo chúng song song (mặc định tối đa 10 thao tác cùng lúc). Đây là lý do apply một hạ tầng lớn nhanh hơn ta tưởng — nó không làm tuần tự từng cái, chỉ tuần tự theo các cạnh phụ thuộc.

---

## 🔄 3. Vì Sao Destroy Đảo Ngược Thứ Tự?

Cùng đồ thị đó, lúc xóa hạ tầng, Terraform đi ngược các cạnh. Lý do tự nhiên: nếu B phụ thuộc A, thì lúc tạo phải có A trước, còn lúc xóa phải gỡ B trước rồi mới gỡ A — không thể xóa cái đang được cái khác dựa vào. 

### Quan sát quá trình destroy:

```yaml
$ terraform destroy -auto-approve
aws_s3_bucket_versioning.data: Destroying...
aws_s3_bucket_versioning.data: Destruction complete after 1s
aws_s3_bucket.data: Destroying...
aws_s3_bucket.data: Destruction complete after 0s
Destroy complete! Resources: 2 destroyed.
```

Versioning bị gỡ trước, bucket sau, đúng ngược với lúc tạo. Đây cũng là lý do bài 4 nói state phải nhớ phụ thuộc: khi bạn xóa resource khỏi cấu hình, nó không còn trong file để suy ra thứ tự nữa, nên thứ tự đó lấy từ metadata trong state.

---

## 🔗 4. Khi Tham Chiếu Không Đủ: `depends_on`

Phụ thuộc ngầm bắt được hầu hết trường hợp, vì thường resource này cần giá trị từ resource kia. Nhưng có những phụ thuộc ẩn mà cấu hình không lộ qua tham chiếu nào. Tài liệu mô tả `depends_on` dùng để *"xử lý phụ thuộc ẩn giữa resource hoặc module mà Terraform không tự suy ra được"*.

Ví dụ thường gặp trong tài liệu: một EC2 instance cần một IAM role policy đã sẵn sàng lúc nó boot để chạy phần mềm bên trong, nhưng instance không tham chiếu policy đó trong bất kỳ đối số (argument) nào. Quan hệ này nằm ở tầng ứng dụng, Terraform không nhìn thấy. Khai báo thủ công:

```hcl
resource "aws_instance" "app" {
  # ... không có dòng nào tham chiếu policy ...
  depends_on = [aws_iam_role_policy.app]
}
```

> [!WARNING]
> **Khuyến cáo từ HashiCorp:** `depends_on` chỉ nên dùng như lối cuối cùng, vì nó khiến Terraform lập kế hoạch dè dặt hơn, thay thế nhiều resource hơn mức cần. 
> *Nguyên tắc thực hành:* Ưu tiên tham chiếu trực tiếp (ví dụ: `aws_iam_role_policy.app.arn`) bất cứ khi nào được, vì nó vừa tạo phụ thuộc vừa cho Terraform biết chính xác giá trị nào phụ thuộc; chỉ dùng `depends_on` khi quan hệ thật sự không thể hiện qua giá trị nào.

---

## 🚨 5. `-target`: Lối Thoát Hiểm, Không Phải Công Cụ Hằng Ngày

Đôi khi bạn muốn apply chỉ một phần đồ thị, ví dụ lúc gỡ rối một resource cứng đầu. Cờ `-target` cho phép giới hạn thao tác vào một (hoặc vài) resource cụ thể:

```bash
terraform apply -target=aws_s3_bucket.data
```

Terraform vẫn tôn trọng phụ thuộc của resource được nhắm (tạo luôn những thứ nó cần), nhưng bỏ qua phần còn lại của đồ thị. Vấn đề là làm vậy khiến state và cấu hình lệch nhau một cách có chủ đích, và bản thân Terraform sẽ in cảnh báo rằng đây là tính năng cho trường hợp đặc biệt, không nên dùng thường xuyên. 

Nếu bạn thấy mình gõ `-target` liên tục để apply "cho nhanh", đó là dấu hiệu nên tách cấu hình thành các state nhỏ hơn chứ không phải lạm dụng cờ này. Coi nó như lối thoát hiểm: có để dùng khi kẹt, không phải để đi lại hằng ngày.

---

## 📝 Tổng Kết

*   Terraform mô hình hóa cấu hình thành một đồ thị có hướng: resource là đỉnh, tham chiếu giữa chúng là cạnh, tạo nên **phụ thuộc ngầm**.
*   Lệnh `graph` cho xem đồ thị đó; từ nó Terraform sắp xếp topo để ra thứ tự, làm song song những nhánh độc lập, và đảo ngược thứ tự khi destroy.
*   Khi quan hệ không lộ qua tham chiếu (phụ thuộc ẩn ở tầng ứng dụng), `depends_on` khai báo thủ công, nhưng chỉ dùng khi buộc phải.
*   `-target` giới hạn thao tác vào một phần đồ thị, là lối thoát hiểm chứ không phải thói quen.
