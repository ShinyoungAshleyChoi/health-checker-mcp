from fastapi import FastAPI, HTTPException, Request
from pydantic import BaseModel
from datetime import datetime
from typing import Optional
import sys
import json

app = FastAPI(title="Health Checker MCP API", version="1.0.0")

class HealthData(BaseModel):
    stepCount: Optional[float] = None
    heartRate: Optional[float] = None
    activeEnergyBurned: Optional[float] = None
    distanceWalkingRunning: Optional[float] = None
    bodyMass: Optional[float] = None
    height: Optional[float] = None
    timestamp: str

# In-memory storage for demo purposes
health_data_store = []

@app.get("/health")
def health():
  return {"ok": True}

@app.post("/health-data")
async def health_data(req: Request):
  data = await req.json()
  print("RECV:", data)  # 콘솔에 찍힘
  return {"received": True}

# @app.get("/")
# def read_root():
#     return {
#         "message": "Health Checker Python API",
#         "python_version": sys.version,
#         "endpoints": [
#             "/health",
#             "/health-data",
#             "/health-data/latest"
#         ]
#     }
#
# @app.get("/health")
# def health_check():
#     return {"status": "healthy", "python_version": sys.version}
#
# @app.post("/health-data")
# async def receive_health_data(health_data: HealthData):
#     try:
#         # Store the health data
#         health_data_dict = health_data.model_dump()
#         health_data_dict["received_at"] = datetime.now().isoformat()
#         health_data_store.append(health_data_dict)
#
#         # Keep only the last 100 entries
#         if len(health_data_store) > 100:
#             health_data_store.pop(0)
#
#         return {
#             "status": "success",
#             "message": "Health data received successfully",
#             "data": health_data_dict
#         }
#     except Exception as e:
#         raise HTTPException(status_code=500, detail=f"Error processing health data: {str(e)}")
#
# @app.get("/health-data/latest")
# def get_latest_health_data():
#     if not health_data_store:
#         return {"message": "No health data available"}
#
#     return {
#         "status": "success",
#         "data": health_data_store[-1]
#     }
#
# @app.get("/health-data")
# def get_all_health_data(limit: int = 10):
#     if not health_data_store:
#         return {"message": "No health data available"}
#
#     return {
#         "status": "success",
#         "count": len(health_data_store),
#         "data": health_data_store[-limit:]
#     }
