# Ubuntu 26 Russian Layout + CapsLock Switch — Full Report

**Date:** 2026-05-26
**Status:** ✅ CONFIGURED, pending manual GUI verification

---

## VM Info

| Field | Value |
|-------|-------|
| VM Name | `freshubuntu26` |
| Hypervisor | KVM/libvirt (virsh) |
| OS | Ubuntu 26.04 LTS "Resolute Raccoon" |
| Desktop | GNOME 50 on Wayland |
| CPU/RAM | 4 CPU, 16GB |
| IP | 192.168.122.204 |
| User | `dm` |
| Auth | SSH key (`~/.ssh/id_ed25519`) |
| Snapshot source | `freshready` (2026-05-21) |

---

## What Was Done

### Step 1: Revert VM to snapshot

```bash
virsh snapshot-revert freshubuntu26 freshready
# VM auto-started after revert
```

### Step 2: Verify VM state

```bash
virsh domifaddr freshubuntu26
# → 192.168.122.204
```

### Step 3: Connect via SSH

```bash
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_ed25519 dm@192.168.122.204
# Key auth works. Password auth not needed for SSH.
# Password `rob0!Cat` is for sudo and display manager login.
```

### Step 4: Check current config

Before changes:
```
dconf sources: [('xkb', 'us')]          # US only
dconf xkb-options: @as []               # No options
/etc/default/keyboard XKBLAYOUT="us"    # US only
/etc/default/keyboard XKBOPTIONS=""     # No options
```

### Step 5: Apply Russian layout + CapsLock toggle (dconf)

```bash
# GNOME/Wayland level — takes effect immediately in GNOME session
dconf write /org/gnome/desktop/input-sources/sources "[('xkb', 'us'), ('xkb', 'ru')]"
dconf write /org/gnome/desktop/input-sources/xkb-options "['grp:caps_toggle']"
```

### Step 6: Apply system-level fallback (/etc/default/keyboard)

```bash
# TTY/console level — requires sudo
echo "rob0!Cat" | sudo -S sed -i 's/^XKBLAYOUT=.*/XKBLAYOUT="us,ru"/' /etc/default/keyboard
echo "rob0!Cat" | sudo -S sed -i 's/^XKBOPTIONS=.*/XKBOPTIONS="grp:caps_toggle"/' /etc/default/keyboard
```

### Step 7: Reboot and verify

```bash
echo "rob0!Cat" | sudo -S reboot
# After reboot:
# dconf sources: [('xkb', 'us'), ('xkb', 'ru')] ✅
# dconf xkb-options: ['grp:caps_toggle'] ✅
# /etc/default/keyboard: XKBLAYOUT="us,ru", XKBOPTIONS="grp:caps_toggle" ✅
# GNOME session active on tty2 ✅
```

---

## Configuration Details

### Method: dconf write (for GNOME/Wayland)

- **Schema:** `org.gnome.desktop.input-sources`
- **sources:** `[('xkb', 'us'), ('xkb', 'ru')]` — US (default) + Russian
- **xkb-options:** `['grp:caps_toggle']` — CapsLock toggles between layouts

**Why `grp:caps_toggle` and not `grp:caps_switch`:**
- `grp:caps_toggle` — press CapsLock to toggle between layouts (works on Wayland + XWayland)
- `grp:caps_switch` — hold CapsLock for temporary switch (BROKEN in XWayland clients)

### Method: /etc/default/keyboard (for TTY/console)

- **XKBLAYOUT:** `"us,ru"`
- **XKBOPTIONS:** `"grp:caps_toggle"`
- This provides fallback for non-GUI sessions (virtual consoles)

---

## Research Summary (from librarian)

### Key findings:

1. **Ubuntu 26.04 ships with GNOME 50 + Wayland**
2. **GNOME ignores /etc/default/keyboard on Wayland** — must use gsettings/dconf
3. **`grp:caps_toggle` works on both Wayland and XWayland** — confirmed working
4. **GNOME 49 had a CapsLock freeze bug** — fixed in GNOME 50 (which Ubuntu 26 uses)
5. **dconf write works without D-Bus session** — ideal for SSH/automation
6. **Alternative: `switch-input-source` keybinding** — but xkb-options is more reliable

### Alternative XKB options for CapsLock:

| Option | Description |
|--------|-------------|
| `grp:caps_toggle` | CapsLock toggles layouts ✅ (recommended) |
| `grp:shift_caps_toggle` | Shift+CapsLock toggles |
| `grp:caps_select` | CapsLock → 1st layout, Shift+CapsLock → 2nd |
| `grp:alt_caps_toggle` | Alt+CapsLock toggles |
| `grp:caps_switch` | Hold CapsLock for 2nd layout ⚠️ broken in XWayland |

---

## Known Issues

1. **GNOME 49 freeze bug** — CapsLock caused session hang. Fixed in GNOME 50 (Ubuntu 26 ships GNOME 50).
2. **XWayland + `grp:caps_switch`** — doesn't work. Use `grp:caps_toggle` instead.
3. **SSH can't test CapsLock** — keyboard layout switching only works in GUI session. Need to log into VM desktop to test.

---

## Files Changed on VM

| File | Change |
|------|--------|
| `~dm/.config/dconf/user` (dconf DB) | Added sources + xkb-options |
| `/etc/default/keyboard` | XKBLAYOUT="us,ru", XKBOPTIONS="grp:caps_toggle" |

---

## How to Test

1. Open VM console (virt-viewer, virt-manager, or SPICE/VNC)
2. Log in as `dm` with password `rob0!Cat` (if auto-login not set)
3. Open any text editor (gedit, terminal)
4. Press **CapsLock** — indicator should show "ru" or "En"/"Ru" switch
5. Type — should get Russian characters
6. Press CapsLock again — back to English

---

## Decisions Log

| # | Decision | Reason |
|---|----------|--------|
| 1 | Use `dconf write` instead of `gsettings set` | SSH session has no D-Bus; dconf writes directly to user DB |
| 2 | Use `grp:caps_toggle` not `grp:caps_switch` | `caps_switch` broken in XWayland; toggle works everywhere |
| 3 | Set both dconf AND /etc/default/keyboard | dconf for GNOME/Wayland, keyboard file for TTY fallback |
| 4 | SSH as `dm` not `root` | root SSH disabled; key auth only for dm |
| 5 | Use `sudo -S` for password-based sudo | No TTY in SSH batch mode; `-S` reads from stdin |

---

## Session Issues Encountered

| Issue | Resolution |
|-------|------------|
| SSH as root failed (Permission denied) | Use user `dm` with SSH key instead |
| sudo in SSH batch mode failed ("terminal required") | Use `echo "pass" \| sudo -S command` |
| tmux send-keys with `!` in password | Works via `send-keys -l` (literal mode), but `sudo -S` is cleaner |
| Pane got messy with nested sessions | Killed pane, used direct SSH from host instead |
