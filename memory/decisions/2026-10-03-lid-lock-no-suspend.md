# Lid close locks and blanks the panel without suspending

- Status: active
- Date: 2026-10-03
- Scope: Hyprland, systemd-logind, Hyprlock, laptop lid, displays
- Sources: live `hyprctl devices`/`hyprctl binds`; `systemd-logind.service(8)` (SIGHUP reloads configuration); `logind.conf(5)`; libinput switch semantics (lid switch state "on" = closed)

## Context

The owner wants closing the lid to lock the session and turn off the internal panel while the machine keeps working (downloads, builds, agents). Suspend and hibernate both stop all work, so neither is acceptable. logind's default `HandleLidSwitch=suspend` was suspending the machine on every close.

## Evidence

- The lid is the ACPI `Lid Switch` device (PNP0C0D); Hyprland exposes it as a switch, and with the Lua parser the binds are `hl.bind("switch:on:Lid Switch", ...)` (close) and `switch:off` (open). `hyprctl keyword bindl` is rejected by the Lua parser.
- `hyprctl dispatch dpms off` is legacy syntax and fails under the Lua parser; `hl.dsp.dpms({ action, monitor })` works and blanks only the named output.
- `hl.get_monitors()` is available, so internal panels are matched at runtime by `^eDP%-` and external outputs are never blanked.
- `systemctl reload systemd-logind` (SIGHUP) applies the drop-in without ending the session on systemd 262.

## Decision

- `hyprland.lua` binds lid close to `hyde.sh.session.lock()` (same path as SUPER + L: `loginctl lock-session` -> hypridle `lock_cmd`) followed by DPMS off on every eDP-* panel; lid open turns those panels back on. Both binds are `locked = true` (`bindl`).
- `system/etc/systemd/logind.conf.d/10-my-hyde-lid.conf` sets `HandleLidSwitch`, `HandleLidSwitchExternalPower` and `HandleLidSwitchDocked` to `ignore`. It is installed only by the sudo `system` module, backed up into `.system/` or recorded in `.system-created`, and restored through an explicit allowlist shared by `install.sh`, `restore.sh` and `update-snapshot.sh`.
- This is a user-initiated lock, not an automatic idle action, so it does not lift the [Hyprlock input stall mitigation](../incidents/2026-09-02-hyprlock-input-stall.md): hypridle still has no automatic lock, DPMS-off or suspend. The owner accepted the stall risk explicitly. Recovery if Hyprlock stops accepting input after opening the lid: switch to a TTY (`Ctrl+Alt+F3`) and run `pkill -USR1 hyprlock`, which unlocks without ending the session.

## Validation

- `hyprctl binds -j` lists `switch:on:Lid Switch` and `switch:off:Lid Switch`, both locked; `hyprctl configerrors` is empty.
- `busctl get-property org.freedesktop.login1 /org/freedesktop/login1 org.freedesktop.login1.Manager HandleLidSwitch` returns `"ignore"` after `./install.sh --only system`.
- Physical test: close the lid with an external display attached; the session stays running and locked on the external output, the internal panel is off, and opening the lid restores it and accepts the password.
- `check.sh` guards the binds, the lock path, the three logind keys and allowlist coverage.
- 2026-10-03, live: after `./install.sh --only system` all three `HandleLidSwitch*` properties report `ignore`. Physical lid test reported by the owner: Hyprlock 0.9.6 started on close (21:39:57), accepted the password and unlocked on open (21:40:20), and the journal shows no `PM: suspend entry`. One successful run is evidence only; it does not satisfy the Hyprlock mitigation's repeated dual-monitor exit criteria.

## Exit criteria

Revisit if the owner wants suspend on battery, if a Hyprland release changes switch-bind or `hl.dsp.dpms` semantics, or if the Hyprlock stall reproduces on lid open (then drop the lock call from the close bind and keep DPMS-off only until the mitigation is resolved).
