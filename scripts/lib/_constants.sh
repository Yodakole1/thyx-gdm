#!/usr/bin/env bash
# shellcheck disable=SC2034

THYX_THEME_ID="thyx"

# Where the built theme lives once installed.
THYX_THEME_ROOT="/usr/share/gnome-shell/theme/${THYX_THEME_ID}"
THYX_GRESOURCE_NAME="gnome-shell-theme.gresource"
THYX_GRESOURCE_DST="${THYX_THEME_ROOT}/${THYX_GRESOURCE_NAME}"

# The link GNOME Shell reads when it starts in greeter mode.
THYX_GDM_LINK="/usr/share/gnome-shell/gdm-theme.gresource"
THYX_ALTERNATIVE="gdm-theme.gresource"
# Yaru registers at 15, stock GNOME at 10.
THYX_ALTERNATIVE_PRIORITY=20

# Used only on systems with no update-alternatives, where the stock file is
# replaced directly and this backup is the way home.
THYX_GDM_BACKUP="/usr/share/gnome-shell/gdm-theme.gresource.thyx-back"

# Records what the install was built from, for uninstall and for --check.
THYX_STATE_DIR="/var/lib/${THYX_THEME_ID}"
THYX_STATE_FILE="${THYX_STATE_DIR}/install.state"

THYX_FONTS_DST="/usr/local/share/fonts/${THYX_THEME_ID}"

# GDM reads its gsettings from this dconf profile.
THYX_DCONF_DIR="/etc/dconf/db/gdm.d"
THYX_DCONF_FILE="${THYX_DCONF_DIR}/95-${THYX_THEME_ID}"

# A keyfile in /etc/dconf/db/gdm.d is only read if the greeter's dconf profile
# actually lists a system-db. Ubuntu's shipped profile does not:
#
#   user-db:user
#   file-db:/var/lib/gdm3/greeter-dconf-defaults
#
# so on a stock Ubuntu every greeter setting Thyx writes is silently ignored.
# The fix is the one Ubuntu's own gdm-config uses for the same problem: an
# admin-owned profile at /etc/dconf/profile/gdm, which shadows the packaged
# one at /usr/share/dconf/profile/gdm. No packaged file is edited, and dpkg
# ships nothing at this path, so a gdm3 upgrade cannot clobber it.
THYX_DCONF_PROFILE_DIR="/etc/dconf/profile"
THYX_DCONF_PROFILE_FILE="${THYX_DCONF_PROFILE_DIR}/gdm"
THYX_DCONF_PROFILE_SRC="/usr/share/dconf/profile/gdm"
THYX_DCONF_SYSTEM_DB="gdm"
THYX_DCONF_PROFILE_BACKUP="${THYX_STATE_DIR}/dconf-profile-gdm.orig"

# The wordmark drawn at the foot of the greeter. GDM's logo gsetting takes a
# filesystem path, not a resource URI, so this one lives beside the bundle
# rather than inside it.
THYX_LOGO_NAME="logo.png"
THYX_LOGO_DST="${THYX_THEME_ROOT}/${THYX_LOGO_NAME}"

THYX_RESOURCE_PREFIX="/org/gnome/shell/theme"
THYX_BACKGROUND_RESOURCE="${THYX_THEME_ID}-background"

THYX_HOME="${HOME:-}"
THYX_CACHE_DIR="${XDG_CACHE_HOME:-${THYX_HOME}/.cache}/thyx"
THYX_TIMESTAMP="$(date +%Y%m%d-%H%M%S)"

THYX_AUTO_YES=0
THYX_LOG_FILE=""
THYX_LOG_PREFIX="thyx"
THYX_REPO_DIR=""
THYX_BUILD_DIR=""
THYX_SUDO=()
