#!/usr/bin/env bash
# Everything that touches GNOME Shell's greeter theme resource.

# GNOME Shell loads the greeter stylesheet out of a single gresource bundle.
# Thyx never edits that bundle in place: it rebuilds a complete copy of the
# stock one with our override block appended to gdm.css, then points the
# gdm-theme alternative at the copy. Upstream's file is never touched, so
# rolling back is a one-line update-alternatives call.

THYX_MARKER="/* thyx:begin */"
THYX_MARKER_END="/* thyx:end */"

_thyx_has_alternatives() {
  command -v update-alternatives >/dev/null 2>&1 &&
    update-alternatives --query "${THYX_ALTERNATIVE}" >/dev/null 2>&1
}

# The upstream bundle we build from -- never our own output, or the override
# block would stack up on every rebuild.
_thyx_stock_gresource() {
  local candidate=""

  if _thyx_has_alternatives; then
    candidate="$(
      update-alternatives --query "${THYX_ALTERNATIVE}" 2>/dev/null |
        awk -v mine="${THYX_GRESOURCE_DST}" '
          /^Alternative: / { alt = $2; next }
          /^Priority: / {
            if (alt != "" && alt != mine) print $2 "\t" alt
            alt = ""
          }
        ' | sort -rn | head -1 | cut -f2
    )"
  fi

  if [ -z "${candidate}" ] && [ -f "${THYX_GDM_BACKUP}" ]; then
    candidate="${THYX_GDM_BACKUP}"
  fi

  if [ -z "${candidate}" ] && [ -e "${THYX_GDM_LINK}" ]; then
    candidate="$(readlink -f -- "${THYX_GDM_LINK}")"
    [ "${candidate}" = "${THYX_GRESOURCE_DST}" ] && candidate=""
  fi

  if [ -z "${candidate}" ]; then
    local fallback="/usr/share/gnome-shell/gnome-shell-theme.gresource"
    [ -f "${fallback}" ] && candidate="${fallback}"
  fi

  [ -n "${candidate}" ] || _thyx_die "no stock gdm theme resource found; is gnome-shell installed?"
  [ -f "${candidate}" ] || _thyx_die "stock gdm theme resource is not a file: ${candidate}"

  printf '%s\n' "${candidate}"
}

_thyx_extract_stock() {
  local src="${1:?}"
  local dest="${2:?}"
  local path out count=0

  rm -rf -- "${dest}"
  mkdir -p -- "${dest}"

  while IFS= read -r path; do
    [ -n "${path}" ] || continue
    case "${path}" in
      "${THYX_RESOURCE_PREFIX}"/*) ;;
      *) _thyx_die "unexpected resource path in ${src}: ${path}" ;;
    esac

    out="${dest}/${path#"${THYX_RESOURCE_PREFIX}"/}"
    mkdir -p -- "$(dirname -- "${out}")"
    gresource extract "${src}" "${path}" > "${out}" ||
      _thyx_die "failed to extract ${path} from ${src}"
    count=$((count + 1))
  done < <(gresource list "${src}")

  [ "${count}" -gt 0 ] || _thyx_die "no resources extracted from ${src}"
  [ -f "${dest}/gdm.css" ] || _thyx_die "gdm.css missing from ${src}"

  printf '%s\n' "${count}"
}

# Strips a previously appended block, so building from an alreadythemed
# bundle still produces a clean sheet
_thyx_strip_previous_overrides() {
  local css="${1:?}"

  grep -qF "${THYX_MARKER}" "${css}" || return 0

  awk -v begin="${THYX_MARKER}" '
    index($0, begin) { skip = 1 }
    !skip { print }
  ' "${css}" > "${css}.clean"

  mv -f -- "${css}.clean" "${css}"
}

_thyx_image_tool() {
  if command -v ffmpeg >/dev/null 2>&1; then
    printf 'ffmpeg\n'
  elif command -v magick >/dev/null 2>&1; then
    printf 'magick\n'
  elif command -v convert >/dev/null 2>&1; then
    printf 'convert\n'
  else
    printf 'none\n'
  fi
}

_thyx_is_video() {
  case "${1,,}" in
    *.mp4|*.webm|*.mkv|*.mov|*.m4v|*.avi) return 0 ;;
    *) return 1 ;;
  esac
}

# Scales, blurs and dims the wallpaper once, at build time, so the greeter
# never pays for it. GDM cannot play video, so a clip contributes one frame
_thyx_prepare_background() {
  local src="${1:?}"
  local dest="${2:?}"
  local max_width="${3:?}"
  local blur="${4:?}"
  local dim="${5:?}"
  local quality="${6:?}"
  local tool sigma brightness filters

  [ -f "${src}" ] || _thyx_die "background not found: ${src}"

  tool="$(_thyx_image_tool)"

  if [ "${tool}" = "none" ]; then
    if _thyx_is_video "${src}"; then
      _thyx_die "background is a video and no ffmpeg is installed; point Background at an image or install ffmpeg"
    fi
    _thyx_warn "no ffmpeg or imagemagick: embedding ${src} unprocessed (Blur and Dim ignored)"
    cp -f -- "${src}" "${dest}"
    return 0
  fi

  sigma="$(awk -v b="${blur}" 'BEGIN { printf "%.2f", b * 40 }')"
  brightness="$(awk -v d="${dim}" 'BEGIN { printf "%.3f", -d }')"

  case "${tool}" in
    ffmpeg)
      filters="scale='min(${max_width},iw)':-2:flags=lanczos"
      awk -v b="${blur}" 'BEGIN { exit !(b > 0) }' &&
        filters="${filters},gblur=sigma=${sigma}"
      awk -v d="${dim}" 'BEGIN { exit !(d > 0) }' &&
        filters="${filters},eq=brightness=${brightness}"

      ffmpeg -nostdin -loglevel error -y \
        -i "${src}" \
        -vf "${filters}" \
        -frames:v 1 -q:v "${quality}" \
        "${dest}" || _thyx_die "ffmpeg could not process ${src}"
      ;;
    magick|convert)
      local args=("${src}" -resize "${max_width}x>")
      awk -v b="${blur}" 'BEGIN { exit !(b > 0) }' &&
        args+=(-blur "0x${sigma}")
      awk -v d="${dim}" 'BEGIN { exit !(d > 0) }' &&
        args+=(-brightness-contrast "$(awk -v d="${dim}" 'BEGIN { printf "%d", -d * 100 }')x0")
      args+=(-quality 92 "${dest}")

      "${tool}" "${args[@]}" || _thyx_die "${tool} could not process ${src}"
      ;;
  esac

  [ -s "${dest}" ] || _thyx_die "background processing produced an empty file"
}

_thyx_write_gresource_xml() {
  local dir="${1:?}"
  local out="${2:?}"
  local rel

  {
    printf '<?xml version="1.0" encoding="UTF-8"?>\n'
    printf '<gresources>\n'
    printf '  <gresource prefix="%s">\n' "${THYX_RESOURCE_PREFIX}"

    while IFS= read -r rel; do
      # Compressing the stylesheets is worth it; the images are already packed.
      case "${rel}" in
        *.css|*.svg)
          printf '    <file compressed="true">%s</file>\n' "${rel}"
          ;;
        *)
          printf '    <file>%s</file>\n' "${rel}"
          ;;
      esac
    done < <(cd "${dir}" && find . -type f ! -name '*.gresource.xml' -printf '%P\n' | LC_ALL=C sort)

    printf '  </gresource>\n'
    printf '</gresources>\n'
  } > "${out}"
}

_thyx_compile_gresource() {
  local dir="${1:?}"
  local xml="${2:?}"
  local out="${3:?}"

  glib-compile-resources \
    --sourcedir="${dir}" \
    --target="${out}" \
    "${xml}" || _thyx_die "glib-compile-resources failed"

  [ -s "${out}" ] || _thyx_die "compiled resource is empty: ${out}"

  # A bundle the shell cannot read is worse than no theme at all. The listing
  # is taken once rather than piped into `grep -q`, which would close the pipe
  # early and trip pipefail whenever gresource had not finished writing.
  local listing
  listing="$(gresource list "${out}" 2>/dev/null)" ||
    _thyx_die "compiled resource is not readable: ${out}"

  grep -qx "${THYX_RESOURCE_PREFIX}/gdm.css" <<< "${listing}" ||
    _thyx_die "compiled resource has no gdm.css"
}

# --- activation ------------------------------------------------------------
#
# Two ways in, picked by what the distro offers:
#
#   1. update-alternatives, on Debian and Ubuntu, where gdm-theme.gresource is
#      already an alternatives link. Registering at a higher priority than
#      Yaru's 15 is a reversible, packaging-friendly switch.
#   2. Otherwise the stock file is moved aside once, to a backup the
#      uninstaller restores, and replaced.

_thyx_activation_method() {
  if _thyx_has_alternatives; then
    printf 'alternatives\n'
  else
    printf 'replace\n'
  fi
}

_thyx_target_file() {
  if [ -e "${THYX_GDM_LINK}" ] || [ -L "${THYX_GDM_LINK}" ]; then
    printf '%s\n' "${THYX_GDM_LINK}"
  else
    printf '%s\n' "/usr/share/gnome-shell/gnome-shell-theme.gresource"
  fi
}

_thyx_activate() {
  local gresource="${1:?}"

  case "$(_thyx_activation_method)" in
    alternatives)
      _thyx_run update-alternatives --install \
        "${THYX_GDM_LINK}" "${THYX_ALTERNATIVE}" \
        "${gresource}" "${THYX_ALTERNATIVE_PRIORITY}" ||
        _thyx_die "could not register the ${THYX_ALTERNATIVE} alternative"

      _thyx_run update-alternatives --set "${THYX_ALTERNATIVE}" "${gresource}" ||
        _thyx_die "could not select the thyx alternative"
      ;;
    replace)
      local target
      target="$(_thyx_target_file)"

      if [ ! -e "${THYX_GDM_BACKUP}" ] && [ -e "${target}" ]; then
        _thyx_run cp -a -- "${target}" "${THYX_GDM_BACKUP}" ||
          _thyx_die "could not back up ${target}"
      fi

      # Written beside the target and renamed, so the greeter never sees a
      # half-copied bundle.
      _thyx_run cp -f -- "${gresource}" "${target}.thyx-new" ||
        _thyx_die "could not stage ${target}"
      _thyx_run mv -f -- "${target}.thyx-new" "${target}" ||
        _thyx_die "could not activate ${target}"
      ;;
  esac
}

_thyx_deactivate() {
  case "$(_thyx_activation_method)" in
    alternatives)
      if update-alternatives --query "${THYX_ALTERNATIVE}" 2>/dev/null |
           grep -qxF "Alternative: ${THYX_GRESOURCE_DST}"; then
        _thyx_run update-alternatives --remove \
          "${THYX_ALTERNATIVE}" "${THYX_GRESOURCE_DST}" ||
          _thyx_die "could not remove the thyx alternative"
      fi
      ;;
    replace)
      local target
      target="$(_thyx_target_file)"

      if [ -e "${THYX_GDM_BACKUP}" ]; then
        _thyx_run mv -f -- "${THYX_GDM_BACKUP}" "${target}" ||
          _thyx_die "could not restore ${target} from ${THYX_GDM_BACKUP}"
      fi
      ;;
  esac
}

# What the greeter will actually load, whichever method was used.
_thyx_active_gresource() {
  local target
  target="$(_thyx_target_file)"
  [ -e "${target}" ] || return 1
  readlink -f -- "${target}"
}

# --- greeter gsettings -----------------------------------------------------
#
# Writing /etc/dconf/db/gdm.d/95-thyx only does something if the greeter's
# dconf profile names a system database. Ubuntu's does not, so Thyx ensures
# one the same way gdm-config does: through /etc/dconf/profile/gdm, an
# admin-owned override of the packaged profile.
#
# Three outcomes, recorded in the install state so uninstall can undo exactly
# what was done and nothing more:
#
#   none      the profile already had a system-db; nothing was written
#   created   Thyx wrote the profile; uninstall deletes it
#   edited    something else owned the profile; Thyx added one line to it and
#             kept the original, which uninstall puts back

_thyx_dconf_profile_has_system_db() {
  local file="${1:?}"

  [ -f "${file}" ] || return 1
  grep -qE "^[[:space:]]*system-db:${THYX_DCONF_SYSTEM_DB}[[:space:]]*$" "${file}"
}

# The profile the greeter resolves today: the admin copy if there is one, the
# packaged one otherwise.
_thyx_dconf_profile_effective() {
  if [ -f "${THYX_DCONF_PROFILE_FILE}" ]; then
    printf '%s\n' "${THYX_DCONF_PROFILE_FILE}"
  elif [ -f "${THYX_DCONF_PROFILE_SRC}" ]; then
    printf '%s\n' "${THYX_DCONF_PROFILE_SRC}"
  fi
}

# Copies a profile with `system-db:gdm` inserted directly below the user-db
# line, which is where dconf wants it: the first line must stay writable, and
# a system-db must outrank the distro's file-db to be able to override it.
_thyx_dconf_profile_render() {
  local src="${1:-}"

  printf '# This profile is managed by thyx.\n'
  printf '# It shadows %s, which lists no system\n' "${THYX_DCONF_PROFILE_SRC}"
  printf '# database and so leaves /etc/dconf/db/%s.d unread. Uninstalling\n' "${THYX_DCONF_SYSTEM_DB}"
  printf '# thyx removes this file again.\n'

  if [ -n "${src}" ] && [ -f "${src}" ]; then
    awk -v db="system-db:${THYX_DCONF_SYSTEM_DB}" '
      /^[[:space:]]*#/ { print; next }
      { print }
      !done && /^[[:space:]]*(user-db|service-db):/ { print db; done = 1 }
      END { if (!done) print db }
    ' "${src}"
  else
    printf 'user-db:user\n'
    printf 'system-db:%s\n' "${THYX_DCONF_SYSTEM_DB}"
  fi
}

_thyx_dconf_profile_is_ours() {
  [ -f "${THYX_DCONF_PROFILE_FILE}" ] &&
    grep -q "^# This profile is managed by thyx" "${THYX_DCONF_PROFILE_FILE}"
}

# Returns the outcome on stdout: none, created or edited.
#
# Re-rendered from the packaged profile on every install, not just the first,
# so that if a gdm3 upgrade ever changes its own profile our shadow copy picks
# the change up instead of pinning the greeter to an old database list.
_thyx_dconf_profile_ensure() {
  local outcome tmp

  if _thyx_dconf_profile_is_ours; then
    outcome="created"
    tmp="$(mktemp)"
    _thyx_dconf_profile_render "${THYX_DCONF_PROFILE_SRC}" > "${tmp}"
  elif [ -f "${THYX_DCONF_PROFILE_FILE}" ]; then
    # Somebody else owns this file -- gdm-config writes one too. Leave it be
    # if it already reaches our database; otherwise add the one line it needs
    # and keep the original for uninstall.
    if _thyx_dconf_profile_has_system_db "${THYX_DCONF_PROFILE_FILE}"; then
      printf 'none\n'
      return 0
    fi
    outcome="edited"
    tmp="$(mktemp)"
    _thyx_run mkdir -p -- "${THYX_STATE_DIR}"
    _thyx_run cp -a -- "${THYX_DCONF_PROFILE_FILE}" "${THYX_DCONF_PROFILE_BACKUP}"
    _thyx_dconf_profile_render "${THYX_DCONF_PROFILE_FILE}" > "${tmp}"
  elif _thyx_dconf_profile_has_system_db "${THYX_DCONF_PROFILE_SRC}"; then
    # A distro whose own profile already reads /etc/dconf/db/gdm.d. Nothing
    # to shadow, and shadowing it anyway would only add a file to go stale.
    printf 'none\n'
    return 0
  else
    outcome="created"
    tmp="$(mktemp)"
    _thyx_dconf_profile_render "${THYX_DCONF_PROFILE_SRC}" > "${tmp}"
  fi

  if [ -f "${THYX_DCONF_PROFILE_FILE}" ] &&
     cmp -s "${tmp}" "${THYX_DCONF_PROFILE_FILE}"; then
    rm -f -- "${tmp}"
    printf '%s\n' "${outcome}"
    return 0
  fi

  _thyx_run mkdir -p -- "${THYX_DCONF_PROFILE_DIR}"
  _thyx_run install -m 0644 -- "${tmp}" "${THYX_DCONF_PROFILE_FILE}"
  rm -f -- "${tmp}"

  printf '%s\n' "${outcome}"
}

# Puts back whatever was there before, guided by the recorded outcome.
_thyx_dconf_profile_restore() {
  local outcome="${1:-none}"

  case "${outcome}" in
    created)
      _thyx_remove_one "${THYX_DCONF_PROFILE_FILE}"
      ;;
    edited)
      if [ -f "${THYX_DCONF_PROFILE_BACKUP}" ]; then
        _thyx_run install -m 0644 -- \
          "${THYX_DCONF_PROFILE_BACKUP}" "${THYX_DCONF_PROFILE_FILE}"
      else
        _thyx_warn "no profile backup at ${THYX_DCONF_PROFILE_BACKUP}; leaving ${THYX_DCONF_PROFILE_FILE} alone"
      fi
      ;;
    *)
      ;;
  esac
}

# Reads a key back the way the greeter will read it, which is the only proof
# that the keyfile and the profile actually line up.
_thyx_dconf_greeter_read() {
  local key="${1:?}"

  command -v dconf >/dev/null 2>&1 || return 1
  DCONF_PROFILE="${THYX_DCONF_SYSTEM_DB}" dconf read "${key}" 2>/dev/null
}
