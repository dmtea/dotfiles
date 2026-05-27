# Ubuntu 26 Russian Layout + CapsLock Switch - Full Report

**Date:** 2026-05-26
**VM:** freshubuntu26 (KVM/libvirt)
**Snapshot:** freshready (from 2026-05-21)
**VM Specs:** 4 CPU, 16GB RAM, IP: 192.168.122.204

## Goal

1. Revert VM `freshubuntu26` to snapshot `freshready`
2. Add Russian (ru) keyboard layout
3. Configure CapsLock as layout toggle key (press CapsLock = switch language)
4. Verify it works

---

## System Info

| Property | Value |
|---|---|
| OS | Ubuntu 26.04 LTS (Resolute Raccoon) |
| Kernel | 7.0.0-15-generic x86_64 |
| Desktop | GNOME 50 on Wayland |
| Hostname | testbot2 |
| User | dm |
| Auth | SSH key (id_ed25519) |
| sudo password | rob0!Cat |

---

## Research Summary (Librarian bg_151bf7a8)

### Key Findings

1. **Ubuntu 26.04 ships GNOME 50 on Wayland** — confirmed
2. **`grp:caps_toggle`** is the correct XKB option for CapsLock layout toggle
3. **GNOME on Wayland ignores `/etc/default/keyboard`** — uses gsettings/dconf instead
4. **`grp:caps_switch` (hold) is BROKEN in XWayland** — must use `grp:caps_toggle` (press/release)
5. **GNOME 49 had a freeze bug with CapsLock switching** — FIXED in GNOME 50 (which Ubuntu 26 uses)
6. **`dconf write` works without active D-Bus session** — perfect for SSH/automation

### Methods Evaluated

| Method | Wayland | X11 | TTY | Automation |
|---|---|---|---|---|
| gsettings (needs D-Bus) | ✅ | ✅ | ❌ | ❌ (needs session) |
| dconf write | ✅ | ✅ | ❌ | ✅ (no D-Bus needed) |
| /etc/default/keyboard | ❌ (GNOME ignores) | ✅ | ✅ | ✅ |

### Decision

Use **both** dconf (for GNOME/Wayland) AND /etc/default/keyboard (for TTY fallback):
- `dconf write` for GNOME session
- `/etc/default/keyboard` for system-level

---

## Steps Performed

### Step 1: Revert VM to snapshot
```bash
virsh snapshot-revert freshubuntu26 freshready
# Result: REVERT_OK, VM started automatically
```

### Step 2: VM network info
```bash
virsh domifaddr freshubuntu26
# IP: 192.168.122.204
```

### Step 3: SSH connection
```bash
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 dm@192.168.122.204
# Connected as user dm via key auth (no password needed)
# NOTE: root@192.168.122.204 does NOT work (no key, password auth fails)
```

### Step 4: Gather system info
```bash
# OS
PRETTY_NAME="Ubuntu 26.04 LTS"
VERSION="26.04 LTS (Resolute Raccoon)"

# Session type
loginctl: Type=wayland

# Current layout (before changes)
gsettings get org.gnome.desktop.input-sources sources → [('xkb', 'us')]
gsettings get org.gnome.desktop.input-sources xkb-options → @as []

# /etc/default/keyboard (before changes)
XKBLAYOUT="us"
XKBOPTIONS=""
```

### Step 5: Apply Russian layout + CapsLock toggle (dconf)
```bash
ssh dm@192.168.122.204 "dconf write /org/gnome/desktop/input-sources/sources \"[('xkb', 'us'), ('xkb', 'ru')]\""
ssh dm@192.168.122.204 "dconf write /org/gnome/desktop/input-sources/xkb-options \"['grp:caps_toggle']\""
# Both: SUCCESS
```

### Step 6: Apply system-level keyboard (for TTY fallback)
```bash
ssh dm@192.168.122.184 'echo "rob0!Cat" | sudo -S sed -i '\''s/^XKBLAYOUT=.*/XKBLAYOUT="us,ru"/'\'' /etc/default/keyboard'
ssh dm@192.168.122.184 'echo "rob0!Cat" | sudo -S sed -i '\''s/^XKBOPTIONS=.*/XKBOPTIONS="grp:caps_toggle"/'\'' /etc/default/keyboard'
# Both: SUCCESS
```

### Step 7: Reboot VM
```bash
ssh dm@192.168.122.204 'echo "rob0!Cat" | sudo -S reboot'
```

### Step 8: Verify after reboot
```bash
ssh dm@192.168.122.204
# dconf read /org/gnome/desktop/input-sources/sources → [('xkb', 'us'), ('xkb', 'ru')]  ✅
# dconf read /org/gnome/desktop/input-sources/xkb-options → ['grp:caps_toggle']  ✅
# cat /etc/default/keyboard → XKBLAYOUT="us,ru", XKBOPTIONS="grp:caps_toggle"  ✅
```

---

## Final State

| Setting | Value | Status |
|---|---|---|
| dconf sources | `[('xkb', 'us'), ('xkb', 'ru')]` | ✅ Applied |
| dconf xkb-options | `['grp:caps_toggle']` | ✅ Applied |
| /etc/default/keyboard XKBLAYOUT | `"us,ru"` | ✅ Applied |
| /etc/default/keyboard XKBOPTIONS | `"grp:caps_toggle"` | ✅ Applied |
| Persisted after reboot | — | ✅ Verified |

---

## Testing

**CapsLock switching must be tested in the VM GUI** — SSH cannot test keyboard input.

To test:
1. Open virt-manager or connect to VM display (VNC/SPICE)
2. Log in as dm
3. Open any text editor (gedit, etc.)
4. Press **CapsLock** → should switch to Russian
5. Press **CapsLock** again → should switch back to English
6. The CapsLock LED may not light up (this is expected — it's now a layout switch, not a CapsLock key)

---

## Reproducible Script

```bash
#!/bin/bash
# apply-russian-capslock.sh
# Applies Russian layout + CapsLock toggle on Ubuntu 26.04 GNOME/Wayland
# Run from HOST, targets VM at 192.168.122.204

VM="dm@192.168.122.204"
KEY="~/.ssh/id_ed25519"
SUDO_PASS="rob0!Cat"

# 1. dconf (GNOME/Wayland)
ssh -i $KEY $VM "dconf write /org/gnome/desktop/input-sources/sources \"[('xkb', 'us'), ('xkb', 'ru')]\""
ssh -i $KEY $VM "dconf write /org/gnome/desktop/input-sources/xkb-options \"['grp:caps_toggle']\""

# 2. /etc/default/keyboard (TTY fallback)
ssh -i $KEY $VM "echo '$SUDO_PASS' | sudo -S sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT=\"us,ru\"/' /etc/default/keyboard"
ssh -i $KEY $VM "echo '$SUDO_PASS' | sudo -S sed -i 's/^XKBOPTIONS=.*/XKBOPTIONS=\"grp:caps_toggle\"/' /etc/default/keyboard"

# 3. Reboot
ssh -i $KEY $VM "echo '$SUDO_PASS' | sudo -S reboot"

echo "Done. Wait for VM to boot, then test CapsLock in GNOME."
```

---

## Decisions Log

| # | Decision | Reason |
|---|---|---|
| 1 | Use `dconf write` instead of `gsettings` | No D-Bus session needed over SSH |
| 2 | Use `grp:caps_toggle` not `grp:caps_switch` | `caps_switch` (hold) breaks in XWayland |
| 3 | Also set /etc/default/keyboard | TTY/console fallback |
| 4 | SSH as `dm` not `root` | root has no key, password auth disabled |
| 5 | `sudo -S` with piped password | Avoids TTY requirement for sudo over SSH |
| 6 | Use both dconf AND /etc/default/keyboard | Full coverage: GNOME + TTY |

## Lessons Learned

1. **SSH as root fails** — VM has only key auth for user `dm`, root has no key
2. **`!` in password** — must use `set +H` or single quotes to avoid bash history expansion
3. **sudo over SSH** — use `echo 'pass' | sudo -S cmd`, regular sudo needs TTY
4. **tmux send-keys** — `!` chars are unreliable, prefer direct SSH + `sudo -S`
5. **GNOME on Wayland** — ignores /etc/default/keyboard, uses dconf exclusively

---

## Bug Fix: CapsLock reverts after ~1 second

**Problem:** After pressing CapsLock with `grp:caps_toggle`, the layout switches but reverts back after ~1 second.

**Cause:** XKB-level `grp:caps_toggle` conflicts with GNOME's input source manager on Wayland. GNOME detects the XKB layout change and overrides it back.

**Fix Attempt 1 (2026-05-26):** Switch from XKB-level to GNOME-level keybinding:
- Removed `grp:caps_toggle` from xkb-options
- Set `switch-input-source` to `Caps_Lock` via dconf
- Set `switch-input-source-backward` to `<Shift>Caps_Lock` via dconf

```bash
dconf write /org/gnome/desktop/input-sources/xkb-options "[]"
dconf write /org/gnome/desktop/wm/keybindings/switch-input-source "['Caps_Lock']"
dconf write /org/gnome/desktop/wm/keybindings/switch-input-source-backward "['<Shift>Caps_Lock']"
```
