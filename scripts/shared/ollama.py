"""Shared Ollama utilities for non-agent scripts.

Re-exports from scripts/agents/ollama_client.py so non-agent scripts
don't need to reach into the agents directory.
"""

import os
import sys

# Add agents dir to path for import
_AGENTS_DIR = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "agents")
if _AGENTS_DIR not in sys.path:
    sys.path.insert(0, _AGENTS_DIR)

from ollama_client import (chat, chat_json, describe_image,
                           unload_models, load_model,
                           is_available, OllamaError,
                           PRESETS, OLLAMA_URL, OLLAMA_MODEL)

__all__ = ["chat", "chat_json", "describe_image",
           "unload_models", "load_model",
           "is_available", "OllamaError",
           "PRESETS", "OLLAMA_URL", "OLLAMA_MODEL"]
