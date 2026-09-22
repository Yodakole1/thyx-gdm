#!/usr/bin/env bash

THYX_REPO_MARKERS=(
  "theme.conf"
  "src/overrides.css.in"
  "scripts/lib/_constants.sh"
)

_thyx_validate_repo_tree() {
  local root="${1:?}"
  local marker

  for marker in "${THYX_REPO_MARKERS[@]}"; do
    [ -f "${root}/${marker}" ] || _thyx_die "not a thyx tree: ${root}/${marker} missing"
  done
}

_thyx_looks_like_repo() {
  local root="${1:?}"
  local marker

  for marker in "${THYX_REPO_MARKERS[@]}"; do
    [ -f "${root}/${marker}" ] || return 1
  done
}

_thyx_find_repo() {
  local script_dir="${1:?}"
  local scripts_parent cwd

  scripts_parent="$(cd "${script_dir}/.." && pwd -P)"
  cwd="$(pwd -P)"

  if _thyx_looks_like_repo "${scripts_parent}"; then
    _thyx_validate_repo_tree "${scripts_parent}"
    printf '%s\n' "${scripts_parent}"
    return 0
  fi

  if _thyx_looks_like_repo "${cwd}"; then
    _thyx_validate_repo_tree "${cwd}"
    printf '%s\n' "${cwd}"
    return 0
  fi

  _thyx_die "thyx tree not found from ${script_dir} or ${cwd}"
}
