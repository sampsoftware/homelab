# Driving VCSA's restricted shell (reference)

Background for the `vcsa-drive` skill (`.claude/skills/vcsa-drive/`). This is the *why* and the
hard-won gotchas; the skill has the runnable recipes and the `vcsa_drive.py` helper. See also
`virtualization.md` for the appliance itself.

## Why plain SSH doesn't work

VCSA `root` over SSH lands in **appliancesh**, a restricted interpreter — not bash. The admin
tools you need (`vdcadmintool`, `passwd`, `dir-cli`, `chpasswd`) are **interactive**: they read
prompts from a terminal, one at a time. So:

- `ssh root@vc 'somecmd'` → `Unknown command: somecmd`. appliancesh rejects anything that isn't
  one of its own verbs; you must run `shell` to drop into bash first.
- **Piping a script over stdin fails.** appliancesh reads *all* of stdin into its own buffer up
  front, so when `shell` launches bash, bash already sees EOF and logs straight back out — the
  later lines bounce back to appliancesh as "unknown command."
- **`ssh -tt` + heredoc + `sshpass -p` is a trap.** The forced pty and the heredoc bytes collide
  with `sshpass`'s prompt-watching; garbage gets sent as the password, and after a few of those
  PAM **`faillock` locks the account** (SSH *and* console). Ask me how I know.

## The method

Give the interactive tools what they want — a controlling terminal — but drive the master side
from a script. `pty.fork()` makes a pseudo-terminal pair; the child `exec`s `ssh -tt`, the parent
keeps the master fd. Everything the session prints comes out of that fd, and bytes written to it
look like keystrokes typed at a terminal. A small expect-style loop waits (via `select()`) for
each expected prompt before sending the next response, which is exactly what defeats the
appliancesh buffering race — bash is fully up before you type into it. Implemented in
`.claude/skills/vcsa-drive/vcsa_drive.py` (Python stdlib only — no `expect`/`pexpect` on the box).

## Gotchas (each one cost a run)

- **Match on ANSI-stripped text.** The appliancesh bash prompt ends in color escapes
  (`...]# \x1b[0m`), so a naive `#\s*$` regex never matches and the driver stalls. Strip
  `\x1b\[[0-9;]*[A-Za-z]` before matching.
- **Send the login password once.** `NumberOfPasswordPrompts=1` + a one-shot flag means a bad
  answer can't snowball into the 3-strikes `faillock`. If you *do* get locked, it clears on its
  own (~15 min) or on reboot — don't keep hammering.
- **`faillock` counts only *failed* auths.** Repeated *successful* logins are fine — run as many
  sessions as you need. Don't "verify" by testing a now-wrong old password.
- **Raw keystrokes dodge shell-escaping.** A password typed at a tool's *password prompt* is
  literal bytes — no shell parsing — so nasty characters (backticks, backslashes, quotes) are
  fine there. Only when a secret has to sit on a *command line* do you need `set +H` (disable
  bash history expansion, so `!` stays literal) and quoting.
- **Capture generated secrets to a file, don't transcribe.** Parse the tool's output and write it
  byte-exact, then re-read via a file/env var. Eyeballing a 20-char random with backticks bites.
- **Echo artifacts are cosmetic.** The pty sometimes renders a doubled char (`addministrator`,
  `/dev//null`) in the *echo* of what you typed. Trust the tool's own result line
  (`... for [administrator]`, `RC=0`), not the echo.
- **`shell.set --enabled True`** may be needed once to permit bash on a hardened appliance; it
  persists. Disable it again if you care about posture.

## PAM password history (Photon)

`passwd` and `chpasswd` both enforce `pwhistory`, so in a lab that reuses passwords you'll hit
*"Password has been already used. Choose another."* Remembered hashes live in
`/etc/security/opasswd`; clearing root's line there (back it up first) lets you set a previously
used password. The new value must still differ from the *current* one regardless.
