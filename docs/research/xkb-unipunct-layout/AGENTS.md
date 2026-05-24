# XKB unipunct Layout — Deployment & Test Project

**Purpose**: Custom `unipunct` keyboard layout (Russian with US punctuation + Ukrainian AltGr) for deployment on laptop and testing in VMs.

**Target platforms on laptop:**
- **Ubuntu 26.04 (GNOME, Wayland)** — main daily driver
- **Pop!_OS 24.04/26.04 (COSMIC, Wayland)** — testing until COSMIC matures

## Problem

On Russian keyboard layout, Ctrl shortcuts (Ctrl+C, Ctrl+V, etc.) send Cyrillic keysyms instead of Latin.
Apps receive `Ctrl+Cyrillic_es` instead of `Ctrl+c` and don't recognize the shortcut.

## Current Solution

| Mechanism | Status | Where |
|-----------|--------|-------|
| `unipunct` layout variant | ✅ Works (host + freshpop24 + freshubuntu26) | System xkb: `/usr/share/X11/xkb/symbols/ru` (replaces entire file) |
| Ctrl→Latin via xkb types | ❌ Does not work | Abandoned — xkb types approach doesn't work for Ctrl+Latin |
| kitty `ru-shortcuts.conf` | ✅ Works | kitty terminal only — `send_text` for Ctrl combos |

### What actually works

1. **`unipunct` layout** — Russian with US punctuation base + Ukrainian characters via Right Alt. Deployed by replacing the system `symbols/ru` file. Original standard `unipunct` is commented out, our version takes its name.
2. **Ctrl→Latin** — **only via kitty terminal config** (`ru-shortcuts.conf`). No XKB-level fix exists.
3. **Wayland** — `~/.config/xkb/` works for user layouts (types + symbols + rules).

## Files

```
~/dotfiles_xkb_test/
├── AGENTS.md                        ← this file
├── xkb-system/                      ← system xkb (deploy to /usr/share/X11/xkb/)
│   └── ru                           ← full system symbols/ru; original unipunct commented out, our version named "unipunct"
├── kitty/                           ← kitty config (deploy to ~/.config/kitty/)
│   ├── kitty.conf                   ← main config (includes ru-shortcuts.conf)
│   ├── current-theme.conf           ← theme colors
│   └── ru-shortcuts.conf            ← Ctrl→Latin mappings for Russian layout
```

## Host (laptop) Setup

Host runs Pop!_OS 22.04 LTS with GNOME (X11 session).

- `symbols/ru` — identical to `xkb-system/ru` in this project (our `unipunct` replaces standard one)
- `evdev.xml` — patched with `unipunct` variant
- `setxkbmap -query` shows: `layout: us,ru,us`, `variant: ,unipunct_ua,` (session started before rename to `unipunct`)
- `grp:caps_toggle` works on host (X11 session)
- kitty config: `~/.config/kitty/kitty.conf` + `ru-shortcuts.conf` + `current-theme.conf`

**Planned:** Replace with dual-boot Ubuntu 26.04 (main) + Pop!_OS 24.04/26.04 (COSMIC testing). Both use same `unipunct` layout + kitty config.

## Deployment

### System XKB (for X11 and Wayland compositor)

Copy `xkb-system/ru` to `/usr/share/X11/xkb/symbols/ru` (requires sudo).

This file contains the standard Russian layouts. The original `unipunct` variant is commented out; our modified version (with Ukrainian AltGr) is named `unipunct`.

### COSMIC DE (Pop!_OS 24.04)

COSMIC stores keyboard config in `~/.config/cosmic/com.system76.CosmicComp/v1/xkb_config`.

**No `evdev.xml` patch needed** — COSMIC reads layout variant directly from `symbols/ru`. The `unipunct` name already exists in standard rules.

**Working RON config:**
```ron
(
    rules: "",
    model: "",
    layout: "us,ru",
    variant: ",unipunct",
    options: Some("lv3:ralt_switch,compose:rctrl"),
    repeat_delay: 600,
    repeat_rate: 25,
)
```

**Important COSMIC findings:**
- COSMIC overwrites `xkb_config` on its own — `chattr +i` is NOT needed (and COSMIC ignores it anyway)
- Writing the file alone is NOT enough — layout must also be added via COSMIC Settings → Keyboard → "+" → Russian (unipunct)
- COSMIC rewrites the file to its preferred format after GUI changes
- Layout order in the file matters: `us,ru` + `,unipunct` (US first, Russian with unipunct variant)
- **CapsLock as layout toggle DOES NOT WORK** — COSMIC comp bug: CapsLock assigned to any shortcut triggers the action then reverts after ~1 second (tested: launcher, layout switch). COSMIC Settings GUI does not offer CapsLock as layout toggle option. `grp:caps_toggle` in xkb_config is ignored by COSMIC.
- COSMIC comp version: `0.1~1779380826~24.04~6ebe2a1` (latest available, no update)

### GNOME (Ubuntu 26.04)

**Important:** `evdev.xml` MUST be patched to include `unipunct` variant — otherwise GNOME doesn't see it. This is unlike COSMIC which reads directly from `symbols/ru`.

Patch `evdev.xml` (python3 script, finds `<name>ru</name>` section, inserts variant):
```bash
sudo python3 -c "
import xml.etree.ElementTree as ET
path = '/usr/share/X11/xkb/rules/evdev.xml'
tree = ET.parse(path)
root = tree.getroot()
for layout in root.iter('layout'):
    ci = layout.find('configItem')
    if ci is not None:
        name = ci.find('name')
        if name is not None and name.text == 'ru':
            vl = layout.find('variantList')
            nv = ET.SubElement(vl, 'variant')
            nci = ET.SubElement(nv, 'configItem')
            ET.SubElement(nci, 'name').text = 'unipunct'
            ET.SubElement(nci, 'description').text = 'Russian (with US punctuation)'
            ll = ET.SubElement(nci, 'languageList')
            ET.SubElement(ll, 'iso639Id').text = 'rus'
            tree.write(path, xml_declaration=True, encoding='UTF-8')
            break
"
```

Then apply layout:
```bash
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru+unipunct')]"
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:caps_toggle', 'lv3:ralt_switch']"
```

Logout/login required.

**GNOME findings:**
- `evdev.xml` patch is required — GNOME reads layout list from there, not just `symbols/ru`
- `grp:caps_toggle` works correctly on GNOME (unlike COSMIC)
- kitty `.desktop` needs full paths for `Exec`, `TryExec`, `Icon` (GNOME doesn't add `~/.local/kitty.app/bin` to `$PATH`)

## Test VMs

### `freshpop24` — Pop!_OS 24.04 (COSMIC DE, Wayland)

| Property | Value |
|----------|-------|
| OS | Pop!_OS 24.04 |
| RAM | 16 GB |
| GUI | COSMIC DE, Wayland |
| IP | `192.168.122.22` (DHCP — check with `virsh domifaddr freshpop24`) |
| SSH | `ssh dm@192.168.122.22` (key-based) |
| User | `dm` |
| Password | `<vm-password>` |
| Snapshot | `freshready` — **USE THIS for all testing** |

### `freshubuntu26` — Ubuntu 26.04 (GNOME 50, Wayland)

| Property | Value |
|----------|-------|
| OS | Ubuntu 26.04 LTS |
| RAM | 16 GB |
| vCPUs | 4 |
| GUI | GNOME 50, Wayland |
| IP | `192.168.122.204` (DHCP — check with `virsh domifaddr freshubuntu26`) |
| SSH | `ssh dm@192.168.122.204` (key-based) |
| User | `dm` |
| Password | `<vm-password>` |
| Snapshot | `freshready` — **USE THIS for all testing** |

### VM Workflow

```bash
# Revert to clean state
virsh shutdown freshpop24 && sleep 10 && virsh snapshot-revert freshpop24 freshready && virsh start freshpop24

# Get IP
sleep 12 && virsh domifaddr freshpop24

# SSH into VM
ssh dm@192.168.122.22

# Open GUI console (human types for keyboard testing)
virt-viewer freshpop24 &

# Shut down when done
virsh shutdown freshpop24
```

## Test Results

### freshpop24 (COSMIC DE) — ✅ PASS (layout) / ❌ CapsLock broken

| Test | Result |
|------|--------|
| Deploy `symbols/ru` | ✅ `sudo cp` works |
| Layout appears in COSMIC list | ✅ After adding via GUI Settings |
| Layout works correctly | ✅ Russian typing + US punctuation |
| AltGr Ukrainian symbols | ⏳ Not yet tested |
| CapsLock toggle us↔ru | ❌ COSMIC comp bug — reverts after ~1 sec |
| `xkb_config` persistence | ✅ COSMIC writes and reads it correctly |
| Layout survives logout/login | ✅ Works |
| kitty installed (0.47.0) | ✅ From official installer |
| kitty .desktop in launcher | ✅ Copied to ~/.local/share/applications/ |
| kitty Ctrl+Latin in Russian | ✅ ru-shortcuts.conf works |
| kitty `hide_window_decorations` | ✅ Works (no title bar) |

**COSMIC deployment steps that work:**
1. Copy `xkb-system/ru` → `/usr/share/X11/xkb/symbols/ru`
2. Logout/login
3. COSMIC Settings → Keyboard → "+" → Russian → select "unipunct" variant → Add
4. Verify `~/.config/cosmic/com.system76.CosmicComp/v1/xkb_config` has correct layout/variant
5. Install kitty: `curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n`
6. Copy .desktop: `cp ~/.local/kitty.app/share/applications/*.desktop ~/.local/share/applications/`
7. Deploy kitty config: `kitty/kitty.conf`, `kitty/current-theme.conf`, `kitty/ru-shortcuts.conf` → `~/.config/kitty/`

### freshubuntu26 (GNOME) — ✅ PASS

| Test | Result |
|------|--------|
| Deploy `symbols/ru` | ✅ `sudo cp` works |
| Patch `evdev.xml` | ✅ Required — GNOME needs variant in evdev.xml |
| Layout appears in GNOME | ✅ After logout/login |
| CapsLock toggle us↔ru | ✅ `grp:caps_toggle` works |
| kitty installed (0.47.0) | ✅ From official installer |
| kitty .desktop in launcher | ✅ Needs full paths for Exec/TryExec/Icon |
| kitty Ctrl+Latin in Russian | ✅ ru-shortcuts.conf works |
| kitty `hide_window_decorations` | ✅ Works (no title bar) |

**GNOME deployment steps that work:**
1. Copy `xkb-system/ru` → `/usr/share/X11/xkb/symbols/ru`
2. Patch `evdev.xml` with `unipunct` variant (python3 script above)
3. `gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru+unipunct')]"`
4. `gsettings set org.gnome.desktop.input-sources xkb-options "['grp:caps_toggle', 'lv3:ralt_switch']"`
5. Logout/login
6. Install kitty: `curl -fsSL https://sw.kovidgoyal.net/kitty/installer.sh | sh /dev/stdin launch=n`
7. Fix .desktop paths: Exec, TryExec, Icon → full paths to `~/.local/kitty.app/...`
8. Deploy kitty config: `kitty/kitty.conf`, `kitty/current-theme.conf`, `kitty/ru-shortcuts.conf` → `~/.config/kitty/`

## Rules

### pane-tester for VM operations

Commands inside VMs go through `pane-tester` skill. Sudo password: `echo '<vm-password>' | sudo -S` (bash `!` requires single quotes).

### Full output — NO truncation

Never pipe through `tail`, `head`, or any truncation. User sees full output of every command.

### Confirmation checkpoints

Agent STOPS and waits for human at:
- After layout deployed + logout/login — does it work?
- After functional tests — pass/fail?
- After revert — system restored?
