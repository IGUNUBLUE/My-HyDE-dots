# HyDE update while preserving Swaync and personal settings

- Status: monitoring
- Date: 2026-10-21
- Scope: HyDE updates, Swaync, deez-dots, migrations, rollback
- Sources: official HyDE README update section; HyDE source at `fa2fd57afc7203b1b5653d3271f3a57ea3873f97`, particularly `Scripts/install.sh`, `Scripts/global_fn.sh`, `Scripts/dots-groups/{core,extra}.toml`, `Scripts/dots/waybar.toml`, and `Scripts/migrations/v26.9.2.sh`; installed deez CLI help; live checks and owner acceptance.

## Context

The owner requested updating HyDE while preserving the existing desktop. The
installed revision was `51b6cbf55b0bf982b2ea88af00a0cdbae0c787c7`. The clean
official checkout was fast-forwarded to `fa2fd57a`; no upstream files were
patched. Packages and the running Hyprland version were not upgraded.

## Evidence

- The official full restore checks and installs the core group's dependencies,
  including Dunst. This profile intentionally uses Swaync, already installed and
  owned by its user service. Keep the notification startup override and the
  user-owned Dunst Wallbash guard.
- At this revision `install.sh --restore --test` is not entirely read-only:
  the final migration loop runs even with `flg_DryRun=1`. During this update it
  retired the stale Zsh arrow-binding file and cleared old Swaync/Waybar deez
  manifests and cached bundles. A complete backup existed before the run.
  Inspect future source before relying on this flag as a simulation.
- `v26.9.2.sh` clears old ownership records before deploying `swaync_config` and
  Waybar, avoiding their former conflict over `menus/swaync.xml`.
- Deez package names differ from TOML file names: `wallbash.toml` defines
  `wallbash-gtk`, and `swaync-config.toml` defines `swaync_config`. A missing dot
  can be reported as an error while the overall deployment still exits zero;
  inspect logs and verify installed files, not just the exit code.
- The initial snapshot found a missing live rhun hook despite its tracked
  source being present. Reapplying the overlay installed the tracked hooks.
  Machine-local shell additions remain outside the portable snapshot.

## Decision

1. Back up affected personal files, upstream runtime, deez manifests, migration
   state, version state and monitor geometry under
   `~/.local/state/my-hyde-dots/upstream-updates/<timestamp>/`. Keep private
   backups out of Git. Review `update-snapshot.sh` output before proceeding.
2. Fetch official `master`, inspect its diff and fast-forward the clean HyDE
   checkout. Refresh Python and Lua through the upstream environment managers.
3. Use official deez granular deployment with `--source ~/HyDE`, the upstream
   group TOMLs, `--skip-git` and `--no-deps-install`. Check dependencies first.
   The core selection was `hyde grimblast xdg-terminal-exec app2unit hyprland
   wallbash-gtk waybar rofi wlogout`; deploy all extra dots and the chosen `zsh`
   shell dot separately. Dunst and system-wide archive payloads were excluded.
4. Reapply the personal overlay with
   `./install.sh --yes --skip-packages --only cursor,config,themes,apply`.
   The logind drop-in already matched its source, so no sudo/system change was
   needed. Preserve excluded local settings from the pre-update backup.
5. Reload through `hyde-shell reload theme`; after successful deployment cache
   the revision with upstream `Scripts/version.sh --cache` from the checkout.
6. Run static and live checks, restoring the original theme afterward. Recheck
   the exact commands and current upstream sources before repeating this flow.

## Validation

- `./check.sh` passed, including 23 hook behavior tests, theme contracts and Qt
  menu checks. The overlay dry run and whitespace checks passed.
- `tests/live-theme.sh`: 145 passed, zero failed across all four LAGC themes,
  including GTK/Qt state, browser toolbars/content with throwaway profiles,
  editors and visible Waybar surfaces on both outputs. Original
  `LAGC Tech Light` restored.
- Pre-existing tracked personal runtime files matched their pre-update hashes;
  `config.toml` matched the expanded tracked template. Missing tracked hooks
  were installed, with no upstream-runtime patch.
- Hyprland config errors empty; both Waybar layers remained 24 logical pixels.
  The owner confirmed real pointer crossing and the brightness right-click
  popup worked on the updated desktop.
- Brightness status remained valid JSON with both internal and external
  controls. Fresh interactive Zsh loaded its user configuration.
- Keyboard layouts remained `es,latam`, active/inactive opacity 1, blur off,
  Future-cursors selected with compositor size 46 and GTK/XSettings size 32.
  Idle, bar, Swaync, XSettings and cursor-watcher services were active.
- Both lid bindings remained locked; all three logind lid policies remained
  `ignore`. Automatic lock, DPMS-off and suspend mitigations were retained.
- No lock/unlock, DPMS or suspend acceptance test was performed. These update
  checks do not resolve the existing Hyprlock incident.
- Waybar emitted GTK accelerator assertions and tray-icon warnings during
  reloads; no bar loss or minimum-height warning was observed in the update
  checks. Retain the reload guard and monitor functional symptoms.

## Rollback

Use the recorded old upstream revision with the same official deployment
selection to roll back runtime. Use the overlay's `restore.sh` with the recorded
overlay backup for paths in its manifest. The additional private archives have
their own explicit path lists: use them only for the affected recorded paths,
never as a blanket home-directory restore. Keep upstream runtime changes under
the official deployer's ownership.

## Exit criteria

Revisit when the official installer supports selecting Swaync without pulling
in Dunst, makes test mode read-only, or changes deez deployment/migration
behavior. Revalidate theme hooks and both outputs after every HyDE update.
