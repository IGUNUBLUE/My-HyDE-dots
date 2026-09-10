# Contributing

This repository is a personal, user-owned overlay for [HyDE](https://github.com/HyDE-Project/HyDE) on Arch Linux. It is maintained for one machine, with that machine's hardware in mind, and it is published so that the reasoning is reviewable — not because it aims to be a general-purpose HyDE distribution.

That shapes what is useful here.

## The most valuable contribution is a bug report

If `install.sh` breaks something, or the documentation claims something the code does not do, that is worth reporting even if you cannot fix it.

Use the [bug report template](https://github.com/IGUNUBLUE/My-HYDE-dots/issues/new?template=bug_report.yml). Two fields matter more than the rest:

- **Hardware.** Monitor identifiers, scale factors and the DDC/CI model name. Almost every display bug in this overlay is a mixed-scale interaction that only reproduces on a specific pair of outputs.
- **The output of `./check.sh`.** It is the repository's own gate and its failure messages name the invariant that broke.

Reporting a defect upstream instead of here, when it belongs upstream, is also a contribution: see the scope section of [SECURITY.md](SECURITY.md) for what belongs to HyDE, to the cursor themes and to the applications that consume these dotfiles.

## Security problems

Do not open a public issue. Use GitHub's private reporting form:

<https://github.com/IGUNUBLUE/My-HYDE-dots/security/advisories/new>

[SECURITY.md](SECURITY.md) describes what is in scope and what to include.

## Sending a change

1. Read [`AGENTS.md`](AGENTS.md). It defines the upstream boundary, the safe change workflow and the required validation. It is not advisory: a change that violates it will be rejected.
2. Read [`memory/index.md`](memory/index.md) and the active entries for the component you are touching, so you do not undo a safeguard whose reason is recorded there.
3. Work on a branch, then run the gate before you commit:

```bash
./check.sh
git diff
```

4. Open a pull request using the template. Describe what you observed and why the change is correct — not just what you changed.

### The one rule that is not negotiable

Store **only user-owned overrides**. Never fork or overwrite HyDE's shared runtime under `~/.local/share/hyde`, `~/.local/share/hypr` or `~/.local/lib/hyde`. Write to HyDE's documented override points instead:

| Path | Role |
| --- | --- |
| `~/.config/hypr/hyprland.lua` | HyDE's preserved Lua override |
| `~/.config/hypr/hypridle.conf` | HyDE's preserved idle override |
| `~/.config/hyde/config.toml` | HyDE's preserved user configuration |
| `~/.config/waybar/` | custom Waybar layouts and modules |
| `~/.config/kitty/kitty.conf` | the preserved Kitty override; HyDE owns `hyde.conf` and `theme.conf` |
| `~/.config/zsh/user.zsh` | the preserved Zsh customization point |
| `~/.config/hyde/themes/` | derived themes, such as `Material Sakura Polished` |

A pull request that clones a HyDE file into this repository and edits the copy will be closed. That is exactly the failure mode this overlay exists to avoid.

### What will not be merged

- Changes that introduce a remote fetch, a download-then-execute step, or an unpinned dependency at install time.
- Wallpaper content, generated HyDE state, generated Kvantum configuration, histories, caches, credentials, KWallet data or browser profiles.
- Anything that requires weakening `check.sh`, including widening its secret scan or removing an invariant it enforces.
- Hardware-specific values presented as universal ones. If a change only makes sense on your display pair, say so and keep it configurable or documented.

### Commit messages

Match the existing history: an imperative subject line, no trailing period, specific about the component.

```
Add portable LAGC themes and stabilize Waybar
Restore compact stable Waybar geometry
Keep brightness popup open during focus transfer
```

### Recording a decision

If your change encodes a durable decision or mitigates an incident, add an entry under `memory/decisions/` or `memory/incidents/` using `memory/template.md`, and keep `memory/index.md` current. Resolve an old decision rather than deleting it, so a future installation keeps the reason behind the safeguard.

## Continuous integration

`.github/workflows/codacy.yml` runs Bandit (Python security) and ShellCheck (shell safety) on pushes to `main` and on pull requests, and uploads the results to GitHub code scanning. It is deliberately scoped to those two tools; `.codacy.yaml` records why.

CI does **not** run `./check.sh`. You have to run it yourself.

## Code of conduct

Participation is covered by the [Code of Conduct](CODE_OF_CONDUCT.md).
