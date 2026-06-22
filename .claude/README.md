homelab-specific Claude Code skills. Workspace-level workflow doctrine (Kanban/Vikunja loop)
and the cross-project ticket skills live in the **codedev** project; this directory only carries
capabilities tied to operating *this* lab.

- `vcsa-drive` — run interactive VCSA admin tools (vdcadmintool, passwd, dir-cli, chpasswd)
  headlessly over SSH: reset a lost vCenter SSO password, or change the appliance root password
  without the console. Reference/background prose lives in `../vcsa-shell-access.md`.
