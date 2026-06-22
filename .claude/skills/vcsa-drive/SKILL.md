---
name: vcsa-drive
description: Run interactive VCSA admin tools (vdcadmintool, passwd, dir-cli, chpasswd) headlessly over SSH — reset a lost vCenter SSO password or change the appliance root password without the console.
disable-model-invocation: true
---

Drive VMware vCenter Server Appliance (VCSA / Photon) admin tools that demand a terminal,
without sitting at the console. Use this to **reset a lost `administrator@vsphere.local` SSO
password** or **change the appliance `root` password** headless.

VCSA `root` over SSH lands in the restricted *appliancesh*, not bash, and these tools are
interactive. Plain non-interactive SSH can't drive them; the helper `vcsa_drive.py` (in this
skill dir) forks `ssh -tt` onto a pty and answers each prompt as it appears. Background and
the gotchas that cost real runs are in `../../vcsa-shell-access.md` — read it before improvising.

Lab target is `192.168.20.11` (vCenter, VLAN 20). The appliance login password is the
appliance `root` password (kept in the host-side `homelab.env` secret, not in this repo).

## Load the helper

```python
import sys; sys.path.insert(0, "/workspaces/homelab/.claude/skills/vcsa-drive")
from vcsa_drive import drive
```

`drive(host, steps, login_pw)` takes an ordered list of `(prompt-substring, response)` and
returns the ANSI-stripped transcript. Match substrings are case-insensitive. The SSH password
prompt is handled for you via `login_pw` (sent once — one wrong answer can't trip faillock).

### Prompt cheat-sheet (VCSA 7.0.3)

| You see | It is | Respond |
|---|---|---|
| `Command>` | appliancesh | `shell` |
| `... ]#` (ends in ANSI reset) | bash | your command |
| `Please select:` / `0. exit` | vdcadmintool menu | `3` (reset account password) |
| `Please enter account UPN :` | vdcadmintool | `administrator@vsphere.local` |
| `New password is - <random>` | vdcadmintool output | capture it, then `0` to exit |
| `New password:` / `Retype new password:` | passwd | the new password, twice |

## Recipe 1 — reset a lost SSO `administrator@vsphere.local` password

`vdcadmintool` option 3 mints a fresh **random** password and prints it. Capture it byte-exact
(it's full of backticks/backslashes — never transcribe by eye), verify, then normalise it.

```python
out = drive("192.168.20.11",
    steps=[
        ("command>",       "shell"),
        ("]#",             "/usr/lib/vmware-vmdir/bin/vdcadmintool"),
        ("0. exit",        "3"),
        ("account upn",    "administrator@vsphere.local"),
        ("new password",  "0"),       # acknowledge, return to menu
    ],
    login_pw="<appliance-root-pw>")

import re
pw = re.search(r"New password is\s*-\s*\r?\n(.*?)\r?\n", out, re.S).group(1)
open("/tmp/sso_newpw", "w").write(pw)     # byte-exact, no trailing newline
```

Verify before trusting it (special chars survive command substitution into the env var):

```bash
GOVC_URL="https://192.168.20.11/sdk" GOVC_INSECURE=1 \
GOVC_USERNAME='administrator@vsphere.local' \
GOVC_PASSWORD="$(cat /tmp/sso_newpw)" govc about     # exit 0 = good
```

Set it to a chosen value: authorise with the random one, type it as **raw keystrokes** at
dir-cli's prompt (no shell parsing at a password prompt → special chars are harmless). `set +H`
first so a `!` in the new password is literal on the command line.

```python
cur = open("/tmp/sso_newpw").read()
drive("192.168.20.11",
    steps=[
        ("command>", "shell"),
        ("]#",       "set +H"),
        ("]#",       "/usr/lib/vmware-vmafd/bin/dir-cli password reset "
                     "--account administrator --new 'AlwaysBeKind1!' "
                     "--login administrator@vsphere.local"),
        ("assword",  cur),            # "Enter password for administrator@vsphere.local:"
    ],
    login_pw="<appliance-root-pw>")
# success line: "Password was reset successfully for [administrator]"
```

## Recipe 2 — change the appliance `root` password headless

`passwd`/`chpasswd` go through PAM `pwhistory`. With reused lab passwords you'll hit
*"Password has been already used."* Clear root's history entry first, then set it. The new
value must still differ from the current one.

```python
drive("192.168.20.11",
    steps=[
        ("command>", "shell"),
        ("]#",       "set +H"),
        ("]#",       "cp -n /etc/security/opasswd /etc/security/opasswd.bak; "
                     "sed -i '/^root:/d' /etc/security/opasswd; echo HIST=$?"),
        ("hist=",    "echo 'root:AlwaysBeKind1!' | chpasswd; echo RC=$?"),
        ("rc=",      "exit"),
    ],
    login_pw="<current-appliance-root-pw>")
# RC=0 = changed
```

Verify with a fresh login — and don't re-test the *old* password (a failed auth feeds faillock):

```bash
sshpass -p 'AlwaysBeKind1!' ssh -o StrictHostKeyChecking=no \
  -o NumberOfPasswordPrompts=1 root@192.168.20.11 'help api list'   # API list = success
```

## After using this

- `shred -u /tmp/sso_newpw` and remove any temp scripts.
- On the appliance you may have left `/etc/security/opasswd.bak` and bash shell access enabled
  (`shell.set --enabled True`) — harmless in this lab; revert if you care about posture.
- Update the password of record in the host-side `homelab.env` secret (read-only mount; edit it
  on the Windows host — see `../../CLAUDE.md`).
