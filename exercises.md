# Phiếu Phản Ánh — K4 Ngày 12

> **Bài làm cá nhân.** Trả lời bằng lời của chính bạn, dựa trên những gì bạn
> quan sát được khi chạy code — không sao chép đáp án của người khác.
> `grade.py` đếm số câu đã trả lời (15 điểm cho 10 câu).
>
> Họ và tên: Trần Đức Bảo  Mã học viên: 2A202601472

---

### Câu 1 — Fail fast (CP1)

Trong `Settings`, `api_token` không có giá trị mặc định nên app chết ngay khi
khởi động nếu thiếu biến môi trường. Hãy mô tả một tình huống cụ thể mà việc
"chết sớm" này cứu bạn, so với việc để mặc định `"changeme"`.

> *Tình huống: tôi deploy service lên platform, gõ tên biến sai thành
> `API-TOKEN` (gạch ngang thay vì gạch dưới) trong phần Variables. Với thiết kế
> hiện tại, `Settings()` không tìm thấy `API_TOKEN` nên pydantic raise
> `ValidationError` ngay trong `get_settings()` lúc import `app.main` —
> container không lên nổi, `/healthz` không bao giờ trả 200, platform báo deploy
> failed và **giữ nguyên bản cũ đang chạy**. Tôi mất 2 phút đọc log rồi sửa tên
> biến.*
>
> *Nếu để mặc định `"changeme"`: container khởi động bình thường, health check
> xanh, deploy "thành công". Endpoint `/chat` khi đó vẫn được bảo vệ — nhưng
> bằng một token mà cả lớp, cả Internet đều đoán được, vì nó nằm trong source
> code công khai trên GitHub. Không có gì báo lỗi cả: log sạch, dashboard xanh.
> Tôi chỉ phát hiện ra khi thấy hóa đơn LLM hoặc khi `cost_guard` bắt đầu trả
> 402 cho `client_id` mà tôi không biết là ai — nghĩa là phát hiện* sau khi *đã
> mất tiền và lộ dữ liệu hội thoại. Lỗi cấu hình vẫn là lỗi cấu hình, khác nhau
> ở chỗ nó nổ lúc khởi động (rẻ, dễ sửa) hay nổ trong hóa đơn (đắt, khó sửa).*

---

### Câu 2 — Log cho máy đọc (CP1)

Chạy service và gọi `/chat` vài lần. Dán một dòng log JSON bạn thu được, rồi
nêu **hai** việc bạn làm được với dòng log đó mà `print("đã trả lời xong")`
không làm được.

> *Dòng log thật tôi thu được khi gọi `/chat`:*
>
> ```json
> {"event": "chat_completed", "severity": "INFO", "ts": "2026-08-11T02:18:33.420045+00:00", "client_id": "sv-demo", "prompt_tokens": 3, "completion_tokens": 37, "usd_cost": 2.265e-05}
> ```
>
> *Hai việc tôi làm được với dòng này mà `print("đã trả lời xong")` chịu:*
>
> 1. ***Tính tiền và tìm ra ai đốt tiền.** Vì `usd_cost` và `client_id` là hai
>    trường riêng có kiểu số/chuỗi, tôi lọc log cả ngày rồi cộng dồn theo
>    client — ví dụ trên Cloud Logging: `jsonPayload.event="chat_completed"`
>    rồi group theo `jsonPayload.client_id`, sum `jsonPayload.usd_cost`. Ở máy
>    thì `docker compose logs chat | jq -s 'map(select(.event=="chat_completed"))
>    | group_by(.client_id) | map({client: .[0].client_id, usd: (map(.usd_cost)
>    | add)})'`. Với một câu tiếng Việt in ra màn hình thì không có con số nào
>    để cộng, cũng không biết của client nào.*
> 2. ***Đặt cảnh báo tự động.** Tôi tạo alert dạng "trong 5 phút, tổng
>    `usd_cost` của một `client_id` vượt $0.5" hoặc "`completion_tokens` trung
>    bình tăng gấp 3 so với hôm qua" — máy so sánh được vì đó là số. Ngoài ra
>    `severity` viết hoa đúng quy ước nên Cloud Logging tự phân loại
>    INFO/ERROR, và `ts` theo ISO-8601 UTC nên tôi ghép được log của 3 instance
>    lại theo đúng trình tự thời gian để dựng lại một sự cố. `print` chỉ cho
>    tôi grep chuỗi, và grep thì không biết đếm tiền.*

---

### Câu 3 — Kích thước image (CP2)

Build cả hai phiên bản và ghi lại số đo thật:

```bash
docker build -f <Dockerfile-1-stage> -t chat:single .
docker build -t chat:multi .
docker images | grep chat
```

| Bản | Dung lượng |
|-----|-----------|
| 1 stage (bản đầu) | 1730 MB (1.73 GB) |
| Multi-stage | 270 MB |

Giải thích: phần dung lượng chênh lệch đó là những gì?

> *Số đo thật trên máy tôi (`docker images`): `chat:single` 1.73GB,
> `chat:multi` 270MB — chênh khoảng 1.46GB, tức bản multi-stage chỉ còn ~15%.*
>
> *Chỗ chênh lệch gồm hai phần, và phần lớn hơn không nằm ở multi-stage:*
>
> 1. ***Đổi base image (`python:3.11` → `python:3.11-slim`), chiếm phần lớn.**
>    Bản đầy đủ mang theo cả bộ toolchain build: gcc/g++, make, các gói `-dev`,
>    git, và một đống thư viện hệ thống chỉ để phòng khi có package nào cần
>    biên dịch từ source. Riêng bộ này đã hơn 800MB. Bản slim chỉ có Python +
>    vài thư viện chạy tối thiểu (~130MB).*
> 2. ***Multi-stage: vứt lại mọi thứ của quá trình cài đặt.** Stage `builder`
>    chạy `pip install --prefix=/install`, stage `runtime` chỉ
>    `COPY --from=builder /install /usr/local`. Nghĩa là image cuối chỉ có* kết
>    quả *cài đặt, còn source tarball đã tải, wheel dựng dở, cache của pip, file
>    tạm trong `/root/.cache` đều nằm lại ở stage builder và không được đóng vào
>    image. Điều này quan trọng vì layer trong Docker chỉ cộng dồn: ở bản 1
>    stage, dù có `rm -rf` cache ở lệnh sau thì dung lượng của layer trước vẫn
>    còn nguyên trong image, xóa chỉ là che đi.*
>
> *Cái tôi thật sự được lợi không chỉ là số MB: image nhỏ thì pull nhanh hơn khi
> scale hoặc rollback (quan trọng lúc 2h sáng), và quan trọng hơn là bề mặt tấn
> công nhỏ hơn — trong image cuối không còn gcc, không còn git, nên kẻ chạy
> được lệnh trong container cũng không có sẵn công cụ để biên dịch/tải thêm đồ.*

---

### Câu 4 — Thứ tự lệnh trong Dockerfile (CP2)

Sửa một ký tự trong `app/main.py` rồi build lại. Với Dockerfile của bạn, những
layer nào được dùng lại từ cache, layer nào phải chạy lại? Nếu bạn đặt
`COPY . .` lên trước `RUN pip install` thì kết quả khác thế nào?

> *Tôi thêm đúng một dòng comment vào `app/main.py` rồi
> `docker build -t chat:multi . --progress=plain`. Kết quả thật:*
>
> ```
> #7  [builder 2/4] WORKDIR /app                                          CACHED
> #9  [builder 3/4] COPY requirements.txt .                               CACHED
> #10 [builder 4/4] RUN pip install --no-cache-dir --prefix=/install ...  CACHED
> #11 [runtime 2/5] COPY --from=builder /install /usr/local               CACHED
> #8  [runtime 3/5] RUN useradd --create-home appuser                     CACHED
> #12 [runtime 4/5] WORKDIR /app                                          CACHED
> #13 [runtime 5/5] COPY --chown=appuser:appuser . .                      DONE 0.1s
> ```
>
> *Tức là **mọi layer đều lấy từ cache, chỉ layer cuối `COPY . .` chạy lại**, và
> vì layer đó chỉ copy vài chục KB source nên cả lần build mất hơn một giây
> (phần lớn thời gian còn lại là kiểm tra metadata của base image trên mạng).*
>
> *Lý do: Docker băm nội dung của từng lệnh và của file được copy.
> `requirements.txt` không đổi → layer `COPY requirements.txt .` giữ nguyên hash
> → layer `RUN pip install` phía sau nó cũng hợp lệ, dùng lại được. Sửa
> `app/main.py` chỉ làm hỏng hash từ `COPY . .` trở đi.*
>
> *Nếu đặt `COPY . .` **trước** `RUN pip install`: sửa một ký tự trong bất kỳ
> file nào — kể cả README — cũng làm layer `COPY . .` khác đi, và vì cache là
> chuỗi phụ thuộc, mọi layer sau nó mất hiệu lực theo. `pip install` phải chạy
> lại từ đầu: tải lại toàn bộ package từ PyPI và cài lại. Trên máy tôi bước này
> tốn khoảng một phút rưỡi và cần mạng — nhân với mỗi lần sửa code trong ngày,
> và nhân tiếp cho mỗi lần CI chạy. Nguyên tắc rút ra: **xếp các lệnh theo tần
> suất thay đổi, thứ ít đổi nhất lên trên** (base image → requirements → cài
> dependency → source code), vì cache chỉ sống được tới layer đầu tiên bị đổi.*

---

### Câu 5 — Vì sao không chạy bằng root (CP2)

Container mặc định chạy bằng root. Mô tả chuỗi sự kiện dẫn từ "một lỗ hổng
trong code Python của bạn" tới "kẻ tấn công có quyền cao trên máy host", và
lệnh `USER` cắt đứt chuỗi đó ở chỗ nào.

> *Chuỗi sự kiện, từng mắt xích một:*
>
> 1. ***Có lỗ hổng ở tầng app.** Ví dụ tôi lỡ đưa nội dung người dùng gửi vào
>    một chỗ chạy được code (một `eval`, một template không escape, hoặc một
>    thư viện deserialize dữ liệu không tin cậy). Kẻ tấn công gửi payload qua
>    `POST /chat` và thực thi được lệnh tùy ý **bên trong container**.*
> 2. ***Leo quyền trong container.** Nếu process chạy bằng root, kẻ đó là root
>    của container: ghi đè được `/usr/local/lib/python3.11/...` để cài backdoor
>    sống sót qua restart, đọc mọi file, cài thêm công cụ, chỉnh cấu hình mạng.
>    Nếu image lại là bản đầy đủ thì sẵn cả gcc/git để dựng đồ.*
> 3. ***Thoát ra host.** Đây là mắt xích cần quyền root: khai thác một lỗ hổng
>    container escape của kernel/runtime (loại CVE runc/containerd vẫn ra đều
>    hằng năm), hoặc lạm dụng cấu hình sai — container chạy `--privileged`,
>    mount `/var/run/docker.sock`, hay bind-mount một thư mục của host. Ví dụ
>    kinh điển: có `docker.sock` thì gọi API Docker tạo một container mới mount
>    `/` của host rồi ghi vào `/etc/shadow`.*
> 4. ***Trên host.** UID 0 trong container ánh xạ thành UID 0 trên host (trừ khi
>    bật user namespace remapping — mặc định thì không). Thoát ra là thành root
>    thật: đọc secret của các service khác trên cùng máy, đi ngang sang container
>    khác, cài persistence.*
>
> *`USER appuser` cắt ở **mắt xích 2**, và nhờ đó mắt xích 3–4 phần lớn không
> xảy ra được. Sau lệnh đó process chạy bằng UID thường: không ghi được vào
> `/usr/local` hay `/etc` (chỉ ghi được `/home/appuser` và `/tmp`), không cài
> thêm được package, không bind được cổng < 1024, và hầu hết đường thoát
> container đều đòi capability chỉ root mới có. Lỗ hổng ở bước 1 vẫn là lỗ
> hổng — kẻ tấn công vẫn đọc được biến môi trường trong process, nên vẫn phải
> vá — nhưng thiệt hại dừng lại ở phạm vi một container dùng-một-lần, thay vì
> lan ra cả máy host. Trong Dockerfile của tôi,
> `COPY --chown=appuser:appuser . .` đặt ngay trước `USER appuser` để `appuser`
> đọc được code mà vẫn không cần quyền ghi ở nơi khác.*

---

### Câu 6 — Bearer token (CP3)

Vì sao 401 phải kèm header `WWW-Authenticate: Bearer`? Và vì sao ta trả **cùng
một** thông báo lỗi cho cả ba trường hợp (thiếu header, sai scheme, sai token)
thay vì nói rõ sai ở đâu cho người dùng dễ sửa?

> ***Vì sao phải có `WWW-Authenticate`:** RFC 7235 quy định 401* bắt buộc *kèm
> header này — 401 nghĩa là "anh chưa xác thực", và header trả lời tiếp câu
> "xác thực kiểu gì". Nhờ đó client là máy biết đường xử lý mà không cần đọc
> tài liệu: thư viện HTTP thấy `Bearer` thì đi lấy token rồi thử lại, thấy
> `Basic` thì hỏi user/pass, thấy `Bearer realm=..., error="invalid_token"` thì
> biết cần refresh token. Đây cũng là chỗ phân biệt với 403: 401 + header là
> "thử lại với chứng danh hợp lệ", 403 là "biết anh là ai rồi, vẫn không cho".
> Trong `app/auth.py` tôi đặt header này vào một chỗ duy nhất là
> `_unauthorized()` nên không có nhánh nào trả 401 mà quên header.*
>
> ***Vì sao ba trường hợp chung một thông báo:** thông báo lỗi chi tiết là một
> kênh rò rỉ thông tin (oracle) cho người đang dò. Nếu tôi trả "sai scheme" khi
> gõ `Basic` nhưng "token không đúng" khi gõ `Bearer abc`, kẻ dò biết ngay đã
> đúng định dạng và chỉ còn phải đoán giá trị — mỗi câu trả lời khác nhau là
> một bit thông tin dẫn hắn đi đúng hướng. Tệ hơn nữa là những thông báo kiểu
> "token đã hết hạn" (xác nhận token có thật) hay "token phải dài 43 ký tự"
> (thu hẹp không gian tìm kiếm). Một câu duy nhất
> `"invalid or missing bearer token"` khiến mọi request sai đều trả lời giống
> hệt nhau, kẻ dò không học được gì. Cùng lý do đó, tôi so sánh token bằng
> `secrets.compare_digest` chứ không phải `==`: `==` dừng ở ký tự đầu tiên khác
> nhau nên* thời gian phản hồi *cũng là một oracle, đoán được token từng ký tự.*
>
> *Còn lập trình viên tử tế thì không thiệt thòi gì: HTTP đã nói rõ 401 +
> `WWW-Authenticate: Bearer`, tài liệu API nói rõ phải gửi header nào, và khi
> cần điều tra thì log phía server ghi đủ chi tiết. Nguyên tắc là **chi tiết đi
> vào log của tôi, không đi ra response cho người lạ**.*

---

### Câu 7 — Token bucket (CP3)

Với `capacity=10`, `refill_per_minute=10`: một client im lặng 10 phút rồi gửi
liên tiếp. Nó gửi được bao nhiêu request trước khi bị 429? Nếu bỏ đoạn
`min(capacity, ...)` trong `available()` thì con số đó thành bao nhiêu, và tại sao?

> ***Có `min(capacity, ...)`: 10 request, request thứ 11 bị 429.**
> Im lặng 10 phút thì token nhỏ thêm được `600s × (10/60) = 100` token, nhưng
> `min(10.0, tokens)` cắt lại đúng sức chứa: `available()` trả về 10.0. Gửi
> liên tiếp (trong khoảng một giây, phần nạp thêm chưa tới 0.2 token) thì tiêu
> hết 10 token; tới lần thứ 11, `tokens < 1` nên `consume()` raise 429 kèm
> `Retry-After` ≈ 7 giây — đúng bằng thời gian nhỏ đủ 1 token với tốc độ
> 1 token / 6 giây. Đây chính là hành vi mong muốn của token bucket: cho phép*
> bùng *đúng bằng sức chứa, rồi ép về đúng tốc độ trung bình đã cấu hình.*
>
> ***Bỏ `min(capacity, ...)`: khoảng 110 request** (chính xác là số token còn
> lại lúc im lặng cộng 100 — nếu lúc đó xô còn đầy 10 thì 110, nếu đã cạn về 0
> thì 100). Lý do: `tokens += (now - last) * refill_per_second` cộng dồn tuyến
> tính theo thời gian im lặng, không còn trần nào chặn. Sức chứa mất hết ý
> nghĩa; xô biến thành cái bể tích vô hạn.*
>
> *Con số đó nguy hiểm vì nó **tỉ lệ với thời gian im lặng**, mà thời gian im
> lặng thì kẻ tấn công tự chọn: im 1 giờ được 600 request, im một ngày được
> 14.400 request bắn hết trong vài giây. Nói cách khác, tôi vẫn có rate limit
> trên giấy tờ nhưng thực tế đã mất hoàn toàn khả năng chặn burst — đúng thứ
> mà rate limit sinh ra để bảo vệ (kết nối DB, quota LLM, CPU). Một dòng
> `min()` là ranh giới giữa "cho phép dùng dồn hợp lý" và "cho phép tích lũy
> vô hạn".*

---

### Câu 8 — Ngân sách theo ngày (CP3)

So sánh hạn mức $30/tháng với hạn mức $1/ngày cho cùng một client. Giả sử có sự
cố khiến một client gọi liên tục từ 2h sáng. Với mỗi cách, thiệt hại tối đa là
bao nhiêu và service tự hồi phục khi nào?

> *Hai hạn mức "bằng nhau" về tổng ($30/tháng ≈ $1/ngày × 30) nhưng khác hẳn về
> mức thiệt hại tối đa của một sự cố và về việc ai phải thức dậy.*
>
> ***$30/tháng.** Sự cố bắt đầu 2h sáng ngày 3 của tháng, client mới tiêu $2 →
> còn $28 để đốt. Không có gì chặn cho tới khi cạn sạch $28, mà với tốc độ gọi
> liên tục thì cạn trong vài giờ. **Thiệt hại tối đa: $28** (toàn bộ ngân sách
> còn lại của tháng — sự cố xảy ra càng sớm trong tháng, mất càng nhiều).
> Tệ hơn: khi hạn mức chạm trần, service trả 402 cho* tất cả *request của
> client đó và **không tự hồi phục cho tới ngày 1 tháng sau** — nghĩa là 28
> ngày chết dịch vụ, trừ khi có người tỉnh dậy nâng hạn mức bằng tay. Một sự cố
> ban đêm biến thành hai sự cố: mất tiền, rồi mất dịch vụ.*
>
> ***$1/ngày (cái tôi đang dùng, `DAILY_BUDGET_USD=1.0`).** Từ 2h sáng, client
> đốt hết $1 rồi `CostGuard.check()` trả 402 cho mọi request tiếp theo. Nếu sự
> cố bắt đầu sau 0h UTC thì hạn mức của ngày còn nguyên, **thiệt hại tối đa:
> $1** — bằng 1/30 phương án kia. Và vì key Redis là
> `spend:<client>:<YYYY-MM-DD>` theo ngày UTC, tới 0h UTC hôm sau `today()` trả
> nhãn ngày mới, `spent()` đọc key chưa tồn tại và trả 0.0 → **service tự hồi
> phục, không cần ai can thiệp**. Sáng ra tôi đọc log `chat_completed` để điều
> tra trong lúc dịch vụ đã chạy lại bình thường. Thời gian gián đoạn tối đa
> cũng có trần cứng: dưới 24 giờ, và tính được trước.*
>
> *Hai điểm nữa tôi rút ra: (1) hạn mức tính **theo từng `client_id`**, nên một
> client hỏng không tiêu lạm sang hạn mức của người khác; (2) cost guard bổ
> sung cho rate limit chứ không thay thế — token bucket chặn* số lượng *request,
> cost guard chặn* số tiền*, và một request 50k token vẫn lọt qua token bucket.
> Trong `/chat` tôi gọi `bucket.consume()` rồi `guard.check()` **trước** khi gọi
> `generate_reply()`, vì tiền mất ở bước gọi LLM — chặn sau khi gọi thì vừa trả
> tiền vừa trả lỗi.*

---

### Câu 9 — /healthz khác /readyz (CP4)

Nếu gộp hai endpoint làm một và cho nó kiểm tra Redis, chuyện gì xảy ra với cụm
3 container khi Redis mất kết nối 30 giây? Trả lời theo đúng thứ tự sự kiện.

> *Giả sử cụm 3 container A, B, C, endpoint gộp `/health` có gọi `store.ping()`,
> và orchestrator dùng nó cho **cả** liveness lẫn readiness (liveness fail 3
> lần liên tiếp, chu kỳ 10s → restart).*
>
> 1. ***t=0s** — Redis rớt (restart, đứt mạng, failover). Cả 3 container vẫn
>    sống, code vẫn chạy, chỉ mất một dependency.*
> 2. ***t=0–10s** — Probe đầu tiên chạm cả 3 container. `store.ping()` ném
>    exception → trả về False → `/health` trả 503. Vì đây cũng là readiness,
>    load balancer **rút cả 3 container ra khỏi pool cùng lúc**. Từ giây này
>    100% request người dùng nhận 502/503 — kể cả những request không cần Redis.*
> 3. ***t=10–30s** — Probe lần 2, lần 3 vẫn 503 (Redis chưa lên). Đồng hồ
>    liveness của cả 3 container chạy **đồng bộ với nhau**, vì chúng cùng hỏng
>    vì cùng một nguyên nhân bên ngoài.*
> 4. ***t≈30s** — Ngưỡng liveness chạm đáy: orchestrator kết luận cả 3 container
>    "chết" và **giết cả 3 cùng lúc**. Đúng thời điểm này thì Redis cũng vừa
>    trở lại — nhưng không còn container nào để phục vụ.*
> 5. ***t=30–60s** — Cả 3 container khởi động lại từ đầu: pull/khởi tạo process,
>    import app, chạy lifespan, warm-up. Trong suốt khoảng này dịch vụ vẫn tắt
>    hoàn toàn, dù nguyên nhân gốc đã hết từ giây 30. Kèm theo đó là mọi state
>    trong process bị xóa và một đợt kết nối đồng loạt đập vào Redis vừa hồi
>    tỉnh (thundering herd) — đủ để đánh sập nó lần nữa và mở màn vòng lặp
>    crash-loop.*
>
> *Tổng kết: **một sự cố 30 giây của dependency biến thành hơn 60 giây chết
> toàn cụm**, và mức nghiêm trọng bị khuếch đại chứ không được cách ly.*
>
> *Tách hai endpoint như tôi đang làm thì kịch bản khác hẳn: `/healthz` chỉ trả
> lời "process còn sống không?" — không chạm Redis, nên suốt 30 giây đó nó vẫn
> trả 200 và **không container nào bị restart**. `/readyz` gọi `store.ping()`
> nên trả 503 và load balancer tạm ngừng đẩy traffic; tới khi Redis lên,
> `/readyz` trả 200 trở lại và traffic tự chảy vào — hồi phục trong vài giây,
> không mất process nào. Nguyên tắc: **liveness chỉ hỏi về bản thân process
> (fail → restart mới sửa được), readiness được phép hỏi về dependency (fail →
> chỉ tạm rút khỏi pool)**. Trộn hai câu hỏi đó là biến "tạm ngừng nhận khách"
> thành "khai tử".*

---

### Câu 10 — Deploy thật (CP5)

Ghi lại **một** lỗi bạn gặp khi deploy lên cloud (build fail, health check
timeout, sai REDIS_URL, app không đọc `$PORT`...): thông báo lỗi là gì, bạn
tìm ra nguyên nhân bằng cách nào, và sửa ra sao?

> *Tôi dùng phương án dự phòng (Docker Compose ở máy, đã ghi lý do trong
> `DEPLOYMENT.md`), và lỗi đáng nhớ nhất là một **build fail** khi dựng lại
> image để đối chiếu dung lượng cho Câu 3:*
>
> ```
> ERROR: failed to build: failed to solve: process "/bin/sh -c pip install -r
> requirements.txt" did not complete successfully: exit code: 2
> ```
>
> ***Cách tôi lần ra nguyên nhân.** Đầu tiên tôi tách đôi giả thuyết: lỗi ở
> Dockerfile hay ở môi trường? Bản multi-stage build ngay sau đó lại chạy qua
> với cùng file `requirements.txt`, nên `requirements.txt` không thể là thủ
> phạm. Tôi build lại lần nữa bằng `--progress=plain` để xem log đầy đủ của
> từng bước thay vì chỉ dòng tổng kết — và lần này nó qua sạch. Một lệnh hỏng
> rồi tự hết khi chạy lại, với bước hỏng đúng là bước duy nhất cần mạng, thì
> nguyên nhân gần như chắc chắn là **kết nối tới PyPI bị gián đoạn giữa chừng**
> chứ không phải lỗi cấu hình.*
>
> ***Sửa thế nào.** Trước mắt là chạy lại build. Nhưng "chạy lại thì hết" không
> phải cách sửa, nên tôi rút ra hai điều cho lần deploy thật:
> `pip install --retries 5 --timeout 60` để bước này chịu được mạng chập chờn
> thay vì hỏng cả build; và ghim phiên bản trong `requirements.txt` (hiện đang
> để `>=`) để lần build hôm nay và lần build lúc rollback tháng sau cho ra đúng
> cùng một bộ thư viện.*
>
> ***Một lỗi nhỏ hơn cùng buổi**, cũng đáng ghi vì thông báo của nó rất dễ làm
> người ta đi sai hướng:*
>
> ```
> failed to connect to the docker API at npipe:////./pipe/dockerDesktopLinuxEngine;
> check if the path is correct and if the daemon is running
> ```
>
> *Đọc thoáng qua tưởng hỏng cấu hình Docker, thực ra chỉ là Docker Desktop chưa
> chạy sau khi khởi động lại máy — `docker.exe` vẫn có trong PATH nên lệnh vẫn
> gõ được, chỉ không có daemon ở đầu bên kia. Bài học chung của cả hai lỗi:
> **đọc đúng dòng lỗi cuối và hỏi "bước nào hỏng, bước đó cần gì"** (mạng?
> daemon? file?) trước khi lao vào sửa Dockerfile.*
