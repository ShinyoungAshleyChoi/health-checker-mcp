# Health Checker MCP

An iOS app that reads health data from your iPhone using HealthKit and sends it to an MCP (Model Context Protocol) server.

## Architecture

- **iOS App** (`apps/ios-app/`): Swift command-line app that reads HealthKit data
- **Python API** (`apps/api-python/`): FastAPI server that receives health data
- **MCP Shim** (`apps/mcp-shim/`): Node.js MCP protocol handler

## Prerequisites

- **macOS** with Xcode and Swift toolchain
- **Python 3.8+** with pip
- **Node.js 18+** with npm
- **iPhone/iPad** with health data (for testing)

## Setup & Installation

### 1. Install Dependencies

```bash
# Install Python dependencies
cd apps/api-python
pip install fastapi uvicorn

# Install Node.js dependencies
cd ../mcp-shim
npm install

# Build iOS app
cd ../ios-app
swift build
```

### 2. Run the API Server

```bash
cd apps/api-python
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

The API will be available at `http://localhost:8000`

### 3. Run the iOS App

```bash
cd apps/ios-app
swift run HealthCheckerApp --server-url http://localhost:8000 --verbose
```

## Health Data Types

The app reads the following health metrics:
- **Step Count** (daily total)
- **Heart Rate** (most recent)
- **Active Energy Burned** (daily total)
- **Walking/Running Distance** (daily total)
- **Body Mass** (most recent)
- **Height** (most recent)

## API Endpoints

- `GET /` - API information
- `GET /health` - Health check
- `POST /health-data` - Receive health data from iOS app
- `GET /health-data/latest` - Get latest health data
- `GET /health-data?limit=N` - Get recent health data (default: 10)

## Usage Example

1. **Start the API server:**
```bash
cd apps/api-python && uvicorn main:app --port 8000
```

2. **Run the iOS app:**
```bash
cd apps/ios-app && swift run HealthCheckerApp --verbose
```

3. **Check received data:**
```bash
curl http://localhost:8000/health-data/latest
```

## Health Permissions

The iOS app will request permission to read:
- Physical activity data (steps, distance, energy)
- Vital signs (heart rate)
- Body measurements (weight, height)

Grant these permissions in Settings > Privacy & Security > Health when prompted.

## Development

### Testing the API

```bash
# Test health endpoint
curl http://localhost:8000/health

# Test with sample data
curl -X POST http://localhost:8000/health-data \
  -H "Content-Type: application/json" \
  -d '{
    "stepCount": 8500,
    "heartRate": 72,
    "activeEnergyBurned": 245.5,
    "timestamp": "2024-01-01T12:00:00Z"
  }'
```

### Building for Different Platforms

The iOS app is configured for:
- iOS 16.0+
- macOS 13.0+

For iPhone deployment, you'll need to:
1. Create an iOS project in Xcode
2. Add HealthKit entitlements
3. Configure provisioning profiles