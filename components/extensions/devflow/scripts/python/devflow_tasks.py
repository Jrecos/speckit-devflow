"""Shared task-line counting for DevFlow (ADR-0023 / C5).

ONE definition of the `tasks.md` line primitives, so init / compute-leash / loop-status /
stop-gate / stop2-prep / open-iteration / status don't each restate the regex. Byte-identical
to the inline forms they replace:
  count_done   ← re.findall(r"^- \\[x\\]", text, re.M)
  count_open   ← re.findall(r"^- \\[ \\]", text, re.M)
  open_task_ids← re.findall(r"^- \\[ \\] (\\S+)", text, re.M)
"""
import re

_DONE = re.compile(r"^- \[x\]", re.M)
_OPEN = re.compile(r"^- \[ \]", re.M)
_OPEN_ID = re.compile(r"^- \[ \] (\S+)", re.M)


def count_done(text):
    """Number of completed task lines (`- [x] …`)."""
    return len(_DONE.findall(text))


def count_open(text):
    """Number of open task lines (`- [ ] …`)."""
    return len(_OPEN.findall(text))


def open_task_ids(text):
    """Ids of open tasks (first whitespace-delimited token after `- [ ] `)."""
    return _OPEN_ID.findall(text)
