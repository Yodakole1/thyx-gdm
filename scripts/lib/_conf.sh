#!/usr/bin/env bash
# Reading theme.conf, and the colour arithmetic the stylesheet needs.

declare -A THYX_CONF=()

# Parses the INI. Keys are taken as-is; quotes and inline comments are stripped.
_thyx_conf_load() {
  local file="${1:?}"
  local line key value

  [ -f "${file}" ] || _thyx_die "config not found: ${file}"

  THYX_CONF=()

  while IFS= read -r line || [ -n "${line}" ]; do
    line="${line%$'\r'}"

    case "${line}" in
      ''|'#'*|';'*|'['*) continue ;;
      *'='*) ;;
      *) continue ;;
    esac

    key="${line%%=*}"
    value="${line#*=}"

    # trim whitespace around the key
    key="${key#"${key%%[![:space:]]*}"}"
    key="${key%"${key##*[![:space:]]}"}"

    # trim whitespace, then surrounding quotes, around the value
    value="${value#"${value%%[![:space:]]*}"}"
    value="${value%"${value##*[![:space:]]}"}"

    # A quoted value ends at its closing quote; whatever follows is a
    # trailing comment. Unquoted values are left whole, because the most
    # common one here is a colour and #rrggbb is not a comment.
    case "${value}" in
      '"'*)
        value="${value#\"}"
        value="${value%%\"*}"
        ;;
      "'"*)
        value="${value#\'}"
        value="${value%%\'*}"
        ;;
    esac

    [ -n "${key}" ] || continue
    THYX_CONF["${key}"]="${value}"
  done < "${file}"

  [ "${#THYX_CONF[@]}" -gt 0 ] || _thyx_die "no settings found in ${file}"
}

_thyx_conf_get() {
  local key="${1:?}"
  local fallback="${2-}"

  if [ -n "${THYX_CONF[${key}]+x}" ] && [ -n "${THYX_CONF[${key}]}" ]; then
    printf '%s\n' "${THYX_CONF[${key}]}"
    return 0
  fi

  printf '%s\n' "${fallback}"
}

# A setting that must be present and must be a colour.
_thyx_conf_color() {
  local key="${1:?}"
  local fallback="${2-}"
  local value

  value="$(_thyx_conf_get "${key}" "${fallback}")"
  [ -n "${value}" ] || _thyx_die "${key} is required in theme.conf"
  _thyx_assert_hex "${value}" "${key}"
  printf '%s\n' "${value}"
}

_thyx_conf_number() {
  local key="${1:?}"
  local fallback="${2:?}"
  local value

  value="$(_thyx_conf_get "${key}" "${fallback}")"
  case "${value}" in
    ''|*[!0-9.]*) _thyx_die "${key} must be a number, got: ${value}" ;;
  esac
  printf '%s\n' "${value}"
}

# Like _thyx_conf_number, but a leading minus is allowed. Tracking is the only
# setting that wants one: large type needs negative letter-spacing to stop the
# digits drifting apart.
_thyx_conf_signed() {
  local key="${1:?}"
  local fallback="${2:?}"
  local value body

  value="$(_thyx_conf_get "${key}" "${fallback}")"

  # One leading minus is allowed; what is left has to be a plain number, so
  # "1-2" and a bare "-" are both rejected.
  body="${value#-}"
  case "${body}" in
    ''|*[!0-9.]*) _thyx_die "${key} must be a number, got: ${value}" ;;
  esac

  printf '%s\n' "${value}"
}

_thyx_conf_bool() {
  local key="${1:?}"
  local fallback="${2:?}"
  local value

  value="$(_thyx_conf_get "${key}" "${fallback}")"
  case "${value}" in
    true|True|TRUE|yes|1) printf 'true\n' ;;
    false|False|FALSE|no|0) printf 'false\n' ;;
    *) _thyx_die "${key} must be true or false, got: ${value}" ;;
  esac
}

# Upstream Thyx sliced hex strings by index, so anything that was not exactly
# #rrggbb produced silent garbage. Here a bad colour stops the build.
_thyx_assert_hex() {
  local value="${1:?}"
  local key="${2:-colour}"

  case "${value}" in
    '#'[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]) return 0 ;;
    *) _thyx_die "${key} must be #rrggbb, got: ${value}" ;;
  esac
}

_thyx_hex_channel() {
  local hex="${1:?}"
  local offset="${2:?}"

  printf '%d\n' "0x${hex:${offset}:2}"
}

# "#f16f1c" -> "241, 111, 28"
_thyx_hex_triplet() {
  local hex="${1:?}"

  _thyx_assert_hex "${hex}"
  printf '%s, %s, %s\n' \
    "$(_thyx_hex_channel "${hex}" 1)" \
    "$(_thyx_hex_channel "${hex}" 3)" \
    "$(_thyx_hex_channel "${hex}" 5)"
}

# "#f16f1c" 0.25 -> "rgba(241, 111, 28, 0.25)"
_thyx_rgba() {
  local hex="${1:?}"
  local alpha="${2:?}"

  printf 'rgba(%s, %s)\n' "$(_thyx_hex_triplet "${hex}")" "${alpha}"
}

# Scales an alpha by a percentage and clamps to 1.0, e.g. 0.25 160 -> 0.40
_thyx_alpha_scale() {
  local alpha="${1:?}"
  local percent="${2:?}"

  awk -v a="${alpha}" -v p="${percent}" 'BEGIN {
    v = a * p / 100
    if (v > 1) v = 1
    if (v < 0) v = 0
    printf "%.3f\n", v
  }'
}

# Moves a colour toward black (percent < 100) or white (percent > 100).
_thyx_shade() {
  local hex="${1:?}"
  local percent="${2:?}"
  local r g b

  _thyx_assert_hex "${hex}"
  r="$(_thyx_hex_channel "${hex}" 1)"
  g="$(_thyx_hex_channel "${hex}" 3)"
  b="$(_thyx_hex_channel "${hex}" 5)"

  awk -v r="${r}" -v g="${g}" -v b="${b}" -v p="${percent}" 'BEGIN {
    f = p / 100
    split("", out)
    ch[1] = r; ch[2] = g; ch[3] = b
    for (i = 1; i <= 3; i++) {
      if (f <= 1) {
        v = ch[i] * f
      } else {
        v = ch[i] + (255 - ch[i]) * (f - 1)
      }
      if (v < 0) v = 0
      if (v > 255) v = 255
      out[i] = int(v + 0.5)
    }
    printf "#%02x%02x%02x\n", out[1], out[2], out[3]
  }'
}

# Substitutes @TOKEN@ placeholders using the THYX_TOKENS map. Unresolved
# tokens are an error rather than something that silently ships.
declare -A THYX_TOKENS=()

_thyx_render_template() {
  local template="${1:?}"
  local out="${2:?}"
  local key

  [ -f "${template}" ] || _thyx_die "template not found: ${template}"

  : > "${out}"

  {
    for key in "${!THYX_TOKENS[@]}"; do
      printf '%s\t%s\n' "${key}" "${THYX_TOKENS[${key}]}"
    done
  } > "${out}.tokens"

  awk -v tokfile="${out}.tokens" '
    BEGIN {
      FS = "\t"
      while ((getline line < tokfile) > 0) {
        split(line, parts, "\t")
        tok[parts[1]] = parts[2]
      }
      close(tokfile)
    }
    {
      line = $0
      out = ""
      while (match(line, /@[A-Za-z0-9_]+@/)) {
        name = substr(line, RSTART + 1, RLENGTH - 2)
        if (!(name in tok)) {
          printf "thyx: unresolved token @%s@ on line %d\n", name, NR > "/dev/stderr"
          exit 3
        }
        out = out substr(line, 1, RSTART - 1) tok[name]
        line = substr(line, RSTART + RLENGTH)
      }
      print out line
    }
  ' "${template}" > "${out}" || _thyx_die "template render failed: ${template}"

  rm -f -- "${out}.tokens"
}
