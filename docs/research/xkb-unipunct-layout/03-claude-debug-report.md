# CapsLock Layout Switch — Wayland Ubuntu 26.04 (QEMU/KVM)
**Дата:** 27 мая 2026  
**Система:** Ubuntu 26.04 LTS (Resolute Raccoon), GNOME Shell 50.1, ядро 7.0.0-15-generic  
**Окружение:** Гостевая VM в QEMU/KVM (virt-manager), дисплей через SPICE  
**Хост:** Pop!OS 22.04  
**Проблема:** CapsLock переключает раскладку, но через ~1 секунду откатывает обратно

---

## Хронология диагностики

### Шаг 1 — Первичная диагностика
```bash
gsettings get org.gnome.desktop.input-sources xkb-options  # → @as []
gsettings get org.gnome.desktop.input-sources sources       # → [('xkb', 'us')]
```
**Вывод:** xkb-options пустой, стоит только одна раскладка `us` — переключать нечего.

**Попытка исправить:**
```bash
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru')]"
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:caps_toggle', 'caps:none']"
```
**Результат:** Не помогло, всё равно откатывает.

---

### Шаг 2 — Диагностика сессии и процессов
```bash
echo $XDG_SESSION_TYPE   # → wayland
ps aux | grep -E 'ibus|fcitx'
env | grep -E 'GTK_IM|QT_IM|XMODIFIERS'
```
**Вывод:** Запущен IBus (`ibus-daemon`, `ibus-x11`, `ibus-extension-gtk3` и др.)  
Переменные окружения: `QT_IM_MODULE=ibus`, `XMODIFIERS=@im=ibus`

---

### Шаг 3 — Мониторинг dconf
```bash
dconf watch /org/gnome/desktop/input-sources/
```
**Вывод:** Меняется только `mru-sources` (порядок раскладок), `current` **не меняется вообще** — GNOME не знает о переключении.

---

### Шаг 4 — Мониторинг IBus engine в реальном времени
```bash
while true; do echo "$(date +%H:%M:%S.%3N) | $(ibus engine) | $(gsettings get org.gnome.desktop.input-sources current)"; sleep 0.2; done
```
**Вывод:** `ibus engine` прыгает `xkb:ru::rus` → `xkb:us::eng` → `xkb:ru::rus` → ...  
`current` всегда `uint32 0` — GNOME не меняет текущую раскладку.

**Вывод:** IBus переключает свой внутренний движок, но GNOME shell синхронизирует IBus обратно к `current=0` через ~1 сек.

---

### Шаг 5 — Попытки исправить IBus

**Попытка 1 — отключить hotkeys IBus:**
```bash
gsettings set org.freedesktop.ibus.general use-system-keyboard-layout true
gsettings set org.freedesktop.ibus.general.hotkey triggers "[]"
gsettings set org.freedesktop.ibus.general.hotkey next-engine-in-menu "[]"
gsettings set org.freedesktop.ibus.general.hotkey previous-engine "[]"
pkill ibus-daemon && ibus-daemon --panel=disable --replace --daemonize
```
**Результат:** Не помогло.

**Попытка 2 — найти откуда стартует IBus:**
```bash
grep -r 'ibus' /usr/lib/systemd/user/
# Найдено:
# /usr/lib/systemd/user/org.freedesktop.IBus.session.GNOME.service
# ExecStart=sh -c 'exec /usr/bin/ibus-daemon --panel disable ...'
```

**Попытка 3 — замаскировать IBus systemd unit:**
```bash
systemctl --user mask org.freedesktop.IBus.session.GNOME.service
systemctl --user stop org.freedesktop.IBus.session.GNOME.service
```
**Результат:** IBus убит, но раскладка всё равно откатывает → **IBus не единственный виновник**.

---

### Шаг 6 — Обнаружение настройки IBus
```bash
gsettings list-recursively org.freedesktop.ibus | grep -i 'hotkey\|engine'
# Найдено:
# org.freedesktop.ibus.general.hotkey next-engine ['Alt+Shift_L']
# org.freedesktop.ibus.general use-global-engine true
```

**Попытка:**
```bash
gsettings set org.freedesktop.ibus.general.hotkey next-engine "[]"
gsettings set org.freedesktop.ibus.general use-global-engine false
```
**Результат:** Не помогло.

---

### Шаг 7 — Попытки с разными xkb-options

```bash
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:caps_switch']"
```
**Результат:** Один раз сработало (держало раскладку, но не обновляло индикатор в панели) — после перелогина перестало работать.

```bash
gsettings set org.gnome.desktop.wm.keybindings switch-input-source "['Caps_Lock']"
```
**Результат:** Всё большими буквами, Super+Space сломался.

---

### Шаг 8 — keyd (перехват на уровне ядра)

**Установка:**
```bash
sudo apt install keyd
```
Бинарник оказался `keyd.rvaiya` (переименован в Ubuntu 26.04).

**Конфиг `/etc/keyd/default.conf`:**
```ini
[ids]
0001:0001:09b4e68d

[main]
capslock = M-space
```
`M-space` = Super+Space в нотации keyd.

**Проблема с конфигом:** keyd ожидает файл с расширением `.conf`, без него конфиг не применялся.

**Результат после исправления:** keyd корректно шлёт `leftmeta + space` (подтверждено через `keyd.rvaiya monitor`), CapsLock переключает раскладку. ✅

**Но после перезагрузки:** IBus снова запустился и начал сбрасывать.

---

### Шаг 9 — Обнаружение истинной причины

```bash
sudo libinput debug-events | grep -v POINTER
```
**При одном нажатии CapsLock:**
```
+12.316s  *** (-1) pressed   ← физическое нажатие
+12.663s  *** (-1) pressed   ← автоматическое повторное нажатие от QEMU!
```

**Вывод:** QEMU/SPICE генерирует **двойное нажатие CapsLock** — синхронизирует состояние Caps Lock между хостом и гостем. Раскладка переключается и тут же переключается обратно.

---

### Шаг 10 — Попытки исправить на уровне QEMU/SPICE

**Попытка 1 — изменить тип keyboard с ps2 на virtio в XML VM:**
```xml
<!-- было -->
<input type='keyboard' bus='ps2'>

<!-- стало -->
<input type='keyboard' bus='virtio'>
```
**Результат:** Двойное нажатие осталось.

**Попытка 2 — добавить `<keymap>en-us</keymap>` в секцию SPICE:**  
**Результат:** libvirt отклонил XML как невалидный.

**Попытка 3 — переключиться на VNC вместо SPICE:**  
Не завершена (отложено).

---

## Итог

| Что пробовали | Результат |
|---|---|
| `grp:caps_toggle` в xkb-options | Откатывает |
| Отключить IBus | Откатывает |
| keyd → Super+Space | Работает, но после ребута IBus мешает |
| `grp:caps_switch` | Один раз сработало, нестабильно |
| Hyprland с `kb_options = grp:caps_toggle` | Откатывает |
| virtio keyboard вместо ps2 | Откатывает |
| GNOME Tweaks / `switch-input-source=['Caps_Lock']` | Ломает апперкейс |

**Корневая причина:** QEMU/SPICE синхронизирует состояние CapsLock между хостом и гостем, генерируя двойное нажатие. Одно переключает раскладку, второе переключает обратно.

**Что работает внутри VM:**
- Super+Space ✅
- Alt+Shift ✅
- Shift+CapsLock ✅

---

## Следующие шаги

1. **Тест на реальном железе (Live USB)** — если на физической машине без QEMU проблема исчезает, значит это исключительно проблема SPICE/QEMU синхронизации CapsLock.

2. **Переключить SPICE на VNC** в настройках VM — VNC не синхронизирует состояние CapsLock.
   ```xml
   <graphics type='vnc' port='-1' autoport='yes' listen='127.0.0.1'>
     <listen type='address' address='127.0.0.1'/>
   </graphics>
   ```
   И удалить `<audio id='1' type='spice'/>`.

3. **Если на реальном железе тоже не работает** — смотреть в сторону бага GNOME 50 + IBus + Wayland.

---

## Рабочая конфигурация (если не в VM)

```bash
gsettings set org.gnome.desktop.input-sources sources "[('xkb', 'us'), ('xkb', 'ru')]"
gsettings set org.gnome.desktop.input-sources xkb-options "['grp:caps_toggle', 'caps:none']"
```

Или через Hyprland `~/.config/hypr/hyprland.conf`:
```ini
input {
    kb_layout = us,ru
    kb_options = grp:caps_toggle,caps:none
}
```
