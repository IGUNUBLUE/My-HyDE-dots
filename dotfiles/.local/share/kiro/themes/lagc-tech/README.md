# LAGC Tech Themes for Kiro IDE

This source package provides the selectable `LAGC Tech Dark` and `LAGC Tech Light` color themes for Kiro IDE. It follows Kiro's VS Code-compatible extension model and is installed only through Kiro's documented CLI:

```bash
./install.sh --kiro-theme-only
```

In Kiro, select either theme through **Preferences: Color Theme** (`Ctrl+K`, then `Ctrl+T`). The installer creates a temporary VSIX, passes it to `kiro --install-extension`, and removes the temporary package; no generated VSIX or Kiro runtime state is tracked.

To remove this overlay-owned extension:

```bash
./restore.sh --kiro-theme-only
```
