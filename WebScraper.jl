### A Pluto.jl notebook ###
# v0.15.1

using Markdown
using InteractiveUtils

# ╔═╡ 4cad59e0-0639-11ec-2f43-4d5952604839
begin
	import Pkg
	
	# Tải thư viện
	Pkg.activate(pwd())
	Pkg.add([
			"HTTP",
			"Gumbo",
			"Cascadia",
			"MbedTLS", # hack: cài đặt TLS để bỏ qua lỗi xác thực
			"Images",  # hiển thị hình ảnh trong bài viết
			])
	
	# `import` dùng để khai báo thư viện được sử dụng
	import HTTP, MbedTLS, Images
	
	# `using` có chức năng như `import` và sẽ đưa các hàm được khai báo
	# trong thư viện vào chương trình của bạn
	using Gumbo, Cascadia, Dates
end

# ╔═╡ f91947c4-ddf3-4af4-8457-266535c52670
md"# Thu thập dữ liệu Covid-19 tại Việt Nam"

# ╔═╡ a8e09f02-fba4-4c03-b764-0525541e73c2
md"
Bài viết này ghi lại quá trình mình làm quen với ngôn ngữ Julia thông qua việc thu nhập dữ liệu về số ca nhiễm Covid-19 tại Việt Nam và tạo một bộ dữ liệu (dataset) đơn giản từ thông tin thu tập được.

Toàn bộ bài viết được tạo bằng Pluto.jl, có chức năng tương tự như công cụ Jupyter Notebook trong ngôn ngữ Python.
Nếu bạn muốn chạy thử mã nguồn có trong bài viết, truy cập trang web [Julia](https://docs.julialang.org) để biết thêm về cách cài đặt. Để có giao diện như bài viết, truy cập trang web [Pluto.jl](https://plutojl.org/) để có thêm chi tiết.
"

# ╔═╡ a677035c-81f1-4e5f-8e79-82e95b4f1125
md"## Mở đầu"

# ╔═╡ cd798651-746d-4c8c-b4c4-78aae62fb9c9
md"
Phần lớn nội dung của bài viết sẽ đi sâu vào quá trình tạo một công cụ thu thập dữ liệu (WebScraper) cơ bản. WebScraping là từ dùng để mô tả quá trình trích xúât dữ liệu từ các trang web. Việc này có thể được thực hiện một cách thủ công hoặc được tự động hóa bằng cách sử dụng các công cụ tương tự như công cụ mình sẽ tạo trong bài viết này.

**Lưu ý:** Trước khi bắt đầu trích xuất dữ liệu từ một trang web bất kì, hãy lưu ý về các trách nhiệm pháp lý và quyền hạn sử dụng dữ liệu được quy định bởi trang web đấy.
"

# ╔═╡ be17b692-3c18-4cbe-abbb-a451e185b5e8
md"### Một chút về Julia"

# ╔═╡ da3b2ec7-d0f5-4082-8fe4-cd9977dcaedd
md"
Đây là một ngôn ngữ lập trình rất mới và được tạo bởi các nhà nghiên cứu từ MIT nhằm giải quyết các vấn đề gặp phải trong quá trình xử lý dữ liệu và tính toán khoa học (scientific computing). Một trong những khó khăn trong lĩnh vực này khi làm việc với các ngôn ngữ khác (chủ yếu là Python, C/C++ hoặc Fortran) là sự đánh đổi giữa tốc độ phát triển công cụ và tốc độ xử lí của công cụ đấy.

Với Python, việc thử nghiệm ý tưởng và phát triển công cụ có thể diễn ra rất nhanh, nhưng bù lại tốc độ xử lí của các công cụ viết bằng Python lại rất chậm so với các công cụ viết bằng C/C++ hoặc Fortran. Tệ hơn nữa, Python mặc định không cho phép một chương trình sử dụng đa luồng trong quá trình hoạt động, gây cản trở việc tối ưu hóa chương trình trên hệ thống đa luồng.

Vì vậy trong quá trình nghiên cứu, công cụ thường sẽ được phát triển thông qua 2 bước
1. Thử nghiệm ý tưởng với Python
2. Xây dựng công cụ với C/C++ hoặc Fortran

Phần lớn các thư viện của Python đề hoạt động và phát triển theo cách này, với toàn bộ mã nguồn được viết bằng C/C++ và Python chỉ được dùng để giao tiếp với công cụ viết bằng C/C++ bên dưới. Khi sử dụng Julia, cả 2 bước thử nghiệm và phát triển có thể được gộp thành một, và lập trình viên không cần phải làm việc cùng lúc với 2 ngôn ngữ khác nhau. Julia mang đến sự đơn giản của Python nhưng với tốc độ xử lý tối ưu của C/C++ hoặc Fortran. Ngoài ra, Julia còn có rất nhiều tính năng giúp tăng cao trải nghiệm người dùng khi làm việc với ngôn ngữ này.

**Lưu ý:** Hiện tại Julia chưa được sử dụng rộng rãi ở các công ty, nếu bạn đọc đang muốn học về lập trình hoặc về xử lí dữ liệu để phục vụ cho mục đích công việc thì Julia không phải là ngôn ngữ dành cho bạn.
"

# ╔═╡ 627bab60-22a3-484f-89a6-1cc9b706538d
md"### Trang thông tin được sử dụng"

# ╔═╡ a64d0ede-82cc-4d92-a434-a81adce148e9
md"
Để có thể dễ dàng bắt đầu và thử nghiệm với Julia, toàn bộ thông tin sẽ được trích xuất từ duy nhất một trang web -- [TRANG TIN VỀ DỊCH BỆNH VIÊM ĐƯỜNG HÔ HẤP CẤP COVID-19 (Bộ Y Tế)](https://ncov.moh.gov.vn).
Trang này chứa đầy đủ thông tin về số lượng người bệnh ghi nhận tại các địa phương bắt đầu từ năm 2020, phù hợp cho mục tiêu đơn giản của bài viết.
Dữ liệu chính mình đang quan tâm đến trong bài viết là số lượng bệnh nhân Covid-19 trong khoảng từ đầu năm 2021 đến nay.
"

# ╔═╡ e568c239-4269-4ac3-8fbd-4dac1e1951ae
md"### Các thư viện được sử dụng"

# ╔═╡ 1f1ccb77-00cd-4495-a54d-e22acaf3b5e3
md"
Dưới đây là một vài thư viện chính mình sẽ dùng trong quá trình tạo dataset. Cách dùng các thư viện này đã được mô tả nhanh trong bài viết [Scraping web pages with Julia and the HTTP and Gumbo packages](https://julia.school/julia/scraping/)
+ [`HTTP`](https://juliahub.com/docs/HTTP) -- gửi/nhận dữ liệu HTTP
+ [`Gumbo`](https://juliahub.com/docs/HTTP) -- đọc dữ liệu dưới định dạng HTML
+ [`Cascadia`](https://juliahub.com/docs/HTTP) -- trích xuất dữ liệu HTML thông qua thông tin CSS (CSS Selector)

Ngoài các thư viện kể trên, một vào các thư viện khác sẽ được sử dụng để tạo giao diện đẹp hơn cho bài viết và không phục vụ cho tính năng của công cụ WebScraper. Đoạn mã sau dùng để tải về các thư viện sẽ được sử dùng trong bài viết.
"

# ╔═╡ 1d7012c6-fa52-44ca-8e0f-9df9e40da6dd
md"## Thu thập dữ liệu gốc"

# ╔═╡ ae9e3b28-fab0-4081-902f-43e470f70d0e
md"
Trước khi tạo được một bộ dữ liệu hoàn chỉnh và chi tiết, đầu tiên, ta cần phải trích xuất dữ liệu gốc (raw data) tự các nguồn đang được quan tâm. Ở phần này, mình sẽ đi qua các bước xác định những dữ liệu cần được trích xuất và cách để trích xuất chúng.
"

# ╔═╡ 07d25ff2-cccd-44ec-9447-cb021ae1b234
md"### Mô tả dữ liệu"

# ╔═╡ 9557fdc7-e47b-47cb-97a3-95a6050c70d8
md"
Thông tin về số lượng bệnh nhân nằm ở đường dẫn [https://ncov.moh.gov.vn/vi/web/guest/dong-thoi-gian](https://ncov.moh.gov.vn/vi/web/guest/dong-thoi-gian). Sau khi truy cập vào đường dẫn, ta có thể thấy một chuỗi các thông báo đến từ Bộ Y Tế được sắp xếp theo thời gian từ mới nhất cho đến cũ nhất. Tổng số lượng bệnh nhân toàn quốc và tổng số lượng bệnh nhân từ mỗi khu vực được thể hiện trong nội dung của mỗi thông báo. 2 thông tin chính bao gồm:
+ Thời điểm đăng thông báo (khung màu **đỏ**)
+ Nội dung thông báo (khung màu xanh **lá**)

Theo quan sát sơ bộ, tất cả thông tin đều được thể hiện hoàn toàn dưới dạng văn bản ký tự (text document), với các phần và hạng mục được sắp xếp rõ ràng. Do đó, việc trích xuất các dữ liệu từ trang web này có thể dễ dàng được thực hiện sau khi xác định được của các phần tử dùng để hiện thị thông tin đang được quan tâm.
"

# ╔═╡ 20fac7a0-2c29-4d25-aba2-67f4e7e41ad5
Images.load("images/page_screenshot_00.png")

# ╔═╡ 879634af-5a0c-45c0-a4e8-265039994a89
md"### Truy cập mã nguồn"

# ╔═╡ b8fc4fc0-af45-478d-967b-69fa53581167
md"
Công cụ *Inspector*, có trên mọi trình duyệt, được dùng để xác định các phần từ chứa thông tin cần truy xuất. Có thể thấy, thông tin của mỗi thông báo được gói trong một thẻ `<div class=\"timeline\"/>` và toàn bộ nội dung của thông báo đấy sẽ nằm trong thẻ `<div class=\"timeline-detail\"/>`. Từ vị trí của một thẻ `<div class=\"timeline-detail\"/>`, ta có thể truy cập được thông tin về:
+ Thời gian đăng thông báo (ở thẻ `<h3/>` nằm trong thẻ `<div class=\"timeline-head\"/>`).
+ Nội dung của thông báo (ở các thẻ `<p/>` nằm trong thẻ `<div class=\"timeline-content\"/>`).
"

# ╔═╡ fb04f59b-d3ea-422c-a276-91573aced1b7
Images.load("images/timeline_element_00.png")

# ╔═╡ e7ea9cdd-50be-446d-bc0a-f6488159f7fd
md"#### Truy xuất thông tin"

# ╔═╡ 9a612d69-6153-4e5a-87ca-4cc8ea95eaed
md"
Sau khi xác định được các phần tử chứa các thông tin cần được trích xuất, ta có thể bắt đầu sử dụng Julia để đọc và xử lí các dữ liệu đến từ trang này. Để nhận nội dung của trang web, ta sử dụng hàm `HTTP.get`. Khi được gọi, hàm này sẽ gửi một yêu cầu truy cập trang web, và khi hoàn thành, hàm này sẽ trả về một biến với kiểu dữ liệu `HTMLResponse` chứa toàn bộ thông tin được gửi.
"

# ╔═╡ a2ae238e-d99c-4912-8dca-4ecb98550960
example_response = HTTP.get(
	"https://ncov.moh.gov.vn/vi/web/guest/dong-thoi-gian";
	sslconfig=MbedTLS.SSLConfig(false)
);

# ╔═╡ b96a3831-b66b-4985-a968-c4e190c9fd62
md"
**Lưu ý:** Julia sử dụng kiểu dữ liệu (data type) để quy định những tương tác giữa các biến và tối ưu hóa tốc độ xử lí của chương trình. Kiểu dữ liệu của một hàm số hoặc một biến số trong Julia không cần phải được khai báo. Trình biên dịch sẽ tự động \"đoán\" kiểu dữ liệu (type inference) mà bạn muốn sử dụng.
"

# ╔═╡ 45a1398a-9277-4184-a96f-7629633b29e1
typeof(example_response.body) # kiểu dữ liệu của thông tin lấy từ thẻ <body/>

# ╔═╡ dd46821a-7b91-4813-9e65-ed281178913b
md"
Sau bước trên, nội dung trả về sẽ được lưu vào biến có tên `example_response`. Ở thời điểm này, thông tin mà ta truy cập được hiện đang ở dưới dạng chuỗi ký tự và việc truy xuất thông tin từ một chuỗi ký tự là một quá trình tốn rất nhiều công sức và thời gian.
"

# ╔═╡ 16a6ec65-43e9-4a91-b6e1-3fbb825366b6
md"
Để chuyển đổi thông tin về định dạng có hỗ trợ tốt hơn cho việc đọc dữ liệu, hàm `parsehtml` từ thư viện `Gumbo.jl` sẽ được sử dụng để tạo một đối tượng dữ liệu (data object) từ nội dung HTML ở dạng ký tự. Đối tượng được trả về bởi `parsehtml` sẽ có kiểu dữ liệu là `HTMLDocument` và được lưu tại biến `example_document`.
"

# ╔═╡ 9f2ab126-2f78-453c-b010-390c84d31deb
example_document = parsehtml(String(example_response.body));

# ╔═╡ 42f111bd-1086-40fb-a9b5-592646aa9b62
md"
Thông tin ở bước này sẽ mang cấu trúc và \"hình dạng\" của file HTML đã được đọc. Để truy cập vào các thành phần của trang web, ta sử dụng các số chỉ mục (index) với biến `example_document`, thay vì phải thực hiện xử lí với một chuỗi kí tự.
"

# ╔═╡ 7a8c87ae-285c-4f90-945c-b31e442bd122
md"
Để lấy thông tin của thẻ `<head/>`, truy cập về phần tử thứ nhất tại `example_document.root` (mảng dữ liệu trong Julia bắt đầu **đếm từ 1**).
"

# ╔═╡ 71e2bda6-680c-4da4-ba14-85d01f31a957
tag(example_document.root[1])

# ╔═╡ 022ce8c3-f13e-4b93-89b1-75206b769e40
md"
Để lấy thông tin của thẻ `<body/>`, truy cập vào phần tử thứ hai tại `example_document.root`
"

# ╔═╡ 08fcdd7f-04c1-45b2-9c78-5a8a89dc6b5c
tag(example_document.root[2])

# ╔═╡ 4c42f6cb-cdc5-4051-951a-2799684952f1
md"Truy xuất phần tử thứ nhất nằm trong thẻ `<head/>`"

# ╔═╡ e098c8dc-4fa9-4132-a805-1a42902aaae0
example_document.root[1][1]

# ╔═╡ 9fa3fad1-33dc-42a6-847e-af6fa38389fc
md"Truy xuất một phần tử ở độ sâu bất kì"

# ╔═╡ 01b9caa9-7dc0-447f-8b1a-c31cc27656e1
example_document.root[2][2][2][1][2][1]

# ╔═╡ 7312873f-eb4b-470d-930b-e8c4e508d60b
md"
Ngoài phương pháp được nêu ra ở trên, thư viện `Cascadia.jl` sẽ hỗ trợ thực hiện việc tìm kiếm thẻ HTML thông qua thuộc tính CSS của chúng. Đây là một thư viện mở rộng cho thư viện `Gumbo.jl`.
"

# ╔═╡ 0470e20d-b5ce-4478-afa6-482128398655
md"
Để sử dụng thư viện này, đầu tiên ta tạo một biến với kiểu dữ liệu `Selector` bằng cách gọi trực tiếp đến hàm `Selector()` và đưa vào một chuỗi kí tự quy định thuộc tính CSS của thẻ HTML cần tìm. Ở đây, chuỗi kí tự `\"div .timeline\"` thể hiện rằng ta đang cần tìm tất cả các thẻ `<div/>` có thuộc tính `class=\"timeline\"`.
"

# ╔═╡ 945ee64e-037c-4120-a9aa-7f4eeff12a75
selector_announcement = Selector("div.timeline")

# ╔═╡ dfd9f632-7a3b-49f6-921f-56e968819f31
md"
Sau khi tạo một đối tượng có kiểu dữ liệu `Selector` ta có thể sử dụng hàm `eachmatch` (có sẵn trong Julia) để lấy một tập hợp các thẻ HTML thỏa điều kiện được đưa ra.
"

# ╔═╡ 72f08ebc-0d55-4af9-a312-d171a298a101
example_announcements = eachmatch(selector_announcement, example_document.root[2])

# ╔═╡ 9ffffed1-ffb8-4c10-838a-ae1f90c6d91c
md"
Sau bước trên, ta nhận được một danh sách của các đối tượng có kiểu dữ liệu `HTMLElement` đại diện cho các thẻ `<div/>` có chứa thông tin của các thông báo. Với mỗi đối tượng `HTMLElement`, ta có thể tiếp tục thực hiện tìm kiếm bằng thuộc tính CSS để truy xuất được các dữ liệu nằm ở vị trí sâu hơn.
"

# ╔═╡ d846ccaa-7785-449f-b364-01702a160c79
md"##### Truy xuất thời điểm đăng thông báo"

# ╔═╡ a3615c1b-9b47-4837-bb08-2c5b7059e480
md"
Ở bước này, mình tạo một hàm được dùng để lấy nội dung trong thẻ `<h3/>` nằm dưới hai thẻ `<div/>` có thuộc tính CSS lần lượt là `class=\"timeline-detail\"` và `class=\"timeline-head\"`. Hàm này sẽ được gọi với biến có kiểu dữ liệu là `HTMLElement` đại diện cho thẻ `<div class=\"timeline\"/>` được tìm thấy ở phần trên.
"

# ╔═╡ a49aa63e-5f68-4b9a-9225-18279703e525
function parse_announcement_head(element::HTMLElement)::String
	selector_head = Selector("div.timeline-detail div.timeline-head h3 *")
	head_elem = eachmatch(selector_head, element)

	# Chỉ có một đối tượng chứa thời điểm đăng
	@assert length(head_elem) == 1
	
	# Lấy nội dụng nằm trong thẻ h3
	text(head_elem[1])
end

# ╔═╡ ab894a2c-cbe5-408c-b3eb-3c597e1877a9
parse_announcement_head(example_announcements[1])

# ╔═╡ 54c6bde0-67db-45cf-9069-c5c8dd143bd2
md"##### Truy xuất nội dung thông báo"

# ╔═╡ 82501bac-9e84-4741-ac33-3d502878fc80
md"
Ở bước này, mình tạo một hàm được dùng để lấy nột dung trong thẻ `<p/>` nằm dưới hai thẻ `<div/>` có thuộc tính CSS lần lượt là `class=\"timeline-detail\"` và `class=\"timeline-content\"`. Hàm này sẽ được gọi với biến có kiểu dữ liệu là `HTMLElement` đại diện cho thẻ `<div class=\"timeline\"/>` được tìm thấy ở phần trên. 
"

# ╔═╡ a325e387-6f7f-4171-88bf-0ed579d9a227
function parse_announcement_content(element::HTMLElement)::AbstractVector{String}
	selector_content = Selector(".timeline-detail .timeline-content p *")
	content_elem = eachmatch(selector_content, element)

	# Tất cả các chuỗi ký tự từ nội dung phần tử lấy được
	content_paragraphs = [text(paragraph) for paragraph in content_elem]
	# Với mỗi chuỗi kí tự, loại bỏ khoảng trắng ở đầu và đuôi
	content_paragraphs = map(x -> strip(isspace, x), content_paragraphs)
	# Lại bỏ các chuỗi rỗng
	content_paragraphs = filter(x -> !isempty(x), content_paragraphs)
end

# ╔═╡ 27a6c5fb-5fae-4a1f-97ac-b1617f432281
parse_announcement_content(example_announcements[1])

# ╔═╡ a035df5e-e157-4c37-88ea-99f77d592013
md"#### Truy cập vào các trang tiếp theo"

# ╔═╡ 3b139efb-d1e9-4d0c-92e5-9d54939706ad
md"
Sau khi xác định được vị trí và cách truy xuất các thẻ HTML chứa thông tin cần thiết, ta có thể bắt đầu thu thập dự liệu của tất cả các thông báo có tại trang web. Nếu bạn đọc để ý thì mỗi trang khi được truy cập chỉ hiển thị tối đa 10 thông báo. Để truy cập các thông báo cũ hơn, ta phải di chuyển đến các trang tiếp theo. Dưới đây là 2 cách có thể được sử dụng để thực hiện việc này.
"

# ╔═╡ 82476ef7-a464-420b-8255-197ab6f62c3a
md"##### Sử dụng nút chuyển trang"

# ╔═╡ 516a38e6-d413-4eee-bca7-80ab16c5c80d
md"
Một cách để xác định đường dẫn URL đến trang mới là thông qua nút chuyển trang có ở mỗi trang. Tiếp tục dụng công cụ *Inspector*, ta có thể xác định được thẻ HTML chứa đường dẫn đến trang tiếp theo. Chuỗi kí tự quy định thuộc tính của thành phần này có định dạng như sau.

```
div.lfr-pagination ul.lfr-pagination-buttons li:nth-child(2):not(.disabled) a
```

Ở đây, điểm đáng chú ý là thuộc tính `:nth-child(2)` và thuộc tính `:not(.disabled)`.
+ `:nth-child(2)` dùng để quy định rằng chỉ thẻ `<li/>` ở vị trí thứ 2 trong thẻ `<ul/>` được chọn.
+ `:not(.disabled)` dùng để quy định rằng thẻ `<li/>` chỉ được chọn khi không chứa thuộc tính `class=\"disabled\"`.
"

# ╔═╡ 25b7a736-df65-4bb7-9c2c-1c1bd1e9e6eb
Images.load("images/pagination_buttons_00.png")

# ╔═╡ baf244b9-c835-4c4d-a1d7-64dbe4da6377
md"
Dựa vào quan sát trên, mình tạo một hàm dùng để lấy đường dẫn đến trang tiếp theo từ nút chuyển trang có tại trang đang được truy cập
"

# ╔═╡ 846202be-e05f-4360-acd4-f9f342aeea28
function parse_pagination_button_next(element::HTMLElement)::String
	selector_next = Selector("div.lfr-pagination ul.lfr-pagination-buttons li:nth-child(2):not(.disabled) a");
	next_elem = eachmatch(selector_next, element)
	
	# Kiểm tra xem trang có nhiều hơn một nút tiếp theo không
	@assert length(next_elem) == 1
	
	# Lấy đường dẫn từ nút
	getattr(next_elem[1], "href")
end

# ╔═╡ b8ba41f1-d226-4624-b118-22bbfadd7ad4
parse_pagination_button_next(example_document.root[2])

# ╔═╡ 3ec264ce-9465-4a55-9407-87221027ba6e
md"##### Tạo đường dẫn trưc tiếp đến trang"

# ╔═╡ 3ccc941b-8823-4718-b751-de125d425f32
md"
Một cách khác để duyệt qua tất cả các trang thông báo là tự tạo đường dẫn URL đến trang được đánh số mà không cần thông qua nút chuyển trang. Quan sát các đường dẫn URL lấy được từ nút chuyển trang, ta có thể thấy các đường dẫn này đều có chung một định dạng như sau.

```
https://ncov.moh.gov.vn/vi/web/guest/dong-thoi-gian?p_p_id=com_liferay_asset_publisher_web_portlet_AssetPublisherPortlet_INSTANCE_nf7Qy5mlPXqs&p_p_lifecycle=0&p_p_state=normal&p_p_mode=view&_com_liferay_asset_publisher_web_portlet_AssetPublisherPortlet_INSTANCE_nf7Qy5mlPXqs_delta=10&p_r_p_resetCur=false&_com_liferay_asset_publisher_web_portlet_AssetPublisherPortlet_INSTANCE_nf7Qy5mlPXqs_cur=<ĐÁNH SỐ TRANG>
```

Để truy cập đến một trang bất kì, trình duyệt web sẽ gửi đi một gói tin có đính kèm thông tin số trang mà bạn muốn truy cập. Bằng cách chỉnh sửa nội dụng quy định số trang cần được truy cấp, ta có thể di chuyển đến một trang bất kì mà không phải thông qua việc trích xuất đường dẫn từ nút chuyển trang.

Đường dẫn đến trang số 2

```
https://ncov.moh.gov.vn/vi/web/guest/dong-thoi-gian?p_p_id=com_liferay_asset_publisher_web_portlet_AssetPublisherPortlet_INSTANCE_nf7Qy5mlPXqs&p_p_lifecycle=0&p_p_state=normal&p_p_mode=view&_com_liferay_asset_publisher_web_portlet_AssetPublisherPortlet_INSTANCE_nf7Qy5mlPXqs_delta=10&p_r_p_resetCur=false&_com_liferay_asset_publisher_web_portlet_AssetPublisherPortlet_INSTANCE_nf7Qy5mlPXqs_cur=2
```

Đường dẫn đến trang số 80

```
https://ncov.moh.gov.vn/vi/web/guest/dong-thoi-gian?p_p_id=com_liferay_asset_publisher_web_portlet_AssetPublisherPortlet_INSTANCE_nf7Qy5mlPXqs&p_p_lifecycle=0&p_p_state=normal&p_p_mode=view&_com_liferay_asset_publisher_web_portlet_AssetPublisherPortlet_INSTANCE_nf7Qy5mlPXqs_delta=10&p_r_p_resetCur=false&_com_liferay_asset_publisher_web_portlet_AssetPublisherPortlet_INSTANCE_nf7Qy5mlPXqs_cur=80
```
"

# ╔═╡ 90d77c0f-7869-4abd-98f1-3f7556164ca9
md"Từ nhận định trên, mình tạo một hàm mới với chức năng nhận vào số trang, gửi yêu cầu nhận thông tin của trang được đánh số đó đến server, và trả về dữ liệu dưới dạng `HTMLDocument` có chứa nội dung của trang truy cập được."

# ╔═╡ 2438877a-fe67-4acb-8c01-d64c6e3c774b
function get_announcements_page(page_number::Integer)::HTMLDocument
	url = "https://ncov.moh.gov.vn/vi/web/guest/dong-thoi-gian?p_p_id=com_liferay_asset_publisher_web_portlet_AssetPublisherPortlet_INSTANCE_nf7Qy5mlPXqs&p_p_lifecycle=0&p_p_state=normal&p_p_mode=view&_com_liferay_asset_publisher_web_portlet_AssetPublisherPortlet_INSTANCE_nf7Qy5mlPXqs_delta=10&p_r_p_resetCur=false&_com_liferay_asset_publisher_web_portlet_AssetPublisherPortlet_INSTANCE_nf7Qy5mlPXqs_cur=$page_number"
	
	@info "requesting data" url
	
	response = HTTP.get(url; sslconfig=MbedTLS.SSLConfig(false))
	parsehtml(String(response.body))
end

# ╔═╡ c654f9e6-2b5d-4d7b-891d-a7a94e5b500f
md"### Bất đầu thu thập dữ liệu"

# ╔═╡ 3d60ea9c-d8c6-41fa-a672-5a70c2cee160
md"
Sau khi quan sát và thẩm định các nội dụng cần được thu thập, ta đã xác định được vị trị của các thông tin có trên trang. Ở bước này, ta có thể bắt đầu tạo một chương trình thu thập thông tin của tất cả các thông báo ở dạng nguyên bản (raw data).
"

# ╔═╡ 296cb140-c8d9-4648-886e-b55de05ec849
md"#### Các hàm trợ giúp"

# ╔═╡ c8454699-0c4f-42d2-97b9-319821f5d323
md"
Để dễ dàng thể hiện một thông báo trong chương trình, ta tạo một kiểu dữ liệu mới có  tên `Announcement`. Kiểu dữ liệu này sẽ chứa thông tin về thời gian (`timestamp`) và nội dung (`content`) của thông báo đã được đăng tải.
"

# ╔═╡ 0e4d7351-2db0-4dca-99ae-74b6669ff80e
struct Announcement
	timestamp::DateTime
	content::AbstractVector{String}
end

# ╔═╡ 99b8afcd-0247-47af-8d23-14f90ccaa4ac
md"
Đầu tiên, mình sẽ tạo một hàm giúp chuyển dữ liệu từ một biến có kiểu dữ liệu `HTMTElement` sang một biến có kiểu dữ liệu `Announcement`. Để dễ dàng sử dụng thông tin về thời gian, chuỗi kí tự được trả về từ hàm `parse_announcement_head` sẽ được chuyển đổi thành đối tượng có kiểu dữ liệu `DateTime`.
"

# ╔═╡ b00a7fdc-12a6-42d1-98fc-5c8b17a27d5c
function parse_announcement(element::HTMLElement)::Announcement
	head = parse_announcement_head(element)
	content = parse_announcement_content(element)
	
	Announcement(DateTime(head, "HH:mm dd/mm/yy"), content)
end

# ╔═╡ cd573427-5a2b-423f-aba6-82fde7a1fb18
parse_announcement(example_announcements[1])

# ╔═╡ 926ba393-a9d8-4a42-961f-eaae680cf56f
md"
Có được hàm trên, mình tiếp tục tạo một hàm mới dùng để tạo một danh sách các thông báo trong một trang.
"

# ╔═╡ be8e03c2-f3ba-4ac4-9297-edd70b885b3b
function parse_announcements(document::HTMLDocument)::AbstractVector{Announcement}
	# Chọn các thẻ HTML chưa thông tin của các thông báo
	selector_announcement = Selector("div .timeline")
	timeline_elems = eachmatch(selector_announcement, document.root[2])
	
	# Duyệt qua các thẻ và sử dụng hàm `parse_announcement` vừa mới được tạo
	# để trích xuất thông tin
	[parse_announcement(elem) for elem in timeline_elems]
end

# ╔═╡ 141c94bc-1670-42e5-82bd-dbb3244199d5
parse_announcements(example_document)

# ╔═╡ 6844910c-1ab1-4578-9c7b-aa4b1d68a5a0
md"#### Chạy chương trình thu thập dữ liệu"

# ╔═╡ c0665287-0771-4b29-aee4-5ae2d2ccd5cb
md"
Để dễ dàng xử lí các trang một cách đồng thời (concurrent), ta sẽ sử dụng phương thức tạo đường dẫn URL đến trang thông qua số của trang. Như vậy, quá trình xử lí của một trang sẽ không bị phụ thuộc vào những trang trước và một trang bất kì có thể bắt đầu được xử lí mà không cần phải đợi thông tin được trả về từ server cho trang trước đó.

Trong bài viết này, mình sẽ sử dụng các tác vụ bất đồng bộ (asynchronous tasks) để có xử lí đồng thời nhiều trang khác nhau và tránh việc đợi thông tin trả về từ server gây ảnh hưởng đến tốc độ xử lí. Một tác vụ bất đồng bộ có thể được tạm dừng khi rơi vào trạng thái chờ. Khi một tác vụ bị tạm dừng, vi xử lí dùng cho tác vụ đấy có thể bắt đầu làm việc với một tác vụ khác và tránh lãng phí thời gian.

Ở đây, các tác vụ đồng thời sẽ được tạo bởi hàm `asyncmap`, hàm này nhận một hàm số và một tập hợp. Khi hoàn thành, `asyncmap` sẽ trả về một tập hợp mới chứa kết quả của hàm số được đưa vào sau khi áp dụng nó với tất cả các phần tử trong tập hợp. Với mỗi phần tử từ tập hợp, `asyncmap` sẽ tự động tạo một tác vụ bất động bộ dùng để chạy quá trình áp dụng hàm số lên phần tử đó.

Chương trình thu thập dữ liệu được khởi động bằng cách gọi hàm `asyncmap` với 2 giá trị:
1. Tập hợp các số từ 1 đến 100 (đại diện cho số của các trang sẽ được truy cập)
2. Một hàm số nhận vào số trang và trả về các thông báo từ trang đấy
"

# ╔═╡ 0e6277fd-9bd8-4672-9fc6-5af77d9406e3
begin
	announcements_paginated = asyncmap(1:100) do page_number
		parse_announcements(get_announcements_page(page_number))
	end
	all_announcements = collect(Iterators.flatten(announcements_paginated))
end

# ╔═╡ 6b9e7a0a-eb83-4b4f-9b1b-2cc483555a1e
md"## Trích xuất số liệu từ thông báo"

# ╔═╡ 0883e298-330e-4f9c-914d-5bbb2e738430
md"
Sau khi chạy chương trình thu thập dữ liệu, ta đã có được một danh sách của tất cả các thông báo về tình hình dịch bệnh được đăng tải bởi Bộ Y Tế trong khoảng từ đầu năm 2020 đến nay. Hiện tại, thông tin thu thập được đang ở hoàn toàn dưới dạng chuỗi kí tự. Để có được chính xác số lượng người bệnh của từng địa phương qua từng thời điểm, nội dung của mỗi thông báo cần phải được xử lý thêm nhằm trích xuất các con số thể hiện thông tin đang được quan tâm.
"

# ╔═╡ 3e9cf64a-0b73-4193-ae39-ab54d916fbc9
md"### Xác định bố cục chung của các thông báo"

# ╔═╡ dd3c5f71-ce80-4f67-8c81-5a6162b94220
md"Danh sách tất thông báo được đăng tải trong năm 2021"

# ╔═╡ f8446a1d-2cf6-4ddb-9b34-64d099d2ef6e
filter(all_announcements) do x
	x.timestamp >= DateTime(2021)
end

# ╔═╡ 6de56fd5-44b5-4b9e-822f-a075f89375a2
md"
Nhìn sơ, bố cục nội dung của các thông báo từ đầu năm 2021 đến nay tất cả đều có cùng các nội dung sau:

| Thông tin                    | Chuỗi kí tự |
|:-----------------------------|:------------|
| Tổng số ca bệnh toàn quốc    | \"<SỐ_LƯỢNG> CA MẮC MỚI\"|
| Tổng số ca bệnh nhập cảnh    | \"<SỐ_LƯỢNG> ca (cách li ngay sau khi)? nhập cảnh\" |
| Tổng số ca bệnh trong nước   | \"<SỐ_LƯỢNG> ca ghi nhận trong nước\"|
| Tổng số ca bệnh ở địa phương | \"<TỈNH/TP> (<SỐ_LƯỢNG>)\"|

Ngoài các thông tin trên, những thông tin dưới đây cũng được thể hiện trong phần lớn các thông báo nhưng bố cục chưa được thống nhất hoặc bị thiếu sót ở một vài thông báo

| Thông tin                     | Chuỗi kí tự |
|:------------------------------|:------------|
| Tổng số ca bệnh từ 27/04      ||
| Tổng số ca khỏi từ 27/04      ||
| Tổng số ca bệnh ở cộnng đồng  ||
| Tổng số ca bệnh ở khu cách ly ||
| Số ca bệnh đăng ký bổ sung    ||
"

# ╔═╡ 052d534d-2673-4ed9-829b-ded0f27e0329
md"### Testing out the RegEx"

# ╔═╡ ede95350-6cc4-4f43-81e7-5e8f1621cd51
md"
From the same of data above, we see that new announcements follow roughly the same format. The format provides the following data:
+ `\"<TOTAL_CASES> CA MẮC MỚI\"`
+ `\"<CITY_NAME> (<CITY_CASES>)\"`
"

# ╔═╡ bd46bad1-8185-4984-9cc8-411ee567d870
begin
	match_result = match(
		r"(?<cases>(?:\.?\d+)+)\s+CA MẮC MỚI",
		all_announcements[1].content
	)
	total_cases = filter(x -> x != '.', match_result[:cases])
	total_cases = parse(Int, total_cases)
end

# ╔═╡ f5776071-274d-4088-b1b1-9a014f91fdb8
begin
	matches = eachmatch(
		r"(?<city>(?:\p{Lu}\p{L}+[\s\.-]+)+)\(\s*(?<cases>(?:\.?\d+)+)\s*\)",
		all_announcements[1].content
	)
	
	city_cases_pairs = map(matches) do match
		strip(isspace, match[:city]) => strip(isspace, match[:cases])
	end
	
	city_cases_pairs = collect(city_cases_pairs)
end

# ╔═╡ ccd5fa0f-1aef-49ef-a0a2-e44b55ebfb74
parse_announcement_head

# ╔═╡ Cell order:
# ╟─f91947c4-ddf3-4af4-8457-266535c52670
# ╟─a8e09f02-fba4-4c03-b764-0525541e73c2
# ╟─a677035c-81f1-4e5f-8e79-82e95b4f1125
# ╟─cd798651-746d-4c8c-b4c4-78aae62fb9c9
# ╟─be17b692-3c18-4cbe-abbb-a451e185b5e8
# ╟─da3b2ec7-d0f5-4082-8fe4-cd9977dcaedd
# ╟─627bab60-22a3-484f-89a6-1cc9b706538d
# ╟─a64d0ede-82cc-4d92-a434-a81adce148e9
# ╟─e568c239-4269-4ac3-8fbd-4dac1e1951ae
# ╟─1f1ccb77-00cd-4495-a54d-e22acaf3b5e3
# ╠═4cad59e0-0639-11ec-2f43-4d5952604839
# ╟─1d7012c6-fa52-44ca-8e0f-9df9e40da6dd
# ╟─ae9e3b28-fab0-4081-902f-43e470f70d0e
# ╟─07d25ff2-cccd-44ec-9447-cb021ae1b234
# ╟─9557fdc7-e47b-47cb-97a3-95a6050c70d8
# ╟─20fac7a0-2c29-4d25-aba2-67f4e7e41ad5
# ╟─879634af-5a0c-45c0-a4e8-265039994a89
# ╟─b8fc4fc0-af45-478d-967b-69fa53581167
# ╟─fb04f59b-d3ea-422c-a276-91573aced1b7
# ╟─e7ea9cdd-50be-446d-bc0a-f6488159f7fd
# ╟─9a612d69-6153-4e5a-87ca-4cc8ea95eaed
# ╠═a2ae238e-d99c-4912-8dca-4ecb98550960
# ╟─b96a3831-b66b-4985-a968-c4e190c9fd62
# ╠═45a1398a-9277-4184-a96f-7629633b29e1
# ╟─dd46821a-7b91-4813-9e65-ed281178913b
# ╟─16a6ec65-43e9-4a91-b6e1-3fbb825366b6
# ╠═9f2ab126-2f78-453c-b010-390c84d31deb
# ╟─42f111bd-1086-40fb-a9b5-592646aa9b62
# ╟─7a8c87ae-285c-4f90-945c-b31e442bd122
# ╠═71e2bda6-680c-4da4-ba14-85d01f31a957
# ╟─022ce8c3-f13e-4b93-89b1-75206b769e40
# ╠═08fcdd7f-04c1-45b2-9c78-5a8a89dc6b5c
# ╟─4c42f6cb-cdc5-4051-951a-2799684952f1
# ╠═e098c8dc-4fa9-4132-a805-1a42902aaae0
# ╟─9fa3fad1-33dc-42a6-847e-af6fa38389fc
# ╠═01b9caa9-7dc0-447f-8b1a-c31cc27656e1
# ╟─7312873f-eb4b-470d-930b-e8c4e508d60b
# ╟─0470e20d-b5ce-4478-afa6-482128398655
# ╠═945ee64e-037c-4120-a9aa-7f4eeff12a75
# ╟─dfd9f632-7a3b-49f6-921f-56e968819f31
# ╠═72f08ebc-0d55-4af9-a312-d171a298a101
# ╟─9ffffed1-ffb8-4c10-838a-ae1f90c6d91c
# ╟─d846ccaa-7785-449f-b364-01702a160c79
# ╟─a3615c1b-9b47-4837-bb08-2c5b7059e480
# ╠═a49aa63e-5f68-4b9a-9225-18279703e525
# ╠═ab894a2c-cbe5-408c-b3eb-3c597e1877a9
# ╟─54c6bde0-67db-45cf-9069-c5c8dd143bd2
# ╠═82501bac-9e84-4741-ac33-3d502878fc80
# ╠═a325e387-6f7f-4171-88bf-0ed579d9a227
# ╠═27a6c5fb-5fae-4a1f-97ac-b1617f432281
# ╟─a035df5e-e157-4c37-88ea-99f77d592013
# ╟─3b139efb-d1e9-4d0c-92e5-9d54939706ad
# ╟─82476ef7-a464-420b-8255-197ab6f62c3a
# ╟─516a38e6-d413-4eee-bca7-80ab16c5c80d
# ╟─25b7a736-df65-4bb7-9c2c-1c1bd1e9e6eb
# ╟─baf244b9-c835-4c4d-a1d7-64dbe4da6377
# ╠═846202be-e05f-4360-acd4-f9f342aeea28
# ╠═b8ba41f1-d226-4624-b118-22bbfadd7ad4
# ╟─3ec264ce-9465-4a55-9407-87221027ba6e
# ╟─3ccc941b-8823-4718-b751-de125d425f32
# ╟─90d77c0f-7869-4abd-98f1-3f7556164ca9
# ╠═2438877a-fe67-4acb-8c01-d64c6e3c774b
# ╟─c654f9e6-2b5d-4d7b-891d-a7a94e5b500f
# ╟─3d60ea9c-d8c6-41fa-a672-5a70c2cee160
# ╟─296cb140-c8d9-4648-886e-b55de05ec849
# ╟─c8454699-0c4f-42d2-97b9-319821f5d323
# ╠═0e4d7351-2db0-4dca-99ae-74b6669ff80e
# ╟─99b8afcd-0247-47af-8d23-14f90ccaa4ac
# ╠═b00a7fdc-12a6-42d1-98fc-5c8b17a27d5c
# ╠═cd573427-5a2b-423f-aba6-82fde7a1fb18
# ╟─926ba393-a9d8-4a42-961f-eaae680cf56f
# ╠═be8e03c2-f3ba-4ac4-9297-edd70b885b3b
# ╠═141c94bc-1670-42e5-82bd-dbb3244199d5
# ╟─6844910c-1ab1-4578-9c7b-aa4b1d68a5a0
# ╟─c0665287-0771-4b29-aee4-5ae2d2ccd5cb
# ╠═0e6277fd-9bd8-4672-9fc6-5af77d9406e3
# ╟─6b9e7a0a-eb83-4b4f-9b1b-2cc483555a1e
# ╟─0883e298-330e-4f9c-914d-5bbb2e738430
# ╟─3e9cf64a-0b73-4193-ae39-ab54d916fbc9
# ╟─dd3c5f71-ce80-4f67-8c81-5a6162b94220
# ╟─f8446a1d-2cf6-4ddb-9b34-64d099d2ef6e
# ╠═6de56fd5-44b5-4b9e-822f-a075f89375a2
# ╟─052d534d-2673-4ed9-829b-ded0f27e0329
# ╠═ede95350-6cc4-4f43-81e7-5e8f1621cd51
# ╠═bd46bad1-8185-4984-9cc8-411ee567d870
# ╠═f5776071-274d-4088-b1b1-9a014f91fdb8
# ╠═ccd5fa0f-1aef-49ef-a0a2-e44b55ebfb74
