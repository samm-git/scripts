#!/bin/bash

set -e
source /tmp/chroot-functions.sh
source /tmp/toolchain_util.sh

# A note on packages:
# The default PKGDIR is /usr/portage/packages
# To make sure things are uploaded to the correct places we split things up:
# crossdev build packages use ${PKGDIR}/crossdev (uploaded to SDK location)
# build deps in crossdev's sysroot use ${PKGDIR}/cross/${CHOST} (no upload)
# native toolchains use ${PKGDIR}/target/${BOARD} (uploaded to board location)

configure_target_root() {
    local board="$1"
    local cross_chost=$(get_board_chost "$1")
    local profile=$(get_board_profile "${board}")

    CBUILD="$(portageq envvar CBUILD)" \
        CHOST="${cross_chost}" \
        ROOT="/build/${board}" \
        SYSROOT="/build/${board}" \
        _configure_sysroot "${profile}"
}

build_target_toolchain() {
    local board="$1"
    local ROOT="/build/${board}"
    local SYSROOT="/usr/$(get_board_chost "${board}")"

    mkdir -p "${ROOT}/usr"
    cp -at "${ROOT}" "${SYSROOT}"/lib*
    cp -at "${ROOT}"/usr "${SYSROOT}"/usr/include "${SYSROOT}"/usr/lib*

    # --root is required because run_merge overrides ROOT=
    PORTAGE_CONFIGROOT="$ROOT" \
        run_merge -u --root="$ROOT" --sysroot="$ROOT" "${TOOLCHAIN_PKGS[@]}"

    export clst_myemergeopts="$( echo "$clst_myemergeopts" | sed -e 's/--newuse//' )"

    PORTAGE_CONFIGROOT="$ROOT" \
        run_merge --root="$ROOT" --sysroot="$ROOT" dev-lang/rust
}

configure_crossdev_overlay / /tmp/crossdev

# TODO: this is building the SDK packages and shouldn't actually be needed
for cross_chost in $(get_chost_list); do
    echo "Building cross toolchain for ${cross_chost}"
    PKGDIR="$(portageq envvar PKGDIR)/crossdev" \
        install_cross_toolchain "${cross_chost}" ${clst_myemergeopts}
    PKGDIR="$(portageq envvar PKGDIR)/cross/${cross_chost}" \
        install_cross_libs "${cross_chost}" ${clst_myemergeopts}
done

for board in $(get_board_list); do
    echo "Building native toolchain for ${board}"
    target_pkgdir="$(portageq envvar PKGDIR)/target/${board}"
    PKGDIR="${target_pkgdir}" configure_target_root "${board}"
    PKGDIR="${target_pkgdir}" build_target_toolchain "${board}"
done
