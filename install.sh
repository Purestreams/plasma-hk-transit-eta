#!/usr/bin/env bash
# Install the pinned, verified public GitHub release for the current user.
set -euo pipefail

version='1.1.0'
plugin_id='com.example.hkbuseta'
archive_name="hong-kong-transit-departures-v${version}.plasmoid"
release_url="https://github.com/Purestreams/plasma-hk-transit-eta/releases/download/v${version}/${archive_name}"
expected_sha256='a6cf4848d80658292a4a8d008ab6c1d141a006e46d86f9bbc298d581a28fbff2'

for required in curl sha256sum kpackagetool6 mktemp; do
    if ! command -v "$required" >/dev/null 2>&1; then
        printf 'Error: required command not found: %s\n' "$required" >&2
        exit 1
    fi
done

data_root="${XDG_DATA_HOME:-${HOME}/.local/share}"
package_root="${data_root}/plasma/plasmoids"
temp_dir="$(mktemp -d "${TMPDIR:-/tmp}/hk-transit-install.XXXXXXXX")"
trap 'rm -rf -- "$temp_dir"' EXIT
archive_path="${temp_dir}/${archive_name}"

printf 'Downloading Hong Kong Transit Departures v%s...\n' "$version"
curl --fail --silent --show-error --location --retry 3 --retry-all-errors --proto '=https' --tlsv1.2 \
    --output "$archive_path" "$release_url"
if ! printf '%s  %s\n' "$expected_sha256" "$archive_path" | sha256sum --check --status; then
    printf 'Error: the downloaded package failed SHA-256 verification.\n' >&2
    exit 1
fi

if kpackagetool6 --type Plasma/Applet --packageroot "$package_root" --show "$plugin_id" >/dev/null 2>&1; then
    printf 'Updating the existing widget...\n'
    kpackagetool6 --type Plasma/Applet --packageroot "$package_root" --upgrade "$archive_path"
else
    printf 'Installing the widget...\n'
    mkdir -p "$package_root"
    kpackagetool6 --type Plasma/Applet --packageroot "$package_root" --install "$archive_path"
fi

printf '\nInstalled. In desktop edit mode, choose Add Widgets and search for Hong Kong Transit Departures.\n'
printf 'If the list does not refresh, restart the Plasma shell or log out and back in.\n'
