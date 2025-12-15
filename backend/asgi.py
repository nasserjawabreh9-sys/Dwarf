"""
Render/ASGI entrypoint.
Make sure the deployed ASGI app is EXACTLY the same as backend/app.py.
"""
from app import app  # noqa: F401
