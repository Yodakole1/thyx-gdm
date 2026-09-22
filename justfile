alias b := build
alias p := preview
alias i := install
alias u := uninstall
alias s := shell

# build the theme from theme.conf
build:
	bash ./scripts/build

# build every preset, to check they all still render
build-all:
	#!/usr/bin/env bash
	set -euo pipefail
	for preset in presets/*.conf; do
		echo "==> ${preset}"
		bash ./scripts/build --config "${preset}" --quiet
	done

# render the greeter and open the screenshot
preview:
	bash ./scripts/preview

# screenshot every preset into build/
preview-all:
	#!/usr/bin/env bash
	set -euo pipefail
	for preset in presets/*.conf; do
		name="$(basename "${preset}" .conf)"
		echo "==> ${name}"
		bash ./scripts/preview --config "${preset}" --out "build/preview-${name}.png" --no-open
	done

install:
	bash ./scripts/install

uninstall:
	bash ./scripts/uninstall

# shellcheck everything
@shell:
	shellcheck -x ./scripts/build ./scripts/install ./scripts/uninstall ./scripts/preview

# clean build artefacts
clean:
	rm -rf build
