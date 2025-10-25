#!/usr/bin/env python3
"""
Wipe all vectors from Pinecone but keep the index structure intact.
This clears all data from the messageai index while preserving namespaces.
"""
import os
import sys
from pathlib import Path

# Add parent directory to path so we can import from app
sys.path.insert(0, str(Path(__file__).parent.parent))

# Load environment variables from .env file
from dotenv import load_dotenv
load_dotenv()

from pinecone import Pinecone

def wipe_pinecone():
    """Wipe all vectors from all namespaces in the messageai index"""
    
    # Get API key from environment
    api_key = os.getenv("PINECONE_API_KEY")
    if not api_key:
        print("❌ PINECONE_API_KEY not found in environment!")
        print("Make sure your .env file exists and contains PINECONE_API_KEY")
        sys.exit(1)
    
    try:
        # Initialize Pinecone
        pc = Pinecone(api_key=api_key)
        index = pc.Index("messageai")
        
        # Namespaces used in your app
        namespaces = ["messages", "events", "decisions", "reminders"]
        
        print("🧹 Wiping Pinecone vectors (keeping index structure)...")
        print(f"   Index: messageai")
        print(f"   Namespaces: {', '.join(namespaces)}\n")
        
        total_cleared = 0
        for namespace in namespaces:
            try:
                # Get stats before deletion
                stats = index.describe_index_stats()
                ns_count = stats.namespaces.get(namespace, {}).vector_count if hasattr(stats, 'namespaces') else 0
                
                # Delete all vectors in this namespace
                index.delete(delete_all=True, namespace=namespace)
                print(f"✅ Cleared namespace '{namespace}' ({ns_count} vectors)")
                total_cleared += ns_count
                
            except Exception as e:
                print(f"⚠️  Error clearing '{namespace}': {e}")
        
        print(f"\n✨ Done! Cleared {total_cleared} total vectors.")
        print(f"   Index 'messageai' still exists and is ready to use.")
        
    except Exception as e:
        print(f"❌ Error connecting to Pinecone: {e}")
        sys.exit(1)

if __name__ == "__main__":
    wipe_pinecone()

