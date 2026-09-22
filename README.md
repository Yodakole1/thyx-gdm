<div align="center">

# **_Thyx_** · GDM

**A GDM login screen with the Thyx design system.**

<p align="center">
  <a href="#installation">
    <img src="https://img.shields.io/badge/Platform-Linux-black?logo=linux&logoColor=white&style=for-the-badge&labelColor=111111" alt="Platform: Linux"/>
  </a>
  <a href="#requirements">
    <img src="https://img.shields.io/badge/Greeter-GDM%20%2F%20GNOME%20Shell-black?logo=gnome&logoColor=white&style=for-the-badge&labelColor=111111" alt="GDM / GNOME Shell"/>
  </a>
  <a href="./LICENSE">
    <img src="https://img.shields.io/badge/License-MIT-black?logo=mit&logoColor=white&style=for-the-badge&labelColor=111111" alt="License: MIT"/>
  </a>
</p>

</div>

---

## What this is

[Thyx](https://github.com/rccyx/thyx) is a beautiful SDDM theme written in QML. This fork keeps its
design system — the palettes, the wallpapers, the type, the soft translucent
pills — and rebuilds it for **GDM**, the login screen GNOME ships.

That is not a port in the usual sense. SDDM runs a QML application you write
end to end. GDM has no such seam: its greeter *is* GNOME Shell, and the only
thing you can hand it is a stylesheet. So the QML is gone, and in its place is
a build that reads the same `theme.conf` and produces a GNOME Shell greeter
resource.

**Use this fork if you run GNOME.** Use [upstream](https://github.com/rccyx/thyx) if you run SDDM.

## What changed from upstream

| | upstream Thyx | this fork |
| --- | --- | --- |
| Greeter | SDDM | GDM / GNOME Shell |
| Theme format | QML application | GNOME Shell `gresource` + CSS |
| Config | `theme.conf` | `theme.conf`, same idea, GDM-shaped keys |
| Presets | 5 | the same 5, re-derived |
| Video backgrounds | yes | **no** — GDM cannot play video; clips contribute one frame |
| Blur | at runtime, per frame | baked in at build time, free at runtime |
| Preview | `sddm-greeter --test-mode` | a real headless greeter, screenshotted |
| Install | copies a theme directory | registers a `gdm-theme` alternative |

Fixed along the way, in the design system these presets came from:

- The focus ring was hard-coded `#8ab4f8`, a blue that fought every preset it
  shipped with. It is `FocusRingColor` now.
- Field colours were built by slicing the hex string by character index, so
  anything that was not exactly `#rrggbb` silently produced garbage. Colours
  are parsed and validated, and a bad one stops the build.
- The field translucency was a hard-coded `0.25`. It is `FieldOpacity` now.
- `DateFormat` was documented but never read; the date was hard-coded to
  English day and month names. Date and time now follow your locale, through
  the settings GDM actually reads.

And, found on Ubuntu itself:

- **Greeter settings never reached the greeter.** A keyfile in
  `/etc/dconf/db/gdm.d` is only read if the greeter's dconf profile names a
  system database, and Ubuntu's ships without one — it lists `user-db:user`
  and a `file-db` and nothing else. Every font, clock and logo setting Thyx
  wrote was silently inert. Thyx now ensures the profile, the same way
  Ubuntu's own `gdm-config` does, and reads a key back afterwards to prove it
  landed.
- **The vendor logo hung off the bottom of the screen.** GDM allocates the
  logo bin at `screen_bottom - bin_height` and does not clip its contents, so
  pinning the bin to a fixed height shorter than the image left the rest of
  the image below the edge of the display. The bin is unconstrained now, and
  a margin holds the mark clear.

## Requirements

- GNOME Shell with GDM — developed against **GNOME Shell 46 / Ubuntu 24.04**
- `glib-compile-resources` and `gresource` (`libglib2.0-bin` on Debian and Ubuntu, `glib2` elsewhere)
- `ffmpeg` or ImageMagick, to scale, blur and dim the wallpaper
- `dconf`, for the greeter's font and clock settings
- For `scripts/preview`: `python3-gi` and `gstreamer1.0-pipewire`

On Ubuntu and Debian:

```bash
sudo apt install libglib2.0-bin ffmpeg dconf-cli python3-gi gstreamer1.0-pipewire
```

## Presets

Five palettes, each with its own wallpaper.

| | |
| :---: | :---: |
| **Cinder** — ember and soot | **Gilded** — old gold on deep pine |
| **Blush** — soft rose, easy at 7am | **Malachite** — green stone and copper |
| **Sakura** — pale petals on ink | |

Cinder is the default. Upstream's Cinder was a looping video; here it is a
frame taken from that clip, because GDM has no video layer to play it on.

## Quick start

```bash
git clone https://github.com/rccyx/thyx
cd thyx

./scripts/preview          # see it, without installing anything
./scripts/install          # make it your login screen
```

Log out or reboot to see it for real. Your running session is never touched,
and nothing is restarted behind your back.

## Preview

```bash
./scripts/preview
./scripts/preview --config presets/malachite.conf
```

This starts a **real GNOME Shell in greeter mode**, headless, on its own D-Bus
session and its own throwaway config, pointed at the theme you just built. It
records one frame through Mutter's screencast interface and saves it to
`build/preview.png`.

Nothing is installed, your session keeps running, and you cannot lock yourself
out with it.

One honest limitation: the account list stays empty in the preview. GDM will
not hand a greeter proxy to a user who is already logged in, so the form has
nothing to draw. What you are checking here is the backdrop, the top bar, the
type and the palette. The form you see for real at the login screen.

## Installation

```bash
./scripts/install           # builds, shows a plan, asks, installs
./scripts/install --yes     # no questions
./scripts/install --config presets/sakura.conf
./scripts/install --check   # report drift, change nothing
```

The installer prints exactly what it will do before it touches anything, asks
for confirmation and sudo, and logs the run to `~/.cache/thyx/`.

<details>
<summary><strong>What the installer does</strong></summary>

<br/>

1. finds the repo, and refuses to run outside one
2. checks for GNOME Shell and the tools it needs
3. builds the theme from `theme.conf` (see **How it works** below)
4. prints the plan and asks for confirmation and sudo
5. installs the bundled fonts to `/usr/local/share/fonts/thyx` and refreshes the font cache
6. writes the bundle to `/usr/share/gnome-shell/theme/thyx/gnome-shell-theme.gresource`, staged and renamed so the greeter never reads a half-written file
7. registers it as the `gdm-theme.gresource` alternative at priority 20, above Yaru's 15 and stock GNOME's 10 — or, where `update-alternatives` does not exist, backs the stock file up once and replaces it
8. writes the greeter's font, clock and logo settings to `/etc/dconf/db/gdm.d/95-thyx` and runs `dconf update`
9. records what it did in `/var/lib/thyx/install.state`
10. verifies that the greeter now resolves to the Thyx bundle
11. never restarts GDM

**The stock theme is never edited.** Thyx builds a complete copy of it and
installs that alongside. Upstream's file stays exactly where it was, which is
what makes the uninstall a one-liner.

</details>

### Staying current

Because the install is a complete copy of whatever upstream theme existed at
build time, it is a snapshot. A `gnome-shell` or distro-theme upgrade does not
disturb it and does not error: `update-alternatives` keeps the selection on
manual and goes on pointing at a perfectly valid file that is simply older
than the shell now reading it. Nothing tells you this has happened, so:

```bash
./scripts/install --check    # or: just check
```

It reads nothing but `/var/lib/thyx/install.state`, needs no sudo, changes
nothing, and compares the `source_sha256` recorded at build time against the
upstream bundle that is installed today. It also confirms the greeter still
resolves to Thyx and that the dconf profile still reaches Thyx's settings.
Exit status is 0 when everything is current and 1 when it is not, so it suits
a timer or an apt hook. The fix, whatever drifted, is `sudo ./scripts/install`.

Within a stable release this drift is invisible — the greeter stylesheet
barely moves across point updates. The one worth checking after is a release
upgrade, where the greeter's JavaScript is new but the stylesheet it loads was
built against the old one.

## Uninstallation

```bash
./scripts/uninstall
./scripts/uninstall --keep-fonts
```

It removes the alternative (or restores the backup), deletes the theme, the
greeter settings, the state file and the fonts, then verifies that the greeter
resolves to a real file that is not ours.

It is also the recovery path. If the login screen is ever unhappy, switch to a
TTY with **Ctrl+Alt+F3**, log in, `cd` to this repo and run:

```bash
./scripts/uninstall --yes
```

See [the guide](./docs/guide.md#recovery) for the full recovery protocol,
including the one-line `update-alternatives` version that needs no repo.

## Configuration

Everything lives in `theme.conf`. Edit, preview, repeat.

```bash
cp presets/malachite.conf theme.conf
./scripts/preview
./scripts/install
```

Or keep your own, and never touch `theme.conf`:

```bash
cp presets/gilded.conf presets/mine.conf
$EDITOR presets/mine.conf
./scripts/preview --config presets/mine.conf
./scripts/install --config presets/mine.conf
```

### Background

| Setting | Description | Example |
| --- | --- | --- |
| `Background` | Wallpaper path, relative to the repo | `"backgrounds/cinder.jpg"` |
| `BackgroundColor` | Behind the image, and before it loads | `"#070304"` |
| `Blur` | `0.0` – `1.0`, applied at build time | `"0.35"` |
| `Dim` | `0.0` – `1.0`, applied at build time | `"0.20"` |
| `BackgroundMaxWidth` | Downscale ceiling, in pixels | `"2560"` |

Blur and dim are baked into the image when you build, not computed by the
greeter on every frame. A 13 MB wallpaper becomes a few hundred KB, and the
login screen draws one flat blit.

Point `Background` at an `.mp4`, `.webm`, `.mkv`, `.mov`, `.m4v` or `.avi` and
the build pulls a frame out of it with ffmpeg. There is no video at the login
screen — GNOME Shell has no layer to play one on — so this is a still.

### Typography

| Setting | Description | Example |
| --- | --- | --- |
| `Font` | Family name as fontconfig knows it | `"Plus Jakarta Sans"` |
| `FontSize` | Base size, in points | `"11"` |
| `WeightUI` | Top bar, placeholders, messages | `"400"` |
| `WeightEmphasis` | Account name, warnings, menu headings | `"500"` |
| `ClockWeight` | The clock in the top bar | `"400"` |
| `FieldWeight` | What you type into the password pill | `"400"` |
| `ButtonWeight` | The primary action | `"600"` |

Ships with **Plus Jakarta Sans**, installed system wide by the installer so the
greeter — which runs as its own user, long before yours — can see it.

Plus Jakarta Sans is a variable face that reads heavy early, so those weights
sit lower than the numbers suggest: 400 is the body and anything past 600
turns the greeter into a poster. Yaru closes its own sheet with
`* { font-weight: normal !important; }`, which is why every weight Thyx sets
is forced — a class selector with `!important` outranks a universal one.

To use something else, list what you have and use the exact family name:

```bash
fc-list -f "%{family}\n" | sort -u
```

### Clock

GDM has no separate clock widget. The top bar's date menu is the only clock on
screen, so Thyx grows it into the greeter's timestamp.

| Setting | Description | Options |
| --- | --- | --- |
| `ClockSize` | Size in points | `"20"` |
| `TimeTextColor` | Clock colour | `"#ffd0bf"` |
| `DateTextColor` | Colour on hover | `"#e4b2a3"` |
| `HourFormat` | Time format | `"24h"`, `"12h"` |
| `ShowDate` | Show the date | `"true"`, `"false"` |
| `ShowWeekday` | Show the weekday | `"true"`, `"false"` |
| `ShowSeconds` | Show seconds | `"true"`, `"false"` |

### Shape and motion

| Setting | Description | Example |
| --- | --- | --- |
| `Radius` | Pill radius for fields and buttons | `"24"` |
| `RadiusSmall` | Radius for menu items and chips | `"10"` |
| `AnimationDuration` | Hover and focus transitions, in ms | `"200"` |
| `FieldOpacity` | How much of the field colour shows, `0.0` – `1.0` | `"0.25"` |
| `FormOpacity` | Panel behind the form, `0.0` – `1.0` | `"0.00"` |

### Session and login-options pickers

| Setting | Description | Example |
| --- | --- | --- |
| `MenuButtonSize` | Diameter of the two corner buttons, in pixels | `"44"` |
| `MenuButtonIconSize` | The gear inside them | `"20"` |
| `MenuButtonBorderWidth` | Their outline | `"1"` |

The bottom-right corner holds the session picker — the only way to choose
Wayland or Xorg before signing in — and the login-options picker. GDM labels
neither; both are a bare gear on a flat background, easy to read as
decoration. Thyx outlines them and gives them the accent on hover, and the
menu that opens gets a visible heading.

### Colours

Every colour is `#rrggbb`. Anything else stops the build with the name of the
setting that was wrong.

**Form** — `FormBackgroundColor`, `LoginFieldBackgroundColor`,
`LoginFieldTextColor`, `PlaceholderTextColor`, `FocusRingColor`,
`FocusRingWidth`

**Primary action** — `LoginButtonBackgroundColor`, `LoginButtonTextColor`,
`HoverLoginButtonBackgroundColor`

**Secondary controls** — `SystemButtonsIconsColor`,
`HoverSystemButtonsIconsColor`, `EnvironmentButtonTextColor`,
`HoverEnvironmentButtonTextColor`

**Menus** — `DropdownTextColor`, `DropdownSelectedTextColor`,
`DropdownBackgroundColor`, `DropdownSelectedBackgroundColor`,
`DropdownBorderColor`

**Messages** — `WarningTextColor`, used for Caps Lock and for
"Sorry, that didn't work"

**Avatar** — `AvatarSize`, `AvatarRadius`, `AvatarBorderWidth`,
`AvatarBorderColor`

You set one field colour and one opacity; the resting, hover and focus states
are derived from them so they stay in step.

### Where the form sits

| Setting | Description | Example |
| --- | --- | --- |
| `FormPosition` | Which side the sign-in column sits on | `"left"`, `"center"`, `"right"` |
| `FormOffset` | How far from the middle of the screen, in pixels | `"480"` |

GDM centres the form on the primary monitor and offers no way to anchor it,
and St — GNOME Shell's CSS engine — has no percentage lengths to lay a column
out with. What it does honour is padding, and a centred box grows both ways
from its middle: padding one flank by `2n` slides everything visible `n`
pixels the other way. So `FormOffset` is measured from the centre of the
screen rather than from its edge, which is the one definition that holds up
across monitor sizes. The wordmark travels with the column.

`FormPosition="center"` ignores `FormOffset`. If the offset is wider than the
screen can take, the form ends up flush against that edge rather than off it.

### Wordmark

| Setting | Description | Example |
| --- | --- | --- |
| `ShowLogo` | Draw a mark at the foot of the screen | `"true"`, `"false"` |
| `LogoText` | What it says | `"ubuntu"` |
| `LogoImage` | An image to use instead of drawing text | `"backgrounds/mark.png"` |
| `LogoSize` | Cap height, in pixels | `"34"` |
| `LogoWeight` | Weight of the lettering | `"700"` |
| `LogoTracking` | Letter spacing, in pixels | `"-1"` |
| `LogoColor` | Colour of the lettering | `"#f3c4aa"` |
| `LogoOpacity` | `0.0` – `1.0` | `"0.75"` |
| `LogoBottomMargin` | Clearance from the bottom edge, in pixels | `"56"` |

GDM's logo setting takes a path to an image and blits the file at its own
pixel size, which is why the stock Ubuntu mark can never match a theme: its
lettering is baked into `/usr/share/plymouth/ubuntu-logo.png`. Thyx draws its
own from `LogoText` at build time, in the same family, weight and colour as
the rest of the greeter, and installs it beside the bundle.

### Greeter behaviour

| Setting | Description | Options |
| --- | --- | --- |
| `DisableUserList` | Ask for a username instead of listing accounts | `"true"`, `"false"` |

`DisableUserList="true"` is worth considering if you would rather not
advertise who has an account on the machine.

## How it works

GNOME Shell loads its greeter stylesheet from a single compiled resource
bundle, `gdm-theme.gresource`. There is no theme directory to drop files into
and no supported hook to add a stylesheet, so a GDM theme is, unavoidably, a
replacement bundle.

`scripts/build`:

1. finds the **stock** bundle — never Thyx's own output, so the override block
   cannot stack up on rebuilds
2. extracts all of it, about 150 resources
3. renders `src/overrides.css.in` against `theme.conf` and **appends** it to
   the stock `gdm.css`, between markers, so nothing upstream is lost and every
   Thyx rule is an override
4. scales, blurs and dims the wallpaper and adds it to the bundle
5. writes the greeter's gsettings to `build/greeter.dconf`
6. compiles it all back and checks the result is readable and has a `gdm.css`

Appending rather than replacing is what keeps this maintainable: when GNOME or
Yaru updates their stylesheet, rebuild and you are on the new one with Thyx
still on top.

`scripts/install` then puts that bundle somewhere of its own and points the
`gdm-theme.gresource` alternative at it. That is the whole of the system
change, and `update-alternatives --remove` is the whole of the undo.

## Requirements this cannot meet

Worth saying plainly, because upstream's README promises some of these:

- **No video backgrounds.** GNOME Shell's greeter has no video layer.
- **No form position.** GDM centres its dialog and the position is not
  expressible in CSS.
- **No giant centred clock.** The greeter has one clock, in the top bar.
  `ClockSize` grows it; it will not become the 108pt clock the QML drew.
- **No fingerprint auto-start setting.** GDM starts fingerprint
  authentication by itself when PAM is configured for it. There is nothing
  to enable.
- **Caps Lock, password reveal and the account list are GDM's own.** They are
  styled here, not implemented here.

## Credits

Thyx, its design system, its presets and its wallpapers are by
[@rccyx](https://github.com/rccyx). This fork carries that design to GDM.

Wallpaper credits are in [backgrounds/README.md](./backgrounds/README.md).

## License

MIT, as upstream.
