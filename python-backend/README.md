# MessageAI Python Backend

AI-Powered messaging features backend built with FastAPI, LangChain, OpenAI, and Pinecone.

## 🚀 Features

- **FastAPI** - Modern, fast web framework
- **OpenAI Integration** - GPT-4o-mini for chat, text-embedding-3-small for embeddings
- **Pinecone Vector Database** - Semantic search for messages
- **LangChain** - LLM orchestration framework
- **Async/Await** - High-performance async operations
- **Automatic API Docs** - Swagger UI at `/docs`

## 📋 Prerequisites

- Python 3.9+
- OpenAI API key
- Pinecone account (free tier)
- Virtual environment (recommended)

## 🛠️ Setup Instructions

### 1. Create Virtual Environment

```bash
cd python-backend
python3 -m venv venv
source venv/bin/activate  # On Windows: venv\Scripts\activate
```

### 2. Install Dependencies

```bash
pip install -r requirements.txt
```

### 3. Configure Environment Variables

Copy the example environment file:

```bash
cp .env.example .env
```

Edit `.env` and add your API keys:

```env
# OpenAI API Configuration
OPENAI_API_KEY=sk-your-actual-openai-key-here

# Pinecone Configuration
PINECONE_API_KEY=your-actual-pinecone-key-here

# Server Configuration
HOST=0.0.0.0
PORT=8000
DEBUG=true
```

### 4. Set Up Pinecone Index

1. Go to [Pinecone Dashboard](https://app.pinecone.io/)
2. Create a new **Serverless** index with:
   - **Name:** `messageai`
   - **Dimensions:** `1536`
   - **Metric:** `cosine`
   - **Cloud:** AWS
   - **Region:** us-east-1 (or your preferred region)

## 🏃 Running Locally

### Start the Server

```bash
uvicorn app.main:app --reload
```

The server will start at: **http://localhost:8000**

### Access API Documentation

- **Swagger UI:** http://localhost:8000/docs
- **ReDoc:** http://localhost:8000/redoc

### Test Endpoints

```bash
# Health check
curl http://localhost:8000/health

# Test AI services
curl http://localhost:8000/test-services
```

## 🧪 Running Tests

```bash
# Run all tests
pytest

# Run with verbose output
pytest -v

# Run specific test file
pytest tests/test_health.py

# Run with coverage
pytest --cov=app tests/
```

## 📁 Project Structure

```
python-backend/
├── app/
│   ├── __init__.py          # Package initialization
│   ├── main.py              # FastAPI application entry point
│   ├── models/              # Pydantic data models
│   │   ├── __init__.py
│   │   ├── requests.py      # Request models
│   │   ├── responses.py     # Response models
│   │   └── database.py      # Internal models
│   ├── routes/              # API endpoints
│   │   ├── __init__.py
│   │   ├── analysis.py      # Sentiment & tone analysis
│   │   ├── summarization.py # Conversation summarization
│   │   ├── events.py        # Event detection
│   │   ├── reminders.py     # Reminder suggestions
│   │   ├── decisions.py     # Decision extraction
│   │   └── agent.py         # Intelligent Q&A agent
│   └── services/            # Business logic
│       ├── __init__.py
│       ├── vector_store.py  # Pinecone integration
│       └── openai_service.py # OpenAI API wrapper
├── tests/                   # Test suite
│   ├── __init__.py
│   ├── conftest.py          # Test configuration
│   ├── test_health.py       # Health endpoint tests
│   └── test_routes.py       # Route tests
├── .env                     # Environment variables (gitignored)
├── .env.example             # Example environment file
├── .gitignore               # Git ignore rules
├── requirements.txt         # Python dependencies
├── pytest.ini               # Pytest configuration
└── README.md                # This file
```

## 🔌 API Endpoints

### Core Endpoints

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/` | Root endpoint with API info |
| GET | `/health` | Health check |
| GET | `/test-services` | Test AI services connection |
| GET | `/docs` | Swagger API documentation |

### AI Feature Endpoints (v1)

All AI endpoints are prefixed with `/api/v1`

| Method | Endpoint | Description | Story |
|--------|----------|-------------|-------|
| POST | `/api/v1/analyze/sentiment` | Analyze message sentiment | 5.1 |
| POST | `/api/v1/analyze/tone` | Detect message tone | 5.1 |
| POST | `/api/v1/summarize/conversation` | Summarize conversations | 5.2 |
| POST | `/api/v1/events/detect` | Detect events in messages | 5.3 |
| POST | `/api/v1/reminders/suggest` | Suggest reminders | 5.4 |
| POST | `/api/v1/decisions/extract` | Extract decisions | 5.5 |
| POST | `/api/v1/agent/ask` | Ask questions about conversations | 5.6 |

**Note:** AI feature endpoints return `not_implemented` status until their respective stories are completed.

## 🚢 Deployment to Render.com

### Option 1: Using Render Dashboard

1. **Create Account**
   - Go to [render.com](https://render.com)
   - Sign up / log in
   - Connect your GitHub repository

2. **Create Web Service**
   - Click "New" → "Web Service"
   - Select your repository
   - Configure:
     - **Name:** `messageai-backend`
     - **Environment:** Python
     - **Region:** Oregon (or your preference)
     - **Branch:** `main`
     - **Root Directory:** `python-backend`
     - **Build Command:** `pip install -r requirements.txt`
     - **Start Command:** `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
     - **Plan:** Free

3. **Add Environment Variables**
   In the Render dashboard, add:
   - `OPENAI_API_KEY` → your OpenAI key
   - `PINECONE_API_KEY` → your Pinecone key
   - `DEBUG` → `false`

4. **Deploy**
   - Click "Create Web Service"
   - Render will build and deploy automatically
   - Your backend will be live at: `https://messageai-backend.onrender.com`

### Option 2: Using render.yaml

Create `render.yaml` in project root:

```yaml
services:
  - type: web
    name: messageai-backend
    env: python
    region: oregon
    plan: free
    rootDir: python-backend
    buildCommand: "pip install -r requirements.txt"
    startCommand: "uvicorn app.main:app --host 0.0.0.0 --port $PORT"
    envVars:
      - key: OPENAI_API_KEY
        sync: false
      - key: PINECONE_API_KEY
        sync: false
      - key: DEBUG
        value: false
```

Push to GitHub, then connect repository in Render dashboard.

## 🔧 Development

### Adding New Endpoints

1. Create route in `app/routes/`
2. Define request/response models in `app/models/`
3. Register router in `app/main.py`
4. Add tests in `tests/`

Example:

```python
# app/routes/my_feature.py
from fastapi import APIRouter

router = APIRouter()

@router.post("/my-endpoint")
async def my_endpoint():
    return {"status": "success"}

# app/main.py
from app.routes import my_feature
app.include_router(my_feature.router, prefix="/api/v1", tags=["MyFeature"])
```

### Environment Variables

| Variable | Required | Description | Default |
|----------|----------|-------------|---------|
| `OPENAI_API_KEY` | Yes | OpenAI API key | - |
| `PINECONE_API_KEY` | Yes | Pinecone API key | - |
| `HOST` | No | Server host | `0.0.0.0` |
| `PORT` | No | Server port | `8000` |
| `DEBUG` | No | Debug mode | `true` |

## 🐛 Troubleshooting

### "Missing required environment variables"

**Solution:** Ensure `.env` file exists with `OPENAI_API_KEY` and `PINECONE_API_KEY`

### "Cannot import name 'Pinecone'"

**Solution:** Reinstall pinecone package:
```bash
pip uninstall pinecone pinecone-client -y
pip install pinecone
```

### Tests failing

**Solution:** Make sure server is NOT running when running tests:
```bash
# Stop server with Ctrl+C first
pytest
```

### Port already in use

**Solution:** Kill process on port 8000:
```bash
# macOS/Linux
lsof -ti:8000 | xargs kill -9

# Or use a different port
uvicorn app.main:app --reload --port 8001
```

## 📚 Additional Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [LangChain Documentation](https://python.langchain.com/)
- [Pinecone Documentation](https://docs.pinecone.io/)
- [OpenAI API Reference](https://platform.openai.com/docs/api-reference)

## 📝 License

Part of the MessageAI project.

## 🤝 Contributing

This is a development project. See main repository for contribution guidelines.

---

**Built with ❤️ using FastAPI, LangChain, OpenAI, and Pinecone**

