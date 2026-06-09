from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path


@dataclass
class Prompt:
    id: str
    name: str
    category: str
    path: Path
    mq_stack: str = field(default="")
