# CapsLock Layout Switch — Combined Research Report

**Date:** 2026-05-27
**Status:** ROOT CAUSE IDENTIFIED — QEMU/SPICE double CapsLock press

---

## Executive Summary

CapsLock as layout toggle (`grp:caps_toggle`) does NOT work in QEMU/KVM VMs with SPICE display. The root cause is that SPICE synchronizes CapsLock state between host and guest, generating a **double press** — the first switches layout, the second switches it back.

On **real hardware** (or with VNC instead of SPICE), `grp:caps_toggle` should work correctly.

---

## Root Cause

From `/home/dm/tmp_xkb/logs/03-claude-debug-report.md` (Step 9):

```
sudo libinput debug-events | grep -v POINTER

# Single physical CapsLock press produces:
+12.316s  *** (-1) pressed   ← physical press
+12.663s  *** (-1) pressed   ← auto-repeat from QEMU/SPICE sync!
```

QEMU/SPICE syncs CapsLock LED state between host and guest. When you press CapsLock, SPICE:
1. Sends the keypress to guest → layout switches to Russian
2. Then sends a second "sync" press → layout switches back to English

---

## Environment Comparison

| Property | Laptop (works ✅) | VM (broken ❌) |
|----------|-------------------|----------------|
| Session | X11 | Wayland |
| GNOME | 42.9 | 50.1 |
| Display server | Real hardware | QEMU/SPICE |
| Kernel | 6.17.9 | 7.0.0 |
| `grp:caps_toggle` | Works | Double-press revert |

**Key insight:** The X11 vs Wayland difference is NOT the cause. SPICE double-press is.

---

## What Was Tried (combined from both sessions)

| Method | Result | Why |
|--------|--------|-----|
| `grp:caps_toggle` in xkb-options | ❌ Reverts | SPICE double press |
| `grp:caps_toggle` + `caps:none` | ❌ Reverts | Same SPICE issue |
| GNOME keybinding `switch-input-source=['Caps_Lock']` | ❌ Reverts | SPICE double press |
| Disable IBus completely | ❌ Reverts | SPICE issue, not IBus |
| `grp:caps_switch` (hold) | ⚠️ Unreliable | Works once, then breaks |
| Shift+CapsLock | ✅ Works | SPICE doesn't sync Shift state |
| Super+Space | ✅ Works | Not CapsLock |
| Alt+Shift | ✅ Works | Not CapsLock |
| keyd → Super+Space | ✅ Works | Remaps CapsLock to different keycode |
| virtio keyboard (instead of ps2) | ❌ Reverts | SPICE still syncs |
| Hyprland `grp:caps_toggle` | ❌ Reverts | SPICE issue at lower level |

---

## Solutions (prioritized)

### 1. Test on Live USB (real hardware)
If CapsLock works on real hardware → confirms SPICE is the sole cause.
```bash
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru')]"
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:caps_toggle', 'caps:none']"
```

### 2. Switch SPICE → VNC in VM
VNC does NOT sync CapsLock state:
```xml
<!-- Replace SPICE graphics with VNC -->
<graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'>
  <listen type='address' address='127.0.0.1'/>
</graphics>
```

### 3. Use keyd (kernel-level remap)
Installs on the VM, remaps CapsLock to Super+Space:
```ini
# /etc/keyd/default.conf
[ids]
*

[main]
capslock = M-space
```
**Note:** IBus must be disabled or it interferes after reboot.

### 4. Accept alternative hotkey
- Shift+CapsLock ✅ (but user doesn't want this)
- Super+Space ✅ (GNOME default)
- Alt+Shift ✅

---

## Configuration That Works on Real Hardware

```bash
# GNOME (Wayland or X11)
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru')]"
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:caps_toggle', 'caps:none']"
```

```bash
# Or via dconf (no D-Bus needed)
dconf write /org/gnome/desktop/input-sources/sources "[('xkb', 'us'), ('xkb', 'ru')]"
dconf write /org/gnome/desktop/input-sources/xkb-options "['grp:caps_toggle', 'caps:none']"
```

```ini
# Hyprland (~/.config/hypr/hyprland.conf)
input {
    kb_layout = us,ru
    kb_options = grp:caps_toggle,caps:none
}
```

---

## VM Configuration (current state)

The VM `freshubuntu26` currently has CapsLock config applied. Should be reverted to clean snapshot before next use.

---

## Files in This Project

| File | Content |
|------|---------|
| `00-credentials.md` | VM access credentials |
| `01-research-and-plan.md` | Initial research + implementation steps |
| `02-implementation-report.md` | First implementation attempt details |
| `03-claude-debug-report.md` | Claude's deep debug session (root cause found) |
| `04-combined-research.md` | This file — combined findings |
