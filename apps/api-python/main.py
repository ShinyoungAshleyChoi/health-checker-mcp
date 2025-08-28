import os
import json
import asyncio
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any
from contextlib import asynccontextmanager

import pandas as pd
import pyarrow as pa
import pyarrow.parquet as pq
from fastapi import FastAPI, HTTPException, Request, BackgroundTasks
from pydantic import BaseModel, Field
import uvicorn
import uuid
import shutil


# 데이터 모델 정의
class HealthData(BaseModel):
    """iOS 앱에서 전송되는 건강 데이터 모델"""
    stepCount: Optional[float] = None
    heartRate: Optional[float] = None
    activeEnergyBurned: Optional[float] = None
    distanceWalkingRunning: Optional[float] = None
    bodyMass: Optional[float] = None
    height: Optional[float] = None
    timestamp: str
    deviceId: Optional[str] = None
    userId: Optional[str] = None


class ParquetManager:
    """Parquet 파일 관리 클래스"""

    def __init__(self, data_dir: str = "data"):
        self.data_dir = Path(data_dir)
        self.data_dir.mkdir(exist_ok=True)

    def get_partition_dir(self, date_str: Optional[str] = None) -> Path:
        """날짜별 파티션 디렉터리 경로 반환 (예: year=2025/month=08/day=28)"""
        if date_str is None:
            ts = datetime.now()
        else:
            ts = datetime.strptime(date_str, "%Y-%m-%d")
        return self.data_dir / f"year={ts.year:04d}/month={ts.month:02d}/day={ts.day:02d}"

    async def append_to_parquet(self, health_data: HealthData):
        """건강 데이터를 parquet 파일에 추가"""
        try:
            # 현재 날짜로 파티션 디렉터리 결정
            timestamp = datetime.fromisoformat(health_data.timestamp.replace('Z', '+00:00'))
            date_str = timestamp.strftime("%Y-%m-%d")
            partition_dir = self.get_partition_dir(date_str)
            partition_dir.mkdir(parents=True, exist_ok=True)

            # 데이터를 DataFrame으로 변환
            data_dict = health_data.model_dump()
            data_dict['processed_at'] = datetime.now().isoformat()

            # 단일 행 DataFrame 생성 후 part 파일로 저장
            new_df = pd.DataFrame([data_dict])
            part_path = partition_dir / f"part-{uuid.uuid4()}.parquet"
            new_df.to_parquet(part_path, engine='pyarrow', compression='snappy')

            return {
                "status": "success",
                "file_path": str(part_path),
                "records_count": 1
            }

        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f"Parquet 저장 중 오류가 발생했습니다: {str(e)}"
            )

    async def read_parquet_data(self, date_str: str = None, limit: int = 100) -> Dict[str, Any]:
        """Parquet 파일에서 데이터 읽기"""
        try:
            partition_dir = self.get_partition_dir(date_str)
            if not partition_dir.exists():
                return {
                    "status": "not_found",
                    "message": f"디렉터리를 찾을 수 없습니다: {partition_dir}"
                }

            files = sorted(partition_dir.glob("*.parquet"))
            if not files:
                return {
                    "status": "not_found",
                    "message": f"해당 날짜에 저장된 파케이 파일이 없습니다: {partition_dir}"
                }

            # 모든 part 파일을 읽어서 병합
            df_list = [pd.read_parquet(fp) for fp in files]
            df = pd.concat(df_list, ignore_index=True)

            # 최신 데이터부터 limit만큼 반환
            df_limited = df.tail(limit)

            # NaN 값을 None으로 변환하여 JSON 직렬화 가능하게 만들기
            df_limited = df_limited.where(pd.notnull(df_limited), None)

            return {
                "status": "success",
                "date": date_str or datetime.now().strftime("%Y-%m-%d"),
                "total_records": len(df),
                "returned_records": len(df_limited),
                "data": df_limited.to_dict('records')
            }

        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f"Parquet 읽기 중 오류가 발생했습니다: {str(e)}"
            )

    async def get_file_stats(self) -> Dict[str, Any]:
        """저장된 Parquet 파일들의 통계 정보"""
        try:
            files = list(self.data_dir.rglob("*.parquet"))
            stats = []

            for file_path in files:
                df = pd.read_parquet(file_path)
                file_size = file_path.stat().st_size

                stats.append({
                    "path": str(file_path.relative_to(self.data_dir)),
                    "records_count": len(df),
                    "file_size_bytes": file_size,
                    "file_size_mb": round(file_size / (1024 * 1024), 2),
                    "created_at": datetime.fromtimestamp(file_path.stat().st_ctime).isoformat(),
                    "modified_at": datetime.fromtimestamp(file_path.stat().st_mtime).isoformat()
                })

            return {
                "status": "success",
                "total_files": len(files),
                "files": stats
            }

        except Exception as e:
            raise HTTPException(
                status_code=500,
                detail=f"통계 조회 중 오류가 발생했습니다: {str(e)}"
            )


# 전역 Parquet 매니저 인스턴스
parquet_manager = ParquetManager()


@asynccontextmanager
async def lifespan(app: FastAPI):
    """앱 시작/종료 시 실행되는 컨텍스트 매니저"""
    print("🚀 MCP 서버가 시작되었습니다.")
    print(f"📁 데이터 저장 경로: {parquet_manager.data_dir.absolute()}")
    yield
    print("🔄 MCP 서버가 종료됩니다.")


# FastAPI 앱 생성
app = FastAPI(
    title="Health Checker MCP Server",
    description="iOS 앱에서 전송되는 건강 데이터를 받아 Parquet 파일로 저장하는 MCP 서버",
    version="1.0.0",
    lifespan=lifespan
)


@app.get("/")
async def root():
    """루트 엔드포인트"""
    return {
        "message": "Health Checker MCP Server",
        "version": "1.0.0",
        "endpoints": {
            "health": "/health",
            "receive_data": "/health-data",
            "query_data": "/health-data/{date}",
            "file_stats": "/files/stats"
        }
    }


@app.get("/health")
async def health_check():
    """서버 상태 확인"""
    return {
        "status": "healthy",
        "timestamp": datetime.now().isoformat(),
        "data_directory": str(parquet_manager.data_dir.absolute())
    }


@app.post("/health-data")
async def receive_health_data(
    health_data: HealthData,
    background_tasks: BackgroundTasks,
    request: Request
):
    """iOS 앱에서 전송되는 건강 데이터 수신 및 저장"""
    try:
        print(f"📱 건강 데이터 수신: {health_data.model_dump()}")

        # 백그라운드에서 Parquet 저장 처리
        result = await parquet_manager.append_to_parquet(health_data)

        return {
            "status": "success",
            "message": "건강 데이터가 성공적으로 저장되었습니다.",
            "parquet_info": result,
            "received_at": datetime.now().isoformat()
        }

    except Exception as e:
        print(f"❌ 오류 발생: {str(e)}")
        raise HTTPException(
            status_code=500,
            detail=f"건강 데이터 처리 중 오류가 발생했습니다: {str(e)}"
        )


@app.get("/health-data")
async def get_health_data(
    date: Optional[str] = None,
    limit: int = 100
):
    """저장된 건강 데이터 조회 (날짜별)"""
    return await parquet_manager.read_parquet_data(date, limit)


@app.get("/health-data/{date}")
async def get_health_data_by_date(date: str, limit: int = 100):
    """특정 날짜의 건강 데이터 조회"""
    try:
        # 날짜 형식 검증
        datetime.strptime(date, "%Y-%m-%d")
        return await parquet_manager.read_parquet_data(date, limit)
    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="올바른 날짜 형식을 사용해주세요 (YYYY-MM-DD)"
        )


@app.get("/files/stats")
async def get_file_statistics():
    """저장된 Parquet 파일들의 통계 정보"""
    return await parquet_manager.get_file_stats()


@app.delete("/health-data/{date}")
async def delete_health_data(date: str):
    """특정 날짜의 건강 데이터 파일 삭제"""
    try:
        # 날짜 형식 검증
        datetime.strptime(date, "%Y-%m-%d")

        partition_dir = parquet_manager.get_partition_dir(date)

        if not partition_dir.exists():
            raise HTTPException(
                status_code=404,
                detail=f"해당 날짜의 데이터 디렉터리가 존재하지 않습니다: {date}"
            )

        shutil.rmtree(partition_dir)

        return {
            "status": "success",
            "message": f"{date} 날짜의 건강 데이터가 삭제되었습니다.",
            "deleted_path": str(partition_dir)
        }

    except ValueError:
        raise HTTPException(
            status_code=400,
            detail="올바른 날짜 형식을 사용해주세요 (YYYY-MM-DD)"
        )


if __name__ == "__main__":
    uvicorn.run(
        "main:app",
        host="0.0.0.0",
        port=8000,
        reload=True,
        log_level="info"
    )
