"""Run a shell snippet under a real pty and capture everything it wrote.

The UI smoke tests have to prove two opposite things about the same helper:
that nothing is drawn into a pipe, and that a human watching a terminal *does*
see frames. The second half cannot be faked — it needs a pty — so both
ui-spinner-smoke.sh and ui-progress-result-smoke.sh grew an inline Python
block to open one. Four byte-identical copies of this function ended up
pasted across those two files, each inside its own heredoc, and the
controlling-terminal bug below had to be fixed in all four at once. One copy
is the point of this module.

Usage from a heredoc, which is why this takes a plain string and no fixtures:

    PYTHONPATH="$ROOT/tests/lib" python3 - "$UI" <<'PY'
    from pty_capture import run_pty
    status, seen = run_pty(f"source '{ui}'; ui_spinner 'Working' sleep 0.3")
    PY

Environment is inherited from this process, so a caller sets MQ_NO_TUI and
friends via os.environ before calling.
"""

import os
import select
import subprocess
import time

__all__ = ["run_pty"]

DEFAULT_TIMEOUT = 5.0
_READ_SIZE = 4096
_POLL_INTERVAL = 0.1


def run_pty(script, timeout=DEFAULT_TIMEOUT):
    """Run `script` under bash on a pty; return (exit status, captured bytes).

    Raises TimeoutError, after killing the child, if it outlives `timeout`.
    """
    master, slave = os.openpty()
    seen = bytearray()
    try:
        # os.login_tty makes the pty the child's *controlling* terminal and
        # dups it onto 0/1/2. Redirecting stdout/stderr alone is not enough:
        # the child would keep the parent's /dev/tty, and the spinner writes
        # its frames there by design, so none of them would reach the master.
        # This is the part pty.spawn did for us.
        proc = subprocess.Popen(
            ["bash", "-c", script],
            stdin=subprocess.DEVNULL,
            close_fds=True,
            preexec_fn=lambda: os.login_tty(slave),
        )
        # The child owns the slave now. Holding it open here would keep the
        # master readable forever after the child exits.
        os.close(slave)
        slave = -1
        _drain_until_exit(proc, master, seen, timeout)
        _drain_remaining(master, seen)
        return proc.wait(), bytes(seen)
    finally:
        for fd in (master, slave):
            if fd >= 0:
                try:
                    os.close(fd)
                except OSError:
                    pass


def _drain_until_exit(proc, master, seen, timeout):
    """Read the pty while the child lives, so a chatty child cannot block."""
    deadline = time.time() + timeout
    while proc.poll() is None:
        if time.time() > deadline:
            proc.kill()
            raise TimeoutError("pty command timed out")
        readable, _, _ = select.select([master], [], [], _POLL_INTERVAL)
        if readable:
            try:
                seen.extend(os.read(master, _READ_SIZE))
            except OSError:
                break


def _drain_remaining(master, seen):
    """Collect what the child wrote just before exiting."""
    while True:
        readable, _, _ = select.select([master], [], [], 0)
        if not readable:
            break
        try:
            chunk = os.read(master, _READ_SIZE)
        except OSError:
            break
        if not chunk:
            break
        seen.extend(chunk)
