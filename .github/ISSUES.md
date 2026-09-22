# Issues

Have you read the [guide](../docs/guide.md)? The
[how it works](../README.md#how-it-works) section explains what the build
actually produces, which answers a good share of questions on its own.

**This fork themes GDM.** If you run SDDM, you want
[upstream Thyx](https://github.com/rccyx/thyx) — issues about SDDM belong
there, not here.

Before opening anything, a few things that are not bugs:

- **No video background.** GNOME Shell's greeter has no video layer. A clip
  contributes one frame and that is the ceiling.
- **The form is centred.** GDM decides that, and CSS cannot move it.
- **The clock is in the top bar.** That is the only clock the greeter has.
  `ClockSize` grows it; it will not become a giant centred clock.
- **The preview shows no account list.** GDM will not hand a greeter proxy to
  a user who is already logged in. This is expected; see the guide.
- **The lock screen is unchanged.** `Super+L` is your own session's shell, not
  GDM.

## If you are locked out

Do this first, then open the issue:

```bash
# Ctrl+Alt+F3 to reach a TTY, log in, then:
sudo update-alternatives --remove gdm-theme.gresource \
  /usr/share/gnome-shell/theme/thyx/gnome-shell-theme.gresource
sudo systemctl restart gdm
```

## What to include

The logs, first:

```bash
ls ~/.cache/thyx/
cat ~/.cache/thyx/thyx-install-*.log | tail -60
```

Which GNOME and which distro:

```bash
gnome-shell --version
cat /etc/os-release
echo "$XDG_CURRENT_DESKTOP / $XDG_SESSION_TYPE"
```

Whether GDM is actually your display manager:

```bash
systemctl status display-manager --no-pager | head -3
```

What the greeter resolves to, and what Thyx thinks it installed:

```bash
update-alternatives --display gdm-theme.gresource
readlink -f /usr/share/gnome-shell/gdm-theme.gresource
cat /var/lib/thyx/install.state
```

Whether the bundle is intact:

```bash
gresource list /usr/share/gnome-shell/theme/thyx/gnome-shell-theme.gresource | head
```

Whether the greeter settings landed:

```bash
cat /etc/dconf/db/gdm.d/95-thyx
```

If the build itself failed, the whole output of:

```bash
./scripts/build
```

If the greeter looks wrong rather than broken, a photo of the screen and your
`theme.conf` say more than a description will.
