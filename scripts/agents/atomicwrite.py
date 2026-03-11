"""Atomic file writes for substrate agents.

Writes to a temp file in the same directory, then os.replace() (atomic on POSIX).
Prevents corrupted reports from mid-write crashes.
"""

import os
import tempfile


def atomic_write(filepath, content):
    """Write content to filepath atomically.

    Creates a temp file in the same directory, writes content, then
    atomically replaces the target. Cleans up on failure.
    """
    dirpath = os.path.dirname(filepath) or "."
    os.makedirs(dirpath, exist_ok=True)

    fd, tmp_path = tempfile.mkstemp(dir=dirpath, prefix=".tmp_", suffix=".write")
    try:
        with os.fdopen(fd, "w") as f:
            f.write(content)
        os.replace(tmp_path, filepath)
    except BaseException:
        try:
            os.unlink(tmp_path)
        except OSError:
            pass
        raise
