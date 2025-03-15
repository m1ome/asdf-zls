#!/usr/bin/env bash

set -euo pipefail

# TODO: Ensure this is the correct GitHub homepage where releases can be downloaded for zls.
GH_REPO="https://github.com/zigtools/zls"
TOOL_NAME="zls"
TOOL_TEST="zls --version"

fail() {
	echo -e "asdf-$TOOL_NAME: $*"
	exit 1
}

curl_opts=(-fsSL)

# NOTE: You might want to remove this if zls is not hosted on GitHub releases.
if [ -n "${GITHUB_API_TOKEN:-}" ]; then
	curl_opts=("${curl_opts[@]}" -H "Authorization: token $GITHUB_API_TOKEN")
fi

sort_versions() {
	sed 'h; s/[+-]/./g; s/.p\([[:digit:]]\)/.z\1/; s/$/.z/; G; s/\n/ /' |
		LC_ALL=C sort -t. -k 1,1 -k 2,2n -k 3,3n -k 4,4n -k 5,5n | awk '{print $2}'
}

list_github_tags() {
	git ls-remote --tags --refs "$GH_REPO" |
		grep -o 'refs/tags/.*' | cut -d/ -f3- |
		sed 's/^v//'
}

list_all_versions() {
	list_github_tags
}

download_release() {
	local version filename url platform architecture
	version="$1"
	filename="$2"

	case "$OSTYPE" in
	darwin*) platform="macos" ;;
	freebsd*) platform="freebsd" ;;
	linux*) platform="linux" ;;
	*) fail "Unsupported platform" ;;
	esac

	case "$(uname -m)" in
	aarch64* | arm64) architecture="aarch64" ;;
	armv7*) architecture="armv7a" ;;
	i686*) architecture="i386" ;;
	riscv64*) architecture="riscv64" ;;
	x86_64*) architecture="x86_64" ;;
	*) fail "Unsupported architecture" ;;
	esac

	url="$GH_REPO/releases/download/${version}/zls-${architecture}-${platform}.tar.xz"
	echo "* Downloading $TOOL_NAME release $version from: $url"
	curl "${curl_opts[@]}" -H "Accept: application/octet-stream" -o "$filename" "$url" || fail "Could not download $url"
}

install_version() {
	local install_type="$1"
	local version="$2"
	local install_path="${3%/bin}/bin"

	if [ "$install_type" != "version" ]; then
		fail "asdf-$TOOL_NAME supports release installs only"
	fi

	(
		mkdir -p "$install_path"

		cp -r "$ASDF_DOWNLOAD_PATH"/zls "$install_path"
		chmod +x "$install_path"/zls

		local tool_cmd
		tool_cmd="$(echo "$TOOL_TEST" | cut -d' ' -f1)"
		test -x "$install_path/$tool_cmd" || fail "Expected $install_path/$tool_cmd to be executable."

		echo "$TOOL_NAME $version installation was successful!"
	) || (
		rm -rf "$install_path"
		fail "An error occurred while installing $TOOL_NAME $version."
	)
}
