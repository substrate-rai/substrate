"""Shared .env loader for Substrate scripts. No external dependencies."""

import os
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent


def load_env(path=None):
    """Load key=value pairs from a .env file into os.environ.

    Skips blank lines and comments. Does not override existing env vars.
    """
    if path is None:
        path = REPO_ROOT / ".env"
    else:
        path = Path(path)
    if not path.exists():
        return
    with open(path) as f:
        for line in f:
            line = line.strip()
            if not line or line.startswith("#"):
                continue
            if "=" in line:
                key, value = line.split("=", 1)
                os.environ.setdefault(key.strip(), value.strip())
