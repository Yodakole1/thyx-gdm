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
