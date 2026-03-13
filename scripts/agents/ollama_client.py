"""Shared Ollama client for substrate agents.

Centralizes all Ollama HTTP interaction. Uses urllib (stdlib only).
Agents migrate from copy-pasted requests.post() calls to:

    from ollama_client import chat, chat_json, describe_image, is_available

VRAM management (used by ML scripts via shared/ollama.py):

    from ollama_client import unload_models, load_model
"""

import base64
import json
import os
import time
import urllib.request
import urllib.error

OLLAMA_URL = os.environ.get("OLLAMA_URL", "http://localhost:11434")
OLLAMA_MODEL = os.environ.get("OLLAMA_MODEL", "qwen3:8b")

# Content-type sampling presets tuned for Qwen3 8B.
# temperature >= 0.6 avoids greedy-decoding repetition loops.
# repeat_penalty >= 1.2 prevents sentence-level looping.
PRESETS = {
    "guide":   {"temperature": 0.7, "top_p": 0.9, "top_k": 20, "repeat_penalty": 1.2, "num_predict": 2048, "num_ctx": 8192},
    "social":  {"temperature": 0.7, "top_p": 0.9, "top_k": 20, "repeat_penalty": 1.3, "num_predict": 512,  "num_ctx": 4096},
    "summary": {"temperature": 0.3, "top_p": 0.85, "top_k": 10, "repeat_penalty": 1.2, "num_predict": 1024, "num_ctx": 4096},
    "log":     {"temperature": 0.3, "top_p": 0.8, "top_k": 10, "repeat_penalty": 1.1, "num_predict": 512,  "num_ctx": 4096},
}

# Cached availability check
_available_cache = {"result": None, "checked_at": 0}
_CACHE_TTL = 60  # seconds


class OllamaError(Exception):
    """Raised when Ollama returns an error or is unreachable."""
    pass


def is_available(timeout=5):
    """Check if Ollama is reachable. Cached for 60 seconds."""
    now = time.monotonic()
    if (_available_cache["result"] is not None
            and now - _available_cache["checked_at"] < _CACHE_TTL):
        return _available_cache["result"]

    try:
        req = urllib.request.Request(f"{OLLAMA_URL}/api/tags")
        urllib.request.urlopen(req, timeout=timeout)
        _available_cache["result"] = True
    except (urllib.error.URLError, OSError):
        _available_cache["result"] = False

    _available_cache["checked_at"] = now
    return _available_cache["result"]


def invalidate_cache():
    """Force next is_available() call to re-check."""
    _available_cache["result"] = None
    _available_cache["checked_at"] = 0


def chat(messages, system=None, model=None, timeout=120, think=False,
         options=None, preset=None, keep_alive=None):
    """Send a chat completion request to Ollama.

    Args:
        messages: List of {"role": "user"|"assistant", "content": "..."} dicts
        system: Optional system prompt string
        model: Model name (default: OLLAMA_MODEL env or qwen3:8b)
        timeout: Request timeout in seconds
        think: Enable thinking mode (default: False)
        options: Dict of Ollama sampling parameters (temperature, top_p, etc.)
        preset: Name of a preset from PRESETS dict (merged under explicit options)

    Returns:
        Response text string

    Raises:
        OllamaError: On connection failure or non-200 response
    """
    model = model or OLLAMA_MODEL

    # Merge preset defaults with explicit options (explicit wins)
    merged_options = {}
    if preset and preset in PRESETS:
        merged_options.update(PRESETS[preset])
    if options:
        merged_options.update(options)

    payload = {
        "model": model,
        "messages": messages,
        "stream": False,
        "think": think,
    }
    if merged_options:
        payload["options"] = merged_options
    if keep_alive is not None:
        payload["keep_alive"] = keep_alive
    if system:
        payload["messages"] = [{"role": "system", "content": system}] + payload["messages"]

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/chat",
        data=data,
        headers={"Content-Type": "application/json"},
    )

    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        body = json.loads(resp.read().decode("utf-8"))
        return body.get("message", {}).get("content", "")
    except urllib.error.HTTPError as e:
        raise OllamaError(f"Ollama HTTP {e.code}: {e.reason}")
    except urllib.error.URLError as e:
        raise OllamaError(f"Ollama unreachable: {e.reason}")
    except OSError as e:
        raise OllamaError(f"Ollama connection error: {e}")
    except (json.JSONDecodeError, KeyError) as e:
        raise OllamaError(f"Ollama response parse error: {e}")


def chat_json(messages, schema, system=None, model=None, timeout=120, **kwargs):
    """Chat with JSON schema enforcement. Returns parsed dict.

    Args:
        messages: List of {"role": "user"|"assistant", "content": "..."} dicts
        schema: JSON schema dict that the response must conform to
        system: Optional system prompt string
        model: Model name (default: OLLAMA_MODEL)
        timeout: Request timeout in seconds

    Returns:
        Parsed dict from JSON response

    Raises:
        OllamaError: On connection failure, non-200 response, or invalid JSON
    """
    model = model or OLLAMA_MODEL

    merged_options = {}
    if "preset" in kwargs and kwargs["preset"] in PRESETS:
        merged_options.update(PRESETS[kwargs["preset"]])
    if "options" in kwargs and kwargs["options"]:
        merged_options.update(kwargs["options"])

    payload = {
        "model": model,
        "messages": messages,
        "stream": False,
        "think": False,
        "format": schema,
    }
    if merged_options:
        payload["options"] = merged_options
    if system:
        payload["messages"] = [{"role": "system", "content": system}] + payload["messages"]

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/chat",
        data=data,
        headers={"Content-Type": "application/json"},
    )

    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        body = json.loads(resp.read().decode("utf-8"))
        content = body.get("message", {}).get("content", "")
        return json.loads(content)
    except urllib.error.HTTPError as e:
        raise OllamaError(f"Ollama HTTP {e.code}: {e.reason}")
    except urllib.error.URLError as e:
        raise OllamaError(f"Ollama unreachable: {e.reason}")
    except json.JSONDecodeError as e:
        raise OllamaError(f"Invalid JSON in response: {e}")
    except OSError as e:
        raise OllamaError(f"Ollama connection error: {e}")


def describe_image(image_path, prompt="Describe this image", model="gemma3:4b", timeout=120):
    """Send an image to a vision model and return description.

    Args:
        image_path: Path to image file (PNG, JPG, etc.)
        prompt: Text prompt to accompany the image
        model: Vision-capable model (default: gemma3:4b)
        timeout: Request timeout in seconds

    Returns:
        Description text string

    Raises:
        OllamaError: On connection failure or non-200 response
        FileNotFoundError: If image_path doesn't exist
    """
    with open(image_path, "rb") as f:
        image_data = base64.b64encode(f.read()).decode("utf-8")

    payload = {
        "model": model,
        "messages": [
            {
                "role": "user",
                "content": prompt,
                "images": [image_data],
            }
        ],
        "stream": False,
        "options": {"keep_alive": 0},  # unload after use to free VRAM
    }

    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/chat",
        data=data,
        headers={"Content-Type": "application/json"},
    )

    try:
        resp = urllib.request.urlopen(req, timeout=timeout)
        body = json.loads(resp.read().decode("utf-8"))
        return body.get("message", {}).get("content", "")
    except urllib.error.HTTPError as e:
        raise OllamaError(f"Ollama HTTP {e.code}: {e.reason}")
    except urllib.error.URLError as e:
        raise OllamaError(f"Ollama unreachable: {e.reason}")
    except OSError as e:
        raise OllamaError(f"Ollama connection error: {e}")


def unload_models(timeout=30):
    """Unload all Ollama models from VRAM."""
    try:
        req = urllib.request.Request(f"{OLLAMA_URL}/api/ps")
        resp = urllib.request.urlopen(req, timeout=timeout)
        data = json.loads(resp.read())
        models = data.get("models", [])
        if not models:
            return []
        unloaded = []
        for m in models:
            name = m.get("name", "unknown")
            body = json.dumps({"model": name, "keep_alive": 0}).encode()
            req2 = urllib.request.Request(
                f"{OLLAMA_URL}/api/generate",
                data=body,
                headers={"Content-Type": "application/json"},
                method="POST",
            )
            urllib.request.urlopen(req2, timeout=timeout)
            unloaded.append(name)
        return unloaded
    except (urllib.error.URLError, OSError) as e:
        raise OllamaError(f"Failed to unload models: {e}")


def load_model(model=None, timeout=60):
    """Warm-load a model into VRAM."""
    model = model or OLLAMA_MODEL
    body = json.dumps({"model": model}).encode()
    req = urllib.request.Request(
        f"{OLLAMA_URL}/api/generate",
        data=body,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    try:
        urllib.request.urlopen(req, timeout=timeout)
    except (urllib.error.URLError, OSError) as e:
        raise OllamaError(f"Failed to load model {model}: {e}")
