#!/usr/bin/env python3
"""Prepare a pacman transaction, approving only Omarchy swaps and never installation."""
import os
import re
import selectors
import signal
import subprocess
import sys
import time


def prepare(command):
    # --ask implies --noconfirm inside pacman, regardless of argument order.
    if any(arg in ('--ask', '--noconfirm') or arg.startswith('--ask=') for arg in command):
        raise ValueError('Noninteractive confirmation flags are unsafe in a preflight')
    proc = subprocess.Popen(command, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.STDOUT, start_new_session=True,
                            env=dict(os.environ, LC_ALL='C'))
    poll = selectors.DefaultSelector()
    poll.register(proc.stdout, selectors.EVENT_READ)
    line = ''
    output = ''
    declined = False
    deadline = time.monotonic() + 60
    try:
        while poll.get_map():
            if time.monotonic() >= deadline:
                raise RuntimeError('Pacman preflight timed out')
            for key, _ in poll.select(timeout=0.2):
                chunk = os.read(key.fileobj.fileno(), 4096)
                if not chunk:
                    poll.unregister(key.fileobj)
                    continue
                text = chunk.decode(errors='replace')
                sys.stdout.write(text)
                sys.stdout.flush()
                output += text
                line += text
                # Pacman prompts without a newline. Keep only the pending line
                # after handling each response, so an old prompt cannot fire twice.
                pending = line.split('\n')[-1]
                if 'Proceed with installation? [Y/n]' in pending:
                    proc.stdin.write(b'n\n')
                    proc.stdin.flush()
                    declined = True
                    line = ''
                elif re.search(r'\[[Yy]/[Nn]\]', pending):
                    match = re.search(r':: (\S+) and (\S+) are in conflict\. Remove (\S+)\? \[y/N\]', pending)
                    allowed = False
                    if match:
                        # Package tokens end in -pkgver-pkgrel; neither version
                        # field may contain hyphens, while package names may.
                        new, old = (token.rsplit('-', 2)[0] for token in match.group(1, 2))
                        allowed = match.group(3) == old and any(
                            (new, old) in ((base, base + '-dev'), (base + '-dev', base))
                            for base in ('omarchy', 'omarchy-settings'))
                    if not allowed or declined:
                        raise RuntimeError('Unexpected package choice; resolve it before switching channels')
                    proc.stdin.write(b'y\n')
                    proc.stdin.flush()
                    line = ''
                elif 'Enter a' in pending and ':' in pending:
                    raise RuntimeError('Package provider selection requires manual resolution')
        status = proc.wait(timeout=5)
        if declined and status == 1 and not re.search(r'^error:', output, re.MULTILINE):
            return 0
        if status == 0 and 'there is nothing to do' in output:
            return 0
        return 1
    finally:
        poll.close()
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGTERM)
            try:
                proc.wait(timeout=3)
            except subprocess.TimeoutExpired:
                os.killpg(proc.pid, signal.SIGKILL)
                proc.wait()
        proc.stdin.close()
        proc.stdout.close()


if __name__ == '__main__':
    try:
        sys.exit(prepare(sys.argv[1:]))
    except (ValueError, RuntimeError, OSError, subprocess.TimeoutExpired) as error:
        print(f'Preflight failed: {error}', file=sys.stderr)
        sys.exit(1)
