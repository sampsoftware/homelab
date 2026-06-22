#!/usr/bin/env python3
"""
vcsa_drive — expect-lite pseudo-terminal driver for VMware vCenter Server Appliance.

VCSA `root` over SSH lands in the restricted *appliancesh*, not bash, and the admin tools
you need (`vdcadmintool`, `passwd`, `dir-cli`, `chpasswd`) are interactive — they read prompts
from a terminal. Plain `ssh host 'cmd'` is rejected by appliancesh, and piping a script over
stdin fails because appliancesh buffers all of stdin before `shell` launches bash. This drives
a real pty and answers each prompt as it appears.

stdlib only (no expect/pexpect on the appliance). See ../../../vcsa-shell-access.md for the
"why" and the gotchas, and SKILL.md for ready-to-run recipes.

    from vcsa_drive import drive
    out = drive("192.168.20.11",
        steps=[("command>", "shell"),
               ("]#", "/usr/lib/vmware-vmdir/bin/vdcadmintool"),
               ("0. exit", "3"),
               ("account upn", "administrator@vsphere.local"),
               ("new password", "0")],
        login_pw="<appliance-root-pw>")
"""
import os, pty, select, time, re

_ANSI = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


def drive(host, steps, login_pw, user="root", timeout=90, settle=0.3):
    """
    Fork `ssh -tt user@host` onto a pty and walk an ordered prompt/response script.

    steps   : ordered list of (needle, response). `needle` is matched as a substring against
              the ANSI-stripped, lowercased accumulated output; when it appears, `response`
              is typed (a trailing newline is added unless already present). The SSH password
              prompt is NOT a step — it is answered automatically from `login_pw`.
    login_pw: appliance login password, sent exactly once (NumberOfPasswordPrompts=1 caps the
              faillock blast radius — one wrong answer can't trip the lockout).
    Returns the full ANSI-stripped transcript (string). Parse it for tool output (e.g. the
    "New password is -" line that vdcadmintool prints).
    """
    argv = ["ssh", "-tt",
            "-o", "StrictHostKeyChecking=no", "-o", "UserKnownHostsFile=/dev/null",
            "-o", "PreferredAuthentications=password", "-o", "PubkeyAuthentication=no",
            "-o", "NumberOfPasswordPrompts=1", "-o", "ConnectTimeout=15",
            "%s@%s" % (user, host)]

    pid, fd = pty.fork()
    if pid == 0:
        os.execvp(argv[0], argv)
        os._exit(1)

    def send(s):
        os.write(fd, s.encode())

    buf, transcript = "", []
    pw_sent, i = False, 0
    start = time.time()
    while True:
        if time.time() - start > timeout:
            transcript.append("\n[TIMEOUT]")
            break
        r, _, _ = select.select([fd], [], [], 1.0)
        if fd not in r:
            continue
        try:
            data = os.read(fd, 4096)
        except OSError:
            break
        if not data:
            break
        chunk = data.decode(errors="replace")
        buf += chunk
        transcript.append(chunk)
        low = _ANSI.sub("", buf).lower()

        # SSH login password — exactly once
        if not pw_sent and "assword:" in low:
            time.sleep(settle)
            send(login_pw + "\n")
            pw_sent = True
            buf = ""
            continue

        # Walk the caller's prompt/response steps in order
        if pw_sent and i < len(steps):
            needle, resp = steps[i]
            if needle.lower() in low:
                time.sleep(settle)
                send(resp if resp.endswith("\n") else resp + "\n")
                i += 1
                buf = ""
                if i >= len(steps):
                    # last step sent — flush a little trailing output, then leave
                    time.sleep(0.8)
                    try:
                        r2, _, _ = select.select([fd], [], [], 2.0)
                        if fd in r2:
                            transcript.append(os.read(fd, 4096).decode(errors="replace"))
                    except Exception:
                        pass
                    break
                continue

    try:
        os.close(fd)
    except Exception:
        pass
    return _ANSI.sub("", "".join(transcript))


if __name__ == "__main__":
    import sys
    sys.stderr.write("vcsa_drive is a library: `from vcsa_drive import drive`. See SKILL.md.\n")
    sys.exit(2)
