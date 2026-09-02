# Hyprlock input stall mitigation

- Status: active
- Date: 2026-09-02
- Scope: Hypridle, Hyprlock, dual displays, NVIDIA
- Sources: previous-boot journal; [hyprlock issue 459](https://github.com/hyprwm/hyprlock/issues/459); [hyprlock issue 427](https://github.com/hyprwm/hyprlock/issues/427); [hyprlock releases](https://github.com/hyprwm/hyprlock/releases)

## Context

The automatic idle lock displayed Hyprlock but stopped accepting useful input. The session had to be shut down from the power button. Investigation found an input/lock-client stall rather than a system-wide freeze.

## Evidence

- Hypridle started Hyprlock normally after the configured idle timeout.
- Both the internal display at fractional scale and the external display were configured successfully.
- Later pointer or keyboard activity restored brightness, while Hyprlock remained alive and no PAM authentication attempt was logged.
- Hyprland and user applications continued running; the previous boot showed no kernel panic, OOM, NVIDIA Xid, or compositor crash during the incident.
- A second lock request failed because the original lock service was still active; this was a consequence of the stalled instance.
- The affected package version was Hyprlock 0.9.6-2. Similar upstream reports exist, but the exact upstream root cause is not proven for this machine.

## Decision

Keep only the 60-second brightness dim/restore listener enabled. Keep automatic Hyprlock launch, DPMS-off and suspend disabled together. Manual lock remains available only for a controlled test with a recovery TTY prepared.

The portable implementation is `dotfiles/.config/hypr/hypridle.conf`, installed as HyDE's preserved user override. `check.sh` rejects accidental reintroduction of the three unsafe automatic actions while this memory remains active.

## Validation

- `hyde-Hyprland-idle.service` is active.
- Hypridle reports exactly one registered timeout rule: brightness dim at 60 seconds and restore on activity.
- The live configuration contains no automatic `loginctl lock-session`, `dispatch dpms off`, or `systemctl suspend` action.
- `hyprctl configerrors` is empty.

## Exit criteria

Do not restore automatic locking merely because a package update exists. First confirm a newer upstream or distribution build addresses the relevant lock/input behavior, then perform repeated lock/unlock tests with both displays active and a TTY recovery path available. Test DPMS and suspend separately. Only after all tests pass may the mitigation be removed, this entry marked resolved, and the validation guard updated in the same change.
