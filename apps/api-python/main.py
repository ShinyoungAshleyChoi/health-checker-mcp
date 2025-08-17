from fastapi import FastAPI
import sys

app = FastAPI()

@app.get("/")
def read_root():
  return {
    "message": "Health Checker Python API",
    "python_version": sys.version
  }

@app.get("/health")
def health_check():
  return {"status": "healthy", "python_version": sys.version}
