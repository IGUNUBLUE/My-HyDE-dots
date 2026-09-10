## What this changes, and why

<!--
Describe the observation that motivated this. If it fixes something, say what
you saw and how you confirmed it. If it adds something, say which component and
which HyDE contract it uses.
-->

## How it was verified

<!--
Commands you ran and what you observed. `./check.sh` is required; per-component
validation (cursor build, Qt menu idempotence, theme source validation) is
required when you touched that component.
-->

## Checklist

- [ ] `./check.sh` passes.
- [ ] I read the relvant `memory/` entries before changing the component, and this does not undo a recorded safeguard.
- [ ] This stores **only user-owned overrides**: it does not fork or overwrite HyDE's shared runtime under `~/.local/share/hyde`, `~/.local/share/hypr` or `~/.local/lib/hyde`.
- [ ] I reviewed `git diff` and it contains no histories, caches, credentials, KWallet data, browser profiles, wallpaper content or generated HyDE/Kvantum state.
- [ ] If this encodes a durable decision or mitigates an incident, I added it under `memory/decisions/` or `memory/incidents/` and updated `memory/index.md`.

## Hardware and scope

<!--
Almost every display or cursor bug in this overlay is a mixed-scale interaction.
If your change depends on specific outputs, scale factors or a DDC/CI model name,
state them here and say whether the code now handles other hardware or still
assumes yours.

Leave the values below in place if you tested on the reference machine.
-->

- Displays and scales:
- Tested with install flags:
- Hardware-specific files touched (if any):
