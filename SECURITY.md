# Security Policy

`My-HyDE-dots` is a personal, user-owned overlay for [HyDE](https://github.com/HyDE-Project/HyDE) on Arch Linux. It is not a hosted service and it runs no server. It is a set of shell scripts, Python helpers and configuration files that you run yourself, on your own machine, as your own user.

That shapes this policy: the realistic threat is a flaw that makes **your** machine do something you did not intend when you run the installer or one of the helper scripts.

## Supported versions

Only the newest tagged release and the current `main` branch are maintained. Fixes land on `main` and are cut into the next tag.

| Version | Supported |
| --- | --- |
| Latest tagged release (`v1.0.0`) | :white_check_mark: |
| `main` | :white_check_mark: |
| Older tags and forks | :x: |

## Reporting a vulnerability

**Please do not open a public issue for a security problem.**

Use GitHub's private vulnerability reporting form:

<https://github.com/IGUNUBLUE/My-HYDE-dots/security/advisories/new>

If that is unavailable to you, open an issue that asks for a private channel and contains no technical detail, and a way to reach you will be arranged.

A useful report contains:

- The file and commit you are looking at.
- A reproduction: the exact command, environment and observation.
- The impact you believe it has, and specifically whether it requires `sudo`.
- Any suggested fix, if you have one.

## What to expect

This is a personal project maintained in spare time, with no support contract and no bug bounty.

- Acknowledgement within **7 days**.
- Initial assessment, including whether the report is in scope, within **14 days**.
- Fixes ship on `main` and are mentioned in the next release's notes.

Credit is given unless you ask otherwise.

## Scope

### In scope

Anything in this repository that executes or changes your system:

- `install.sh`, `restore.sh`, `update-snapshot.sh`, `check.sh`
- `tools/merge-zed-settings.py`, `tools/package-kiro-theme.py`
- `dotfiles/.local/bin/hyde-brightness-panel`, `dotfiles/.local/bin/my-hyde-qt-menu`, `dotfiles/.local/bin/my-hyde-rofi-selection`
- `cursor-sources/` and the local cursor build performed with `hyprcursor-util`
- `dotfiles/.config/hyde/themes/`, and the Wallbash templates and post-render callbacks the overlay installs
- `.github/workflows/`

Reports that matter most:

- Command injection through any variable that reaches a shell, `eval`, or a Python `subprocess`/`os.system` call.
- A path that deletes or overwrites something outside the overlay's documented targets, or an `rm -rf` acting on an unresolved or attacker-influenced variable.
- Unexpected privilege escalation: anything that ends up running as root beyond the documented `sudo pacman` package install.
- A remote fetch, download-then-execute, or unpinned dependency introduced by the overlay.
- A secret, token or private key that the snapshot tooling could commit.

### Out of scope

- **HyDE upstream.** Report those to [HyDE-Project/HyDE](https://github.com/HyDE-Project/HyDE).
- **Bundled cursor themes.** `Future-cursors` and the `Future-cyan` hyprcursor port are GPLv3 third-party assets, tracked here together with their license and provenance. Report defects upstream; this repository only pins a reviewed revision.
- **The software that consumes these dotfiles** — Kiro IDE, Zed, Kitty, Waybar, Dunst, Kvantum, Rofi, Hyprlock, Hypridle — and the Arch packages listed in `packages.arch`.
- **Your own machine state.** Anything requiring an attacker to already control your user account, shell profile, `~/.config` or package manager is outside the threat model this overlay defends against.
- **GitHub features and the Codacy action.** Code scanning, secret scanning, Dependabot and the third-party analysis action belong to their respective vendors.

## Guarantees this overlay upholds

These are the properties a valid report would most likely violate. They are deliberate:

- **No remote code execution at install time.** None of the scripts download or pipe remote content into a shell. Cursor sources are tracked in this repository and compiled locally with `hyprcursor-util`. Packages come from the official Arch repositories, through `pacman`.
- **Backups before writes.** Every file or managed tree that is replaced is copied to `~/.local/state/my-hyde-dots/backups/` first, and `restore.sh` reverts to that copy.
- **No shared HyDE runtime is overwritten.** The overlay writes only its own files plus HyDE's documented user-owned override points. It does not touch `~/.local/share/hyde`, `~/.local/share/hypr` or `~/.local/lib/hyde`.
- **No secrets in the repository.** `check.sh` refuses to pass when it finds a private key, a GitHub token, or a `password=` / `token=` / `api_key=` assignment, and `update-snapshot.sh` deliberately excludes histories, caches, credentials, KWallet and browser profiles.

## Privileges required

`install.sh` calls `sudo pacman -S --needed` for the packages listed in `packages.arch`. Everything else runs as your normal user. Review that list, and use `./install.sh --dry-run` to see every action without applying it. `./install.sh --skip-packages` installs nothing.

## Hardening advice for users

- Run `./install.sh --dry-run` and read the output before the real run.
- Read `packages.arch`; use `--skip-packages` if you would rather install those yourself.
- Keep `~/.local/state/my-hyde-dots/backups/` out of any folder that syncs to a third party, since it contains a copy of your configuration.
- Run `./check.sh` before committing: it is the same gate CI enforces.
- Treat a fork as untrusted input if you take configuration from someone else.
