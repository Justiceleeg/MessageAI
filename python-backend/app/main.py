"""
MessageAI Backend API
FastAPI application for AI-powered messaging features
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from dotenv import load_dotenv
import os

# Load environment variables
load_dotenv()

# Validate required environment variables
required_env_vars = ["OPENAI_API_KEY", "PINECONE_API_KEY"]
missing_vars = [var for var in required_env_vars if not os.getenv(var)]
if missing_vars:
    raise EnvironmentError(
        f"Missing required environment variables: {', '.join(missing_vars)}\n"
        "Please check your .env file."
    )

# Initialize FastAPI app
app = FastAPI(
    title="MessageAI Backend",
    description="AI-Powered Messaging Features API",
    version="1.0.0",
    docs_url="/docs",
    redoc_url="/redoc"
)

# Configure CORS for iOS app
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # TODO: Configure for production with specific origins
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def root():
    """Root endpoint - API status"""
    return {
        "message": "MessageAI Backend API",
        "status": "running",
        "version": "1.0.0",
        "docs": "/docs"
    }


@app.get("/health")
def health_check():
    """Health check endpoint"""
    return {
        "status": "healthy",
        "service": "messageai-backend"
    }


@app.get("/test-services")
def test_services():
    """Test that AI services are properly initialized"""
    from app.services.vector_store import get_vector_store
    from app.services.openai_service import get_openai_service
    
    try:
        # Initialize services (will use singleton if already created)
        vector_store = get_vector_store()
        openai_service = get_openai_service()
        
        # Get Pinecone stats (convert to simple dict)
        stats = vector_store.get_index_stats()
        
        # Extract just the useful info
        simple_stats = {
            "dimensions": stats.get("dimension", "unknown"),
            "total_vector_count": stats.get("total_vector_count", 0),
            "namespaces": list(stats.get("namespaces", {}).keys()) if stats.get("namespaces") else []
        }
        
        return {
            "status": "success",
            "vector_store": "connected",
            "openai_service": "connected",
            "pinecone_index": "messageai",
            "stats": simple_stats
        }
    except Exception as e:
        import traceback
        return {
            "status": "error",
            "message": str(e),
            "traceback": traceback.format_exc()
        }


# Register API routes
from app.routes import analysis, summarization, events, reminders, decisions, agent

app.include_router(analysis.router, prefix="/api/v1", tags=["Analysis"])
app.include_router(summarization.router, prefix="/api/v1", tags=["Summarization"])
app.include_router(events.router, prefix="/api/v1", tags=["Events"])
app.include_router(reminders.router, prefix="/api/v1", tags=["Reminders"])
app.include_router(decisions.router, prefix="/api/v1", tags=["Decisions"])
app.include_router(agent.router, prefix="/api/v1", tags=["Agent"])

