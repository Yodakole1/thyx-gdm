# Guide

Thyx for GDM is a **login screen** theme. It controls the screen that asks for
your password before the desktop starts. Once you are in, GDM hands the screen
to your session and Thyx is no longer on it.

This guide covers what GDM is, why theming it looks the way it does, exactly
what this repo puts on your system, and how to get out of trouble.

---

## The login stack

A Linux machine can boot to several kinds of login surface.

The simplest is a **TTY** — the plain text login the kernel and systemd
provide. It needs no desktop, no Wayland, no X11 and no display manager. It is
always there, and it is your way back if anything goes wrong. Remember
**Ctrl+Alt+F3**.

A graphical desktop needs something more: a program that draws the login UI,
authenticates you through PAM, lists the sessions you can start, and starts the
one you pick. That program is a **display manager**.

| display manager | usually paired with |
| --- | --- |
| `gdm` / `gdm3` | GNOME |
| `sddm` | KDE Plasma, and many custom Wayland setups |
| `lightdm` | XFCE, Cinnamon, older distros |
| `ly`, `greetd` | minimal and tiling setups |

GNOME, Plasma, XFCE, Hyprland and Sway are **sessions**. The display manager is
what gets you into one.

This repo themes **GDM**. If you run SDDM, you want
[upstream Thyx](https://github.com/rccyx/thyx) instead.

---

## Why GDM theming is different

SDDM loads a *theme*: a directory with a QML application in it. You write the
whole interface — where the clock goes, what the password field looks like,
what happens on a failed login. Upstream Thyx is about 1,300 lines of QML doing
exactly that.

GDM has no equivalent. **GDM's greeter is GNOME Shell**, started in a special
session mode, running the same JavaScript that runs your desktop. There is no
theme directory, no QML, no hook to add a file. The only thing that is yours to
change is the **stylesheet**.

So a GDM theme is a stylesheet — and because GNOME Shell reads that stylesheet
out of a compiled resource bundle rather than from disk, a GDM theme is in
practice a *replacement bundle*.

```
/usr/share/gnome-shell/gdm-theme.gresource   <- what the greeter loads
        |
        +-- /org/gnome/shell/theme/gdm.css   <- the greeter stylesheet
        +-- /org/gnome/shell/theme/*.svg     <- ~150 other resources
```

On Ubuntu that path is not a file. It is a symlink managed by
`update-alternatives`, which is a gift: it means a custom theme can be
registered as one more alternative and selected by priority, instead of
overwriting anything.

```bash
update-alternatives --display gdm-theme.gresource
```

```
gdm-theme.gresource - auto mode
  link currently points to /usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource
/usr/share/gnome-shell/gnome-shell-theme.gresource - priority 10
/usr/share/gnome-shell/theme/Yaru/gnome-shell-theme.gresource - priority 15
```

Thyx registers at priority **20**.

---

## What the build does

`scripts/build` never edits the stock bundle. It builds a new one.

**1. Find the stock bundle.** Specifically the *stock* one — if Thyx is already
installed, the alternatives list still knows where Yaru's is. Building from
Thyx's own output would append the override block to a sheet that already has
it, over and over.

**2. Extract it.** All ~150 resources, to `build/stage/`.

**3. Append, don't replace.** `src/overrides.css.in` is rendered against
`theme.conf` and appended to the stock `gdm.css` between markers:

```css
/* thyx:begin */
  ... every Thyx rule ...
/* thyx:end */
```

Everything upstream still applies. Every Thyx rule is an override of it. When
GNOME or Yaru ships a new stylesheet, you rebuild and you are on the new one
with Thyx still on top.

One wrinkle worth knowing, because it explains all the `!important` in the
stylesheet: Ubuntu's Yaru sheet ends with

```css
* { font-weight: normal !important; text-shadow: none !important; }
```

A universal selector has zero specificity, so a class selector marked
`!important` still beats it — which is why Thyx marks the weights it cares
about and nothing else.

**4. Bake the wallpaper.** Scaled to `BackgroundMaxWidth`, blurred by `Blur`,
dimmed by `Dim`, written into the bundle as a JPEG. Doing this at build time
rather than at runtime is why the greeter costs nothing to draw: 13 MB of
wallpaper becomes a few hundred KB and one flat blit. It is also why `Blur`
here is not the live blur the QML did — there is no live blur to have.

Point `Background` at a video and ffmpeg pulls one frame out of it. There is no
video at a GNOME login screen.

**5. Write the greeter's settings.** Some things are not stylesheet material.
The font, the clock format, whether the weekday shows, whether the vendor logo
shows, whether accounts are listed — GDM reads those as **gsettings**, from its
own dconf profile. The build writes them to `build/greeter.dconf`, which the
installer drops into `/etc/dconf/db/gdm.d/` and the preview loads into a
throwaway database. Both get the same values that way.

**6. Compile and check.** Back into a `.gresource`, then verified: readable,
and it has a `gdm.css`. A bundle the shell cannot parse is worse than no theme,
so this never ships unchecked.

---

## What preview actually runs

`scripts/preview` is not a mockup. It starts **GNOME Shell itself**, in greeter
mode:

```
gnome-shell --headless --virtual-monitor 1920x1080 --mode=gdm
```

inside `dbus-run-session`, with three redirections that keep it away from your
system:

| variable | effect |
| --- | --- |
| `GNOME_SHELL_DATADIR` | the shell loads *your built* `gdm-theme.gresource` |
| `XDG_CONFIG_HOME` | a private dconf database for the greeter settings |
| `FONTCONFIG_FILE` | the bundled font, without installing it system wide |

Headless means no window and no output device, so there is nothing to
screenshot in the usual way — and gdm's session mode does not export
`org.gnome.Shell.Screenshot` anyway. Instead the preview records the virtual
monitor through **Mutter's own screencast interface** into PipeWire and keeps a
single frame.

Nothing is installed. Your session is untouched. You cannot lock yourself out
with it.

**What you will not see:** the account list and the password field. GDM refuses
to hand a greeter proxy to a user who is already logged in —

```
Can only be called before user is logged in
```

— so the form never initialises. The preview is an honest check of the
backdrop, the top bar, the type and the palette. The form you check for real,
at the login screen, with the uninstaller one TTY away.

---

## What ends up on your system

| path | what |
| --- | --- |
| `/usr/share/gnome-shell/theme/thyx/gnome-shell-theme.gresource` | the theme |
| `/usr/share/gnome-shell/gdm-theme.gresource` | the alternatives link, now pointing at Thyx |
| `/usr/share/gnome-shell/theme/thyx/logo.png` | the wordmark, which GDM wants as a path, not a resource |
| `/etc/dconf/db/gdm.d/95-thyx` | the greeter's font, clock and logo settings |
| `/etc/dconf/profile/gdm` | only if the packaged profile reads no system database — see below |
| `/usr/local/share/fonts/thyx/` | Plus Jakarta Sans |
| `/var/lib/thyx/install.state` | what was installed, and what it was built from |
| `~/.cache/thyx/thyx-install-*.log` | the log of the run |

Nothing else is modified, and none of those paths belongs to a package —
`dpkg -S` reports no owner for any of them. The stock bundle is where it
always was; the packaged dconf profile and the distro's gschema overrides are
only ever read.

### Why `/etc/dconf/profile/gdm`

A keyfile under `/etc/dconf/db/gdm.d` does nothing on its own. It is only read
if the greeter's dconf profile names a system database, and Ubuntu's does
not:

```
$ cat /usr/share/dconf/profile/gdm
user-db:user
file-db:/var/lib/gdm3/greeter-dconf-defaults
```

No `system-db:gdm` line, so the keyfile is never consulted and every greeter
setting is silently ignored — the failure looks exactly like a successful
install.

The fix is not to edit that file. `dconf` looks in `/etc/dconf/profile` before
`/usr/share/dconf/profile`, and `/etc` is the administrator's to write: no
package ships anything there, so a `gdm3` upgrade cannot clobber it. Thyx
copies the packaged profile, inserts `system-db:gdm` below the writable
database, and marks the result as its own. This is the same thing Ubuntu's own
`gdm-config` does when it needs a greeter setting to stick.

The copy is re-rendered from the packaged profile on every install, so if a
future `gdm3` changes its own profile the shadow picks the change up instead
of pinning the greeter to a stale database list. If something else already
owns the file — `gdm-config` writes one too — Thyx adds the one line it needs
and keeps the original for the uninstaller. If the profile already reaches
`/etc/dconf/db/gdm.d`, as on distributions that ship it that way, Thyx writes
nothing at all.

`scripts/install` finishes by reading a key back through
`DCONF_PROFILE=gdm`, so a profile that does not line up is reported rather
than discovered at the login screen.

The fonts have to be system wide because the greeter runs as the `gdm` user,
before you have logged in. A font in your home directory does not exist as far
as it is concerned.

---

## Recovery

Themes that replace the login screen deserve a way out that does not depend on
the login screen working. This one has three, in order of how little they need.

### 1. Get to a TTY

**Ctrl+Alt+F3.** Log in with your username and password. You have a shell. The
graphical login being broken does not affect this.

### 2. Run the uninstaller

```bash
cd /path/to/thyx
./scripts/uninstall --yes
sudo systemctl restart gdm
```

### 3. If you cannot find the repo

The install is one alternatives entry. Remove it by hand:

```bash
sudo update-alternatives --remove gdm-theme.gresource \
  /usr/share/gnome-shell/theme/thyx/gnome-shell-theme.gresource
sudo systemctl restart gdm
```

`--remove` drops Thyx from the list and `update-alternatives` falls back to the
highest remaining priority, which is your distro's own theme. That is the whole
recovery.

On a system without `update-alternatives`, the installer backed the stock file
up first:

```bash
sudo mv /usr/share/gnome-shell/gdm-theme.gresource.thyx-back \
        /usr/share/gnome-shell/gdm-theme.gresource
sudo systemctl restart gdm
```

> [!WARNING]
> `systemctl restart gdm` ends your graphical session. Save your work first, or
> just reboot.

### If the greeter shows but looks wrong

That is a stylesheet problem, not a lockout. Log in normally, change
`theme.conf`, and run `./scripts/install` again.

---

## Living with it

**Switching presets**

```bash
./scripts/install --config presets/sakura.conf
```

**After a GNOME or Yaru update**

Thyx was built against the stylesheet that was current when you installed it.
An updated one does not break anything — the alternatives link still points at
a valid bundle — but you will be on the old upstream sheet until you rebuild:

```bash
./scripts/install
```

`/var/lib/thyx/install.state` records which bundle yours was built from, and
its checksum, if you want to check.

**Does this theme the lock screen?**

No. `Super+L` is GNOME Shell in *your* session, styled by your shell theme, not
by GDM's. It is a different stylesheet in a different resource bundle owned by
a different user. Same look is achievable, but it is a separate problem and
this repo does not solve it.
