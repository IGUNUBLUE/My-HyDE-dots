# LAGC Themes for VSCodium

This source package provides four selectable color themes: `LAGC Calm Dark`/`Light` and `LAGC Tech Dark`/`Light` for VSCodium. It follows the VS Code-compatible extension model and is installed only through the VSCodium CLI:

```bash
./install.sh --vscodium-theme-only
```

In VSCodium, select any theme through **Preferences: Color Theme** (`Ctrl+K`, then `Ctrl+T`). The installer creates a temporary VSIX, passes it to `codium --install-extension`, and removes the temporary package; no generated VSIX or VSCodium runtime state is tracked.

To remove this overlay-owned extension:

```bash
./restore.sh --vscodium-theme-only
```
