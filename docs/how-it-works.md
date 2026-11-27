# How it works — the investigation

This is how the "keyboard light turns off at login" problem was traced on a MacBook Pro 15-inch
2019 (`MacBookPro15,3`, board `Mac-1E7E29AD0135F9BC`, T2) running macOS Sequoia 15.8, fitted
with a screen from a 2017 MacBook Pro.

## Symptoms

- Keyboard backlight lit at the login window; drops to 0 the instant any user logs in.
- Screen brightness keys and sliders have no effect; the backlight sits near maximum.
- `AppleHIDKeyboardEventDriverV2` → `KeyboardBacklightBrightness = 0` after login.

## 1. The brightness service has no display

`corebrightnessd` (the daemon behind the brightness keys, Control Center and the Touch Bar)
fails to create a module for the built-in display at boot, before anyone logs in:

```
CBDisplayContainer: ID: 69733446 alias: 2077750201 vendor: 1552 product: 41009 serial: 0 built-in: 1
CBDisplayContainer: internal display
DSDevice: reports=(null)
CoreBrightness: failed to create DSIICDevice
DSDevice: Failed to create new HID or IIC device for displayID 0x04280c46
CBDisplayContainer: failed instantiate internal modules (#1 attempt) - retry
```

DisplayServices agrees: `DisplayServicesCanChangeBrightness(builtin) == false`, and
`DisplayServicesGetBrightness` fails.

## 2. …so it zeroes the keyboard at login

The keyboard backlight container initialises without a valid state
(`Keyboard backlight initialized for lgpVersion = -1`), and the per-user switch fails
(`KeyboardBacklightContainer key=CBUserSwitch … result=0`). From then on every keyboard query
returns -1 and the light is held at 0. The login window is lit because, before a user session,
the driver's default level (`/Library/Preferences/com.apple.iokit.AmbientLightSensor.plist`,
`KeyboardBacklight = 200`) is still in effect.

Resetting `com.apple.CoreBrightness.plist`, restarting the daemon, SMC/NVRAM resets and forcing
the integrated GPU (`pmset gpuswitch 0`) do not change this. The macOS system volume was verified
sealed and intact, so a reinstall would not help either.

## 3. The backlight driver doesn't recognise the panel

The built-in panel's backlight is handled by `AGDCBacklightControl` (in `AppleGraphicsControl.kext`),
attached to the ACPI `PNLF` device. Its `IODisplayParameters` advertise a brightness range but no
current value, and it rejects every get/set (`kIOReturnUnsupported`):

```
"IODisplayParameters" = {"brightness"={"max"=255,"min"=40},"commit"={"reg"=0}}
```

The driver carries an `ApplePanels` table of per-panel brightness curves. Disassembling it shows
how the lookup key is built:

```
snprintf(key, 32, "F%dT%04x", PNLF._UID, DisplayProductID)   // plus P / I / L / D / S variants, then "F%d", then "Default"
```

On this Mac `PNLF._UID = 15` and the 2017 panel reports `DisplayProductID = 0xa031`, so the
driver looks for **`F15Ta031`**. The table only contains `F15Ta044` / `F15Ia040` for this
family; `a031` appears only as `F16Ta031`. The panel never gets a profile
(`AppleNumBrightLevels` / `ApplePanel` are never published), and the kernel log shows the
framebuffer treating it as unmanaged: `[AGDC] AGDC not registered. Unmanaged display`.

Adding the key would mean editing a sealed system kext (SIP and authenticated-root disabled,
re-done after every update), and the fallback path suggests it may not be sufficient anyway —
so Glimmer works around it in user space instead.

## 4. The workarounds

**Keyboard.** WindowServer publishes a virtual HID device, `Keyboard Backlight`
(usage page `0xFF00`, usage `0x0F`), that `corebrightnessd` normally uses. Its vendor page `0xFF70`
has two feature reports:

| Report | Bytes | Meaning |
|---|---|---|
| 3 | `03 EN 00 00 00 00` | `EN` = 1 on / 0 off |
| 1 | `01 LL LL LL LL FF FF FF FF` | level (u32, `KeyboardBacklightMinOn`…`MaxOn`, e.g. 32…512) and fade time in ms (u32) |

Sending those lights the keyboard immediately (`KeyboardBacklightBrightness` 0 → 512). Writing
`KeyboardBacklightBrightness` directly on the driver or through `IOHIDServiceClientSetProperty`
does *not* work. Because `corebrightnessd` keeps driving the level back to 0, Glimmer checks
every 3 s and after wake, and re-applies the chosen level.

**Screen.** With the backlight unmanaged, the only control left is the display's gamma table
(`CGSetDisplayTransferByFormula`): the white point is lowered and the gamma raised together, so
the picture gets darker rather than greyer. The lowest level is clamped to stay readable; below
it, `pmset displaysleepnow` turns the panel off and any input wakes it.

**Keys.** A session event tap watches `NX_SYSDEFINED` events (subtype 8) for
`NX_KEYTYPE_BRIGHTNESS_UP/DOWN` (2/3) and `NX_KEYTYPE_ILLUMINATION_UP/DOWN/TOGGLE` (21/22/23),
which is what the function keys and the Touch Bar's up/down buttons send. Only keys for parts in
workaround mode are taken.
