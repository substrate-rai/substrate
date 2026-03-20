---
globs: ["gentoo/**"]
---

# Gentoo / OpenRC Conventions

- Portage config (`gentoo/`) + `/var/lib/portage/world` is the source of truth for system state.
- Python3 IS in system PATH on Gentoo (no nix develop wrapper needed).
- Never inline secrets in Portage config — use environment files with restricted permissions.
- OpenRC service scripts: `gentoo/init.d/` → install to `/etc/init.d/`
- Service environment: `gentoo/conf.d/` → install to `/etc/conf.d/`
- Scheduled tasks: `gentoo/fcrontab` → install with `fcrontab gentoo/fcrontab`
- After Portage config changes: `emerge --update --deep --newuse @world`
- Service management: `rc-service <name> start|stop|restart|status`
- Enable/disable: `rc-update add|del <name> default`
- **elogind must be in boot runlevel**, not default: `rc-update add elogind boot`
- NVIDIA suspend hook: `gentoo/elogind-nvidia-sleep.sh` → `/etc/elogind/system-sleep/`
