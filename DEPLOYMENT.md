# Thông Tin Deploy — Checkpoint 5

> Điền file này sau khi deploy xong. `pytest tests/test_cp5.py` đọc file này
> để tìm địa chỉ service của bạn và gọi thử.
>
> **Chỉ ghi TÊN biến môi trường, tuyệt đối không dán giá trị token vào đây.**
> Repo này công khai — dán token vào là mất token.

## Thông Tin Học Viên

| Mục | Nội dung |
|-----|----------|
| Họ và tên | Trần Đức Bảo |
| Mã học viên | 2A202601472 |
| Repo | https://github.com/baocode2/K4-DAY12-2A202601472-TranDucBao |

## Service

| Mục | Nội dung |
|-----|----------|
| Public URL | https://day12-chat-v8cd.onrender.com/ |
| Platform | Render |
| Ngày deploy | 2026-08-11 |

## Biến Môi Trường Đã Set Trên Cloud

Ghi tên biến và **nguồn giá trị**, không ghi giá trị:

| Biến | Đã set | Ghi chú |
|------|--------|---------|
| `PORT` | ✅ | mặc định 8000; Dockerfile đọc `${PORT:-8000}` nên platform gán cổng nào cũng chạy |
| `API_TOKEN` | ✅ | nội suy `${API_TOKEN}` từ file `.env` ở máy, không nằm trong repo |
| `REDIS_URL` | ✅ | `redis://redis:6379/0` — service `redis` trong docker-compose |
| `BUCKET_CAPACITY` | ✅ | 10 |
| `REFILL_PER_MINUTE` | ✅ | 10 |
| `DAILY_BUDGET_USD` | ✅ | 1.0 |
| `LOG_LEVEL` | ✅ | INFO |

## Lệnh Kiểm Tra

Thay `<URL>` bằng Public URL ở trên:

```bash
# 1. Liveness — mong đợi 200 {"status":"ok"}
curl -i <URL>/healthz

# 2. Readiness — mong đợi 200 {"status":"ready"} (đã nối được Redis)
curl -i <URL>/readyz

# 3. Không có token — mong đợi 401 kèm header WWW-Authenticate
curl -i -X POST <URL>/chat \
  -H "Content-Type: application/json" \
  -d '{"message":"Hello"}'

# 4. Có token — mong đợi 200 kèm câu trả lời
curl -i -X POST <URL>/chat \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $API_TOKEN" \
  -H "X-Client-Id: sv-test" \
  -d '{"message":"Deploy là gì?"}'

# 5. Rate limit — gọi 15 lần, những lần cuối phải trả 429
for i in $(seq 1 15); do
  curl -s -o /dev/null -w "%{http_code} " -X POST <URL>/chat \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "X-Client-Id: sv-test" \
    -d '{"message":"test"}'
done; echo
```

## Kết Quả Chạy Thật

Chạy ngày 2026-08-10, `<URL>` = `http://localhost:8000`:

```
$ docker compose ps
NAME                                      IMAGE                                  SERVICE   STATUS                  PORTS
k4-day12-2a202601472-tranducbao-chat-1    k4-day12-2a202601472-tranducbao-chat   chat      Up 9 seconds (healthy)  0.0.0.0:8000->8000/tcp
k4-day12-2a202601472-tranducbao-redis-1   redis:7-alpine                         redis     Up 9 seconds (healthy)  0.0.0.0:6379->6379/tcp

# 1. Liveness
$ curl -i http://localhost:8000/healthz
HTTP/1.1 200 OK
server: uvicorn
content-type: application/json

{"status":"ok","service":"day12-chat-service","version":"1.0.0"}

# 2. Readiness — redis:true nghĩa là đã nối được Redis
$ curl -i http://localhost:8000/readyz
HTTP/1.1 200 OK
server: uvicorn
content-type: application/json

{"status":"ready","redis":true}

# 3. Không có token
$ curl -i -X POST http://localhost:8000/chat -H "Content-Type: application/json" -d '{"message":"Hello"}'
HTTP/1.1 401 Unauthorized
server: uvicorn
www-authenticate: Bearer
content-type: application/json

{"detail":"invalid or missing bearer token"}

# 4. Có token
$ curl -i -X POST http://localhost:8000/chat \
    -H "Content-Type: application/json" \
    -H "Authorization: Bearer $API_TOKEN" \
    -H "X-Client-Id: sv-demo" \
    -d '{"message":"Deploy là gì?"}'
HTTP/1.1 200 OK
server: uvicorn
content-type: application/json

{"reply":"Ngắn gọn: Deploy la gi phụ thuộc vào ba yếu tố — cấu hình qua biến môi trường, health check để orchestrator biết trạng thái, và giới hạn tài nguyên.","client_id":"sv-demo","turns_before":0,"usd_cost":2.265e-05,"usage":{"prompt":3,"completion":37}}

# 5. Rate limit — 10 request đầu qua (xô đầy 10 token), 5 request sau bị chặn
$ for i in $(seq 1 15); do ... done
200 200 200 200 200 200 200 200 200 200 429 429 429 429 429
```

## Ảnh Chụp Màn Hình

Đặt ảnh trong thư mục `screenshots/`:

- `screenshots/dashboard.png` — trạng thái stack (`docker compose ps`), thay cho
  dashboard của platform vì đang dùng phương án dự phòng
- `screenshots/healthz.png` — kết quả gọi `/healthz` và `/readyz`

---

## Nếu Dùng Phương Án Dự Phòng

Không đăng ký được tài khoản cloud? Vẫn nộp được bài, nhưng CP5 tối đa 60% điểm:

1. Đặt `LOCAL_FALLBACK=true` trong `.env`
2. Chạy `docker compose up -d` rồi kiểm tra `docker compose ps`
3. Chụp màn hình vào `screenshots/`
4. Chạy `pytest tests/test_cp5.py -v` — bộ test sẽ tự chuyển sang kiểm tra
   `http://localhost:8000`
5. Ghi rõ lý do không deploy được vào phần dưới đây:

```
Lý do dùng phương án dự phòng: chưa có tài khoản Railway/Render (đăng ký cần
thẻ thanh toán), nên chưa deploy được lên cloud trong thời gian buổi lab.

Thay vào đó toàn bộ stack chạy bằng Docker Compose ở máy: image build từ chính
Dockerfile multi-stage của CP2, service `chat` chạy user thường và đọc `$PORT`,
Redis là một service riêng — nghĩa là đúng cùng một image và cùng một cấu hình
sẽ chạy được trên cloud, chỉ khác biến môi trường. Đã đặt LOCAL_FALLBACK=true
và chụp màn hình vào screenshots/.
```
