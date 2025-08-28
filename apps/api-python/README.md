# Health Checker MCP Server

iOS 앱에서 전송되는 건강 데이터를 받아서 Parquet 파일로 저장하는 MCP 서버입니다.

## 기능

- ✅ iOS 건강 앱 데이터 수신
- ✅ 자동 Parquet 파일 저장 (날짜별 분리)
- ✅ 데이터 조회 API
- ✅ 파일 통계 조회
- ✅ 데이터 삭제 기능

## 설치 및 실행

```bash
# 의존성 설치
cd apps/api-python
uv sync

# 서버 실행
uv run uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

## API 엔드포인트

### 1. 건강 체크
```bash
GET /health
```

### 2. 건강 데이터 전송 (iOS 앱에서 사용)
```bash
POST /health-data
Content-Type: application/json

{
    "stepCount": 8500.0,
    "heartRate": 72.0,
    "activeEnergyBurned": 350.5,
    "distanceWalkingRunning": 6.2,
    "bodyMass": 70.5,
    "height": 175.0,
    "timestamp": "2025-08-28T14:30:00Z",
    "deviceId": "iPhone-12345",
    "userId": "user-abc"
}
```

### 3. 데이터 조회
```bash
# 오늘 데이터 조회
GET /health-data?limit=100

# 특정 날짜 데이터 조회
GET /health-data/2025-08-28?limit=50
```

### 4. 파일 통계
```bash
GET /files/stats
```

### 5. 데이터 삭제
```bash
DELETE /health-data/2025-08-28
```

## 데이터 저장 구조

- 데이터는 `data/` 폴더에 날짜별로 저장됩니다
- 파일명 형식: `health_data_YYYY-MM-DD.parquet`
- Parquet 형식으로 압축 저장 (Snappy 압축)

## 데이터 스키마

```python
{
    "stepCount": float,                    # 걸음 수
    "heartRate": float,                    # 심박수
    "activeEnergyBurned": float,           # 활동 에너지 소모량
    "distanceWalkingRunning": float,       # 걷기/뛰기 거리
    "bodyMass": float,                     # 체중
    "height": float,                       # 신장
    "timestamp": str,                      # 타임스탬프 (ISO 형식)
    "deviceId": str,                       # 디바이스 ID (선택사항)
    "userId": str,                         # 사용자 ID (선택사항)
    "processed_at": str                    # 서버 처리 시각 (자동 추가)
}
```

## 테스트

```bash
# 건강 체크
curl http://localhost:8000/health

# 샘플 데이터 전송
curl -X POST http://localhost:8000/health-data \
  -H "Content-Type: application/json" \
  -d '{
    "stepCount": 8500,
    "heartRate": 72,
    "activeEnergyBurned": 350.5,
    "timestamp": "2025-08-28T14:30:00Z"
  }'

# 데이터 조회
curl http://localhost:8000/health-data

# 파일 통계 확인
curl http://localhost:8000/files/stats
```
