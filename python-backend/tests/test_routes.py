"""
Test API Routes
"""
from fastapi.testclient import TestClient
from app.main import app

client = TestClient(app)


def test_analysis_route_exists():
    """Test that analysis route is registered"""
    response = client.post("/api/v1/analyze/sentiment")
    # Should return 200 with not_implemented status (not 404)
    assert response.status_code == 200


def test_summarization_route_exists():
    """Test that summarization route is registered"""
    response = client.post("/api/v1/summarize/conversation")
    assert response.status_code == 200


def test_events_route_exists():
    """Test that events route is registered"""
    response = client.post("/api/v1/events/index", json={
        "id": "test-event-123",
        "user_id": "test-user-123", 
        "title": "Test Event",
        "date": "2024-01-19",
        "startTime": "10:00",
        "endTime": "11:00"
    })
    assert response.status_code == 200


def test_reminders_route_exists():
    """Test that reminders route is registered"""
    response = client.post("/api/v1/reminders/suggest")
    assert response.status_code == 200


def test_decisions_route_exists():
    """Test that decisions route is registered"""
    response = client.post("/api/v1/decisions/extract")
    assert response.status_code == 200


def test_agent_route_exists():
    """Test that agent route is registered"""
    response = client.post("/api/v1/agent/ask")
    assert response.status_code == 200

