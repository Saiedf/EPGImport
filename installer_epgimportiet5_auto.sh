#!/bin/sh
#Script created by iet5
#
# ==========================================================
# SCRIPT : DOWNLOAD AND INSTALL ENIGMA2 PLUGIN
# Plugin   : EPGImportiet5
# Notes    : This installer automatically reads the latest
#            version from ver.txt and installs the matching
#            package without editing this script each release.
#            Old version removal is automatic with no prompt.
# ==========================================================
#
# Example run:
# wget -qO- "https://raw.githubusercontent.com/Saiedf/EPGImportiet5/main/installer_epgimportiet5_auto.sh?nocache=$(date +%s)" | /bin/sh
#
# Alternative:
# wget -O /tmp/installer_epgimportiet5_auto.sh "https://raw.githubusercontent.com/Saiedf/EPGImportiet5/main/installer_EPGImportiet5_auto.sh?nocache=$(date +%s)" && chmod 755 /tmp/installer_EPGImportiet5_auto.sh && /bin/sh /tmp/installer_EPGImportiet5_auto.sh
# ==========================================================

PACKAGE_NAME='enigma2-plugin-extensions-epgimportiet5'
LEGACY_PACKAGE_NAME='enigma2-plugin-extensions-epgimport'
PLUGIN_TITLE='EPGImport'
PLUGIN_FOLDER='EPGImport'

# Installation paths
# The plugin directory is cleaned/recreated during a clean install.
# /etc/epgimport is USER DATA: never delete, empty, overwrite or restore it.
# It is created only when it does not already exist.
PLUGIN_EXTENSIONS_PATH="/usr/lib/enigma2/python/Plugins/Extensions/$PLUGIN_FOLDER"
PLUGIN_SYSTEM_PATH="/usr/lib/enigma2/python/Plugins/SystemPlugins/$PLUGIN_FOLDER"
EPGIMPORT_CONFIG_DIR='/etc/epgimport'

REPO_USER='Saiedf'
REPO_NAME='EPGImport'
REPO_BRANCH='main'

# Adjust once only if your GitHub layout is different
VERSION_FILE_PATH='ver.txt'
RELEASES_DIR='Releases'

DEB_DM920_PY2=''
DEB_DM920_PY3=''
DEB_DREAMBOX_PY2=''
DEB_DREAMBOX_PY3=''

IPK_VTI_VUPLUS_PY2=''
IPK_VTI_VUPLUS_PY3=''
IPK_VTI_PY2=''
IPK_VTI_PY3=''
IPK_VTI_DEFAULT=''

IPK_OPENATV_VUPLUS_PY2=''
IPK_OPENATV_VUPLUS_PY3=''
IPK_OPENATV_DM920_PY2=''
IPK_OPENATV_DM920_PY3=''
IPK_OPENATV_PY2=''
IPK_OPENATV_PY3=''
IPK_OPENATV_DEFAULT=''

IPK_OPENSOURCE_VUPLUS_PY2=''
IPK_OPENSOURCE_VUPLUS_PY3=''
IPK_OPENSOURCE_DM920_PY2=''
IPK_OPENSOURCE_DM920_PY3=''
IPK_OPENSOURCE_PY2=''
IPK_OPENSOURCE_PY3=''
IPK_OPENSOURCE_DEFAULT=''

IPK_ARM64=''
IPK_ARMHF=''
IPK_MIPS32EL=''
IPK_GENERIC=''

say() {
    echo "$@"
}

have() {
    command -v "$1" >/dev/null 2>&1
}

to_lower() {
    echo "$1" | tr '[:upper:]' '[:lower:]'
}

trim() {
    printf '%s' "$1" | tr -d '\r' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

read_first_line() {
    for f in "$@"; do
        if [ -r "$f" ]; then
            sed -n '1p' "$f"
            return 0
        fi
    done
    return 1
}

download_to_stdout() {
    URL="$1"

    if have wget; then
        wget -qO- "$URL"
        return $?
    fi

    if have curl; then
        curl -fsL "$URL"
        return $?
    fi

    return 1
}

fetch_version() {
    VERSION_URL="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$REPO_BRANCH/$VERSION_FILE_PATH?nocache=$(date +%s)"
    VERSION_RAW=$(download_to_stdout "$VERSION_URL" 2>/dev/null | sed -n '1p')
    VERSION_RAW=$(trim "$VERSION_RAW")

    if [ -z "$VERSION_RAW" ]; then
        return 1
    fi

    # Accept versions like: 3.4, 3.4A, 3.4a, 3.4-beta, 3.4_1
    # Reject only unsafe characters, spaces, slashes, or empty values.
    case "$VERSION_RAW" in
        *[!0-9A-Za-z._-]*|.*|-*|_*|*/*|*\\*|*[[:space:]]*)
            return 1
            ;;
    esac

    printf '%s' "$VERSION_RAW"
    return 0
}

detect_image_type() {
    INFO=''
    [ -r /etc/issue ] && INFO="$INFO $(cat /etc/issue 2>/dev/null)"
    [ -r /etc/image-version ] && INFO="$INFO $(cat /etc/image-version 2>/dev/null)"
    [ -r /etc/os-release ] && INFO="$INFO $(cat /etc/os-release 2>/dev/null)"
    [ -r /etc/vtiversion.info ] && INFO="$INFO $(cat /etc/vtiversion.info 2>/dev/null)"
    [ -r /etc/issue.net ] && INFO="$INFO $(cat /etc/issue.net 2>/dev/null)"

    INFO=$(to_lower "$INFO")

    case "$INFO" in
        *dreambox*|*dreamos*|*oe2.5*|*oe2.6*) echo 'dreamos' ;;
        *vti*) echo 'vti' ;;
        *openatv*) echo 'openatv' ;;
        *openpli*) echo 'openpli' ;;
        *openspa*) echo 'openspa' ;;
        *openvix*) echo 'openvix' ;;
        *openbh*|*blackhole*) echo 'openbh' ;;
        *openhdf*) echo 'openhdf' ;;
        *openvision*) echo 'openvision' ;;
        *egami*) echo 'egami' ;;
        *teamblue*) echo 'teamblue' ;;
        *pure2*) echo 'pure2' ;;
        *)
            if have dpkg; then
                echo 'dreamos'
            else
                echo 'opensource'
            fi
            ;;
    esac
}

detect_box_model() {
    MODEL=''
    [ -z "$MODEL" ] && MODEL=$(read_first_line /proc/stb/info/boxtype)
    [ -z "$MODEL" ] && MODEL=$(read_first_line /proc/stb/info/model)

    if [ -z "$MODEL" ] && [ -r /proc/device-tree/model ]; then
        MODEL=$(tr -d '\000' < /proc/device-tree/model 2>/dev/null)
    fi

    [ -z "$MODEL" ] && MODEL=$(hostname 2>/dev/null)
    [ -z "$MODEL" ] && MODEL='unknown'

    echo "$MODEL" | tr ' ' '_' | tr '[:upper:]' '[:lower:]'
}

detect_device_family() {
    case "$BOX_MODEL" in
        dm920*|dm9*|dream*|dreambox*|one|two) echo 'dreambox' ;;
        vu*|solo*|uno*|zero*|duo*|ultimo*) echo 'vuplus' ;;
        *) echo 'generic' ;;
    esac
}

detect_arch() {
    ARCH=''

    if have dpkg; then
        ARCH=$(dpkg --print-architecture 2>/dev/null)
    fi

    if [ -z "$ARCH" ] && have opkg; then
        ARCH=$(opkg print-architecture 2>/dev/null | awk '{print $2}' | tail -n 1)
    fi

    [ -z "$ARCH" ] && ARCH=$(uname -m 2>/dev/null)
    [ -z "$ARCH" ] && ARCH='unknown'

    echo "$ARCH" | tr '[:upper:]' '[:lower:]'
}

detect_python_cmd() {
    if have python3; then
        echo 'python3'
        return 0
    fi
    if have python2; then
        echo 'python2'
        return 0
    fi
    if have python; then
        echo 'python'
        return 0
    fi
    echo ''
}

detect_python_series() {
    if [ -z "$PYTHON_CMD" ]; then
        echo 'unknown'
        return 0
    fi

    PY_MAJOR=$($PYTHON_CMD -c 'import sys; sys.stdout.write(str(sys.version_info[0]))' 2>/dev/null)
    case "$PY_MAJOR" in
        2) echo 'py2' ;;
        3) echo 'py3' ;;
        *) echo 'unknown' ;;
    esac
}

detect_python_version() {
    if [ -z "$PYTHON_CMD" ]; then
        echo 'not-found'
        return 0
    fi

    $PYTHON_CMD -c 'import sys; sys.stdout.write("%d.%d" % (sys.version_info[0], sys.version_info[1]))' 2>/dev/null
}

is_opensource_image() {
    case "$IMAGE_TYPE" in
        openatv|openpli|openspa|openvix|openbh|openhdf|openvision|egami|teamblue|pure2|opensource) return 0 ;;
        *) return 1 ;;
    esac
}

default_deb_file() {
    echo "${PACKAGE_NAME}_${PLUGIN_VERSION}_all.deb"
}

default_ipk_file() {
    echo "${PACKAGE_NAME}_${PLUGIN_VERSION}_all.ipk"
}

pick_deb_file() {
    if [ "$BOX_MODEL" = 'dm920' ] || [ "$BOX_MODEL" = 'dm920uhd' ]; then
        if [ "$PYTHON_SERIES" = 'py2' ] && [ -n "$DEB_DM920_PY2" ]; then
            echo "$DEB_DM920_PY2"
            return 0
        fi
        if [ "$PYTHON_SERIES" = 'py3' ] && [ -n "$DEB_DM920_PY3" ]; then
            echo "$DEB_DM920_PY3"
            return 0
        fi
    fi

    if [ "$PYTHON_SERIES" = 'py2' ] && [ -n "$DEB_DREAMBOX_PY2" ]; then
        echo "$DEB_DREAMBOX_PY2"
        return 0
    fi
    if [ "$PYTHON_SERIES" = 'py3' ] && [ -n "$DEB_DREAMBOX_PY3" ]; then
        echo "$DEB_DREAMBOX_PY3"
        return 0
    fi

    echo "$(default_deb_file)"
}

pick_ipk_file() {
    if [ "$IMAGE_TYPE" = 'vti' ]; then
        if [ "$DEVICE_FAMILY" = 'vuplus' ] && [ "$PYTHON_SERIES" = 'py2' ] && [ -n "$IPK_VTI_VUPLUS_PY2" ]; then
            echo "$IPK_VTI_VUPLUS_PY2"
            return 0
        fi
        if [ "$DEVICE_FAMILY" = 'vuplus' ] && [ "$PYTHON_SERIES" = 'py3' ] && [ -n "$IPK_VTI_VUPLUS_PY3" ]; then
            echo "$IPK_VTI_VUPLUS_PY3"
            return 0
        fi
        if [ "$PYTHON_SERIES" = 'py2' ] && [ -n "$IPK_VTI_PY2" ]; then
            echo "$IPK_VTI_PY2"
            return 0
        fi
        if [ "$PYTHON_SERIES" = 'py3' ] && [ -n "$IPK_VTI_PY3" ]; then
            echo "$IPK_VTI_PY3"
            return 0
        fi
        if [ -n "$IPK_VTI_DEFAULT" ]; then
            echo "$IPK_VTI_DEFAULT"
            return 0
        fi
    fi

    if [ "$IMAGE_TYPE" = 'openatv' ]; then
        if [ "$DEVICE_FAMILY" = 'vuplus' ] && [ "$PYTHON_SERIES" = 'py2' ] && [ -n "$IPK_OPENATV_VUPLUS_PY2" ]; then
            echo "$IPK_OPENATV_VUPLUS_PY2"
            return 0
        fi
        if [ "$DEVICE_FAMILY" = 'vuplus' ] && [ "$PYTHON_SERIES" = 'py3' ] && [ -n "$IPK_OPENATV_VUPLUS_PY3" ]; then
            echo "$IPK_OPENATV_VUPLUS_PY3"
            return 0
        fi
        if [ "$BOX_MODEL" = 'dm920' ] || [ "$BOX_MODEL" = 'dm920uhd' ]; then
            if [ "$PYTHON_SERIES" = 'py2' ] && [ -n "$IPK_OPENATV_DM920_PY2" ]; then
                echo "$IPK_OPENATV_DM920_PY2"
                return 0
            fi
            if [ "$PYTHON_SERIES" = 'py3' ] && [ -n "$IPK_OPENATV_DM920_PY3" ]; then
                echo "$IPK_OPENATV_DM920_PY3"
                return 0
            fi
        fi
        if [ "$PYTHON_SERIES" = 'py2' ] && [ -n "$IPK_OPENATV_PY2" ]; then
            echo "$IPK_OPENATV_PY2"
            return 0
        fi
        if [ "$PYTHON_SERIES" = 'py3' ] && [ -n "$IPK_OPENATV_PY3" ]; then
            echo "$IPK_OPENATV_PY3"
            return 0
        fi
        if [ -n "$IPK_OPENATV_DEFAULT" ]; then
            echo "$IPK_OPENATV_DEFAULT"
            return 0
        fi
    fi

    if is_opensource_image; then
        if [ "$DEVICE_FAMILY" = 'vuplus' ] && [ "$PYTHON_SERIES" = 'py2' ] && [ -n "$IPK_OPENSOURCE_VUPLUS_PY2" ]; then
            echo "$IPK_OPENSOURCE_VUPLUS_PY2"
            return 0
        fi
        if [ "$DEVICE_FAMILY" = 'vuplus' ] && [ "$PYTHON_SERIES" = 'py3' ] && [ -n "$IPK_OPENSOURCE_VUPLUS_PY3" ]; then
            echo "$IPK_OPENSOURCE_VUPLUS_PY3"
            return 0
        fi
        if [ "$BOX_MODEL" = 'dm920' ] || [ "$BOX_MODEL" = 'dm920uhd' ]; then
            if [ "$PYTHON_SERIES" = 'py2' ] && [ -n "$IPK_OPENSOURCE_DM920_PY2" ]; then
                echo "$IPK_OPENSOURCE_DM920_PY2"
                return 0
            fi
            if [ "$PYTHON_SERIES" = 'py3' ] && [ -n "$IPK_OPENSOURCE_DM920_PY3" ]; then
                echo "$IPK_OPENSOURCE_DM920_PY3"
                return 0
            fi
        fi
        if [ "$PYTHON_SERIES" = 'py2' ] && [ -n "$IPK_OPENSOURCE_PY2" ]; then
            echo "$IPK_OPENSOURCE_PY2"
            return 0
        fi
        if [ "$PYTHON_SERIES" = 'py3' ] && [ -n "$IPK_OPENSOURCE_PY3" ]; then
            echo "$IPK_OPENSOURCE_PY3"
            return 0
        fi
        if [ -n "$IPK_OPENSOURCE_DEFAULT" ]; then
            echo "$IPK_OPENSOURCE_DEFAULT"
            return 0
        fi
    fi

    case "$ARCH" in
        aarch64|arm64) [ -n "$IPK_ARM64" ] && { echo "$IPK_ARM64"; return 0; } ;;
        arm*|cortexa*) [ -n "$IPK_ARMHF" ] && { echo "$IPK_ARMHF"; return 0; } ;;
        mips*|mipsel|mips32el) [ -n "$IPK_MIPS32EL" ] && { echo "$IPK_MIPS32EL"; return 0; } ;;
    esac

    if [ -n "$IPK_GENERIC" ]; then
        echo "$IPK_GENERIC"
        return 0
    fi

    echo "$(default_ipk_file)"
}

build_url() {
    BASE_URL="https://raw.githubusercontent.com/$REPO_USER/$REPO_NAME/$REPO_BRANCH/$RELEASES_DIR"
    PKG_URL="$BASE_URL/$PKG_FILE?nocache=$(date +%s)"
}

has_deb_support() {
    if have dpkg || have apt-get || have apt; then
        return 0
    fi
    return 1
}

has_ipk_support() {
    if have opkg; then
        return 0
    fi
    return 1
}

check_installed_package_name() {
    CANDIDATE="$1"
    [ -z "$CANDIDATE" ] && return 1

    if have dpkg-query; then
        FOUND_VERSION=$(dpkg-query -W -f='${Status} ${Version}\n' "$CANDIDATE" 2>/dev/null | awk '/install ok installed/ {print $4}')
        if [ -n "$FOUND_VERSION" ]; then
            OLD_VERSION="$FOUND_VERSION"
            OLD_MANAGER='dpkg'
            OLD_PACKAGE_NAME="$CANDIDATE"
            return 0
        fi
    fi

    if have opkg; then
        FOUND_VERSION=$(opkg list-installed 2>/dev/null | awk -F ' - ' -v p="$CANDIDATE" '$1==p {print $2; exit}')
        if [ -n "$FOUND_VERSION" ]; then
            OLD_VERSION="$FOUND_VERSION"
            OLD_MANAGER='opkg'
            OLD_PACKAGE_NAME="$CANDIDATE"
            return 0
        fi
    fi

    return 1
}

detect_installed_package() {
    OLD_VERSION=''
    OLD_MANAGER=''
    OLD_PACKAGE_NAME=''

    check_installed_package_name "$PACKAGE_NAME" && return 0
    check_installed_package_name "$LEGACY_PACKAGE_NAME" && return 0

    return 1
}

find_old_plugin_paths() {
    FOUND_PATHS=''

    if [ -d "$PLUGIN_EXTENSIONS_PATH" ]; then
        FOUND_PATHS="$FOUND_PATHS $PLUGIN_EXTENSIONS_PATH"
    fi

    if [ -d "$PLUGIN_SYSTEM_PATH" ]; then
        FOUND_PATHS="$FOUND_PATHS $PLUGIN_SYSTEM_PATH"
    fi

    echo "$FOUND_PATHS" | sed 's/^ *//'
}

ensure_install_directories() {
    # Main plugin folder: recreate it empty before package extraction if needed.
    if [ ! -d "$PLUGIN_EXTENSIONS_PATH" ]; then
        mkdir -p "$PLUGIN_EXTENSIONS_PATH" || return 1
    fi

    # /etc/epgimport: never clean, delete, overwrite or restore.
    # Create it only when it is missing.
    if [ ! -d "$EPGIMPORT_CONFIG_DIR" ]; then
        mkdir -p "$EPGIMPORT_CONFIG_DIR" || return 1
        say "Created missing config directory: $EPGIMPORT_CONFIG_DIR"
    else
        say "Keeping existing config directory untouched: $EPGIMPORT_CONFIG_DIR"
    fi

    return 0
}

mask_package_config_files_before_remove() {
    # Protect /etc/epgimport from the OLD package manager metadata/scripts.
    # This function never reads/writes files inside /etc/epgimport itself.
    MASK_MANAGER="$1"
    MASK_PACKAGE="$2"
    MASK_BACKUP_DIR="/tmp/.epgimport-remove-mask-$$"
    MASK_INFO_DIR=''

    case "$MASK_MANAGER" in
        dpkg) MASK_INFO_DIR='/var/lib/dpkg/info' ;;
        opkg) MASK_INFO_DIR='/var/lib/opkg/info' ;;
        *) return 0 ;;
    esac

    [ -d "$MASK_INFO_DIR" ] || return 0
    mkdir -p "$MASK_BACKUP_DIR" || return 1
    MASK_CHANGED=0

    for MASK_SUFFIX in list conffiles; do
        MASK_FILE="$MASK_INFO_DIR/$MASK_PACKAGE.$MASK_SUFFIX"
        if [ -f "$MASK_FILE" ] && grep -q "^$EPGIMPORT_CONFIG_DIR\(/\|$\)" "$MASK_FILE" 2>/dev/null; then
            cp -p "$MASK_FILE" "$MASK_BACKUP_DIR/$MASK_PACKAGE.$MASK_SUFFIX" || return 1
            grep -v "^$EPGIMPORT_CONFIG_DIR\(/\|$\)" "$MASK_FILE" > "$MASK_FILE.ajtmp" || true
            mv "$MASK_FILE.ajtmp" "$MASK_FILE" || return 1
            MASK_CHANGED=1
        fi
    done

    # If old removal scripts explicitly touch /etc/epgimport, neutralize only
    # those scripts temporarily. Plugin files are still removed by dpkg/opkg
    # plus remove_old_plugin_paths().
    for MASK_SUFFIX in prerm postrm; do
        MASK_FILE="$MASK_INFO_DIR/$MASK_PACKAGE.$MASK_SUFFIX"
        if [ -f "$MASK_FILE" ] && grep -q "$EPGIMPORT_CONFIG_DIR" "$MASK_FILE" 2>/dev/null; then
            cp -p "$MASK_FILE" "$MASK_BACKUP_DIR/$MASK_PACKAGE.$MASK_SUFFIX" || return 1
            cat > "$MASK_FILE" <<'EOF_AJ_SAFE_REMOVE'
#!/bin/sh
# Temporarily neutralized by EPGImportiet5 installer.
# /etc/epgimport must remain untouched.
exit 0
EOF_AJ_SAFE_REMOVE
            chmod 755 "$MASK_FILE" || return 1
            MASK_CHANGED=1
        fi
    done

    MASK_INFO_DIR_ACTIVE="$MASK_INFO_DIR"
    MASK_PACKAGE_ACTIVE="$MASK_PACKAGE"
    MASK_CHANGED_ACTIVE="$MASK_CHANGED"
    return 0
}

restore_package_remove_metadata_on_failure() {
    [ "${MASK_CHANGED_ACTIVE:-0}" -eq 1 ] || return 0
    [ -d "${MASK_BACKUP_DIR:-}" ] || return 0
    [ -n "${MASK_INFO_DIR_ACTIVE:-}" ] || return 0
    [ -n "${MASK_PACKAGE_ACTIVE:-}" ] || return 0

    for MASK_SUFFIX in list conffiles prerm postrm; do
        MASK_SAVED="$MASK_BACKUP_DIR/$MASK_PACKAGE_ACTIVE.$MASK_SUFFIX"
        if [ -f "$MASK_SAVED" ]; then
            cp -p "$MASK_SAVED" "$MASK_INFO_DIR_ACTIVE/$MASK_PACKAGE_ACTIVE.$MASK_SUFFIX" >/dev/null 2>&1 || true
        fi
    done
}

cleanup_package_remove_mask() {
    [ -n "${MASK_BACKUP_DIR:-}" ] && rm -rf "$MASK_BACKUP_DIR" >/dev/null 2>&1
    MASK_CHANGED_ACTIVE=0
    MASK_INFO_DIR_ACTIVE=''
    MASK_PACKAGE_ACTIVE=''
}

sanitize_deb_config_payload() {
    # If the downloaded DEB contains /etc/epgimport files, remove those payload
    # entries from the temporary DEB so dpkg cannot overwrite existing user data.
    [ "$PKG_TYPE" = 'deb' ] || return 0

    if ! have dpkg-deb; then
        say 'dpkg-deb was not found; cannot guarantee protection of /etc/epgimport.'
        return 1
    fi

    if ! dpkg-deb -c "$MY_TMP_FILE" 2>/dev/null | awk '{print $NF}' | grep -q '^\./etc/epgimport\(/\|$\)'; then
        return 0
    fi

    SAFE_ROOT="/tmp/.epgimport-deb-safe-$$"
    SAFE_DEB="$MY_TMP_FILE.safe"
    rm -rf "$SAFE_ROOT" "$SAFE_DEB" >/dev/null 2>&1
    mkdir -p "$SAFE_ROOT" || return 1

    say "Protecting existing $EPGIMPORT_CONFIG_DIR from package payload..."

    dpkg-deb -R "$MY_TMP_FILE" "$SAFE_ROOT" >/dev/null 2>&1 || {
        rm -rf "$SAFE_ROOT" "$SAFE_DEB" >/dev/null 2>&1
        return 1
    }

    rm -rf "$SAFE_ROOT/etc/epgimport" >/dev/null 2>&1

    if [ -f "$SAFE_ROOT/DEBIAN/conffiles" ]; then
        grep -v "^$EPGIMPORT_CONFIG_DIR\(/\|$\)" "$SAFE_ROOT/DEBIAN/conffiles" > "$SAFE_ROOT/DEBIAN/conffiles.ajtmp" || true
        mv "$SAFE_ROOT/DEBIAN/conffiles.ajtmp" "$SAFE_ROOT/DEBIAN/conffiles"
    fi

    dpkg-deb -b "$SAFE_ROOT" "$SAFE_DEB" >/dev/null 2>&1 || {
        rm -rf "$SAFE_ROOT" "$SAFE_DEB" >/dev/null 2>&1
        return 1
    }

    mv "$SAFE_DEB" "$MY_TMP_FILE" || {
        rm -rf "$SAFE_ROOT" "$SAFE_DEB" >/dev/null 2>&1
        return 1
    }

    rm -rf "$SAFE_ROOT" >/dev/null 2>&1
    say "$EPGIMPORT_CONFIG_DIR payload excluded; existing contents will remain untouched."
    return 0
}

remove_installed_package() {
    REMOVED_BY_MANAGER=0
    PACKAGE_TO_REMOVE=''
    REMOVE_MANAGER=''

    if [ -z "$OLD_VERSION" ]; then
        return 0
    fi

    PACKAGE_TO_REMOVE="$OLD_PACKAGE_NAME"
    [ -z "$PACKAGE_TO_REMOVE" ] && PACKAGE_TO_REMOVE="$PACKAGE_NAME"

    if [ "$OLD_MANAGER" = 'dpkg' ] && have dpkg; then
        REMOVE_MANAGER='dpkg'
    elif [ "$OLD_MANAGER" = 'opkg' ] && have opkg; then
        REMOVE_MANAGER='opkg'
    elif have dpkg; then
        REMOVE_MANAGER='dpkg'
    elif have opkg; then
        REMOVE_MANAGER='opkg'
    else
        return 1
    fi

    mask_package_config_files_before_remove "$REMOVE_MANAGER" "$PACKAGE_TO_REMOVE" || {
        say "Failed to protect $EPGIMPORT_CONFIG_DIR before old package removal."
        cleanup_package_remove_mask
        return 1
    }

    if [ "$REMOVE_MANAGER" = 'dpkg' ]; then
        dpkg -r "$PACKAGE_TO_REMOVE"
        REMOVED_BY_MANAGER=$?
    else
        opkg remove "$PACKAGE_TO_REMOVE"
        REMOVED_BY_MANAGER=$?
    fi

    if [ $REMOVED_BY_MANAGER -ne 0 ]; then
        restore_package_remove_metadata_on_failure
        cleanup_package_remove_mask
        return $REMOVED_BY_MANAGER
    fi

    cleanup_package_remove_mask
    return 0
}

remove_old_plugin_paths() {
    PATH_REMOVE_RET=0
    OLD_PLUGIN_PATHS="$(find_old_plugin_paths)"

    for OLD_PLUGIN_PATH in $OLD_PLUGIN_PATHS; do
        if [ -d "$OLD_PLUGIN_PATH" ]; then
            say "Removing old plugin path: $OLD_PLUGIN_PATH"
            rm -rf "$OLD_PLUGIN_PATH"
            RET=$?
            if [ $RET -ne 0 ]; then
                PATH_REMOVE_RET=$RET
            fi
        fi
    done

    if [ $PATH_REMOVE_RET -ne 0 ]; then
        return $PATH_REMOVE_RET
    fi

    # Recreate only the main Extensions plugin folder.
    # /etc/epgimport is preserved; created only if missing.
    ensure_install_directories || return 1
    return 0
}

confirm_old_version_removal() {
    OLD_PLUGIN_PATHS="$(find_old_plugin_paths)"

    if [ -z "$OLD_VERSION" ] && [ -z "$OLD_PLUGIN_PATHS" ]; then
        ensure_install_directories || {
            say 'Failed to prepare installation directories.'
            exit 1
        }
        return 0
    fi

    say ''
    say '============================================================='
    say 'Old installed version or old plugin files detected.'
    if [ -n "$OLD_PACKAGE_NAME" ]; then
        say "Package : $OLD_PACKAGE_NAME"
    else
        say "Package : $PACKAGE_NAME"
    fi
    if [ -n "$OLD_VERSION" ]; then
        say "Version : $OLD_VERSION"
    else
        say 'Version : package manager entry not found'
    fi
    if [ -n "$OLD_PLUGIN_PATHS" ]; then
        say 'Old plugin paths found:'
        for OLD_PLUGIN_PATH in $OLD_PLUGIN_PATHS; do
            say " - $OLD_PLUGIN_PATH"
        done
    fi
    say '============================================================='
    say 'Removing old version automatically ...'

    remove_installed_package
    REMOVE_RET=$?
    if [ $REMOVE_RET -ne 0 ]; then
        say 'Failed to remove the old package. Installation aborted.'
        exit 1
    fi

    remove_old_plugin_paths
    REMOVE_PATH_RET=$?
    if [ $REMOVE_PATH_RET -ne 0 ]; then
        say 'Failed to remove old plugin files. Installation aborted.'
        exit 1
    fi

    return 0
}

download_package() {
    rm -f "$MY_TMP_FILE" >/dev/null 2>&1

    if have wget; then
        wget -T 20 -O "$MY_TMP_FILE" "$PKG_URL"
        return $?
    fi

    if have curl; then
        curl -L --connect-timeout 20 -o "$MY_TMP_FILE" "$PKG_URL"
        return $?
    fi

    say 'No downloader found. Please install wget or curl.'
    return 1
}

install_package() {
    if [ "$PKG_TYPE" = 'deb' ]; then
        if have dpkg; then
            dpkg -i --force-overwrite "$MY_TMP_FILE"
            INSTALL_RET=$?
            if have apt-get; then
                apt-get install -f -y >/dev/null 2>&1
            elif have apt; then
                apt install -f -y >/dev/null 2>&1
            fi
            return $INSTALL_RET
        fi

        if have apt-get; then
            apt-get install -y "$MY_TMP_FILE" >/dev/null 2>&1
            return $?
        fi

        if have apt; then
            apt install -y "$MY_TMP_FILE" >/dev/null 2>&1
            return $?
        fi

        return 1
    fi

    if have opkg; then
        opkg install --force-reinstall "$MY_TMP_FILE"
        return $?
    fi

    return 1
}

show_install_success_message() {
    MSG_TITLE="$PLUGIN_TITLE"

    say ''
    say '============================================================='
    say " $PLUGIN_TITLE has been installed successfully."
    say " Version: $PLUGIN_VERSION"
    say ' Enigma2 will restart now.'
    say '============================================================='
    say ''

    # OpenATV / OpenPLI / OpenVision / many OE images with WebInterface
    if have wget; then
        wget -qO- "http://127.0.0.1/web/message?text=$PLUGIN_TITLE%20version%20$PLUGIN_VERSION%20has%20been%20installed%20successfully.%0AEnigma2%20will%20restart%20now.&type=1&timeout=8" >/dev/null 2>&1
    elif have curl; then
        curl -fs "http://127.0.0.1/web/message?text=$PLUGIN_TITLE%20version%20$PLUGIN_VERSION%20has%20been%20installed%20successfully.%0AEnigma2%20will%20restart%20now.&type=1&timeout=8" >/dev/null 2>&1
    fi

    # DreamOS / Dreambox images when dbus notifications are available
    if have dbus-send; then
        dbus-send --system --type=method_call \
            --dest=org.freedesktop.Notifications \
            /org/freedesktop/Notifications \
            org.freedesktop.Notifications.Notify \
            string:"$MSG_TITLE" uint32:0 string:"" \
            string:"Installation completed" \
            string:"$PLUGIN_TITLE version $PLUGIN_VERSION has been installed successfully. Enigma2 will restart now." \
            array:string: dict:string:variant: int32:8000 >/dev/null 2>&1
    fi

    sleep 8
}

restart_enigma2() {
    if have systemctl; then
        sleep 2
        systemctl restart enigma2
    else
        init 4
        sleep 4 >/dev/null 2>&1
        init 3
    fi
}

IMAGE_TYPE=$(detect_image_type)
BOX_MODEL=$(detect_box_model)
DEVICE_FAMILY=$(detect_device_family)
ARCH=$(detect_arch)
PYTHON_CMD=$(detect_python_cmd)
PYTHON_SERIES=$(detect_python_series)
PYTHON_VERSION=$(detect_python_version)

PLUGIN_VERSION=$(fetch_version)
if [ $? -ne 0 ] || [ -z "$PLUGIN_VERSION" ]; then
    say ''
    say 'Failed to read version from ver.txt'
    say "URL: $VERSION_URL"
    exit 1
fi

[ -z "$IPK_VTI_DEFAULT" ] && IPK_VTI_DEFAULT="$(default_ipk_file)"
[ -z "$IPK_OPENATV_DEFAULT" ] && IPK_OPENATV_DEFAULT="$(default_ipk_file)"
[ -z "$IPK_OPENSOURCE_DEFAULT" ] && IPK_OPENSOURCE_DEFAULT="$(default_ipk_file)"

PKG_TYPE=''
PKG_FILE=''

DEB_CANDIDATE=$(pick_deb_file)
IPK_CANDIDATE=$(pick_ipk_file)

if [ "$IMAGE_TYPE" = 'dreamos' ]; then
    if has_deb_support && [ -n "$DEB_CANDIDATE" ]; then
        PKG_TYPE='deb'
        PKG_FILE="$DEB_CANDIDATE"
    elif has_ipk_support && [ -n "$IPK_CANDIDATE" ]; then
        PKG_TYPE='ipk'
        PKG_FILE="$IPK_CANDIDATE"
    fi
else
    if has_ipk_support && [ -n "$IPK_CANDIDATE" ]; then
        PKG_TYPE='ipk'
        PKG_FILE="$IPK_CANDIDATE"
    elif has_deb_support && [ -n "$DEB_CANDIDATE" ]; then
        PKG_TYPE='deb'
        PKG_FILE="$DEB_CANDIDATE"
    fi
fi

if [ -z "$PKG_FILE" ] || [ -z "$PKG_TYPE" ]; then
    say ''
    say 'No matching package was found for this image/device/Python combination.'
    say "Image         : $IMAGE_TYPE"
    say "Model         : $BOX_MODEL"
    say "Device family : $DEVICE_FAMILY"
    say "Architecture  : $ARCH"
    say "Python        : $PYTHON_VERSION"
    say "Version       : $PLUGIN_VERSION"
    exit 1
fi

build_url
MY_TMP_FILE="/tmp/$PKG_FILE"
detect_installed_package
MY_SEP='============================================================='

say ''
say '************************************************************'
say '**                         STARTED                        **'
say '************************************************************'
say "** Plugin        : $PLUGIN_TITLE"
say "** Package       : $PACKAGE_NAME"
say "** Version       : $PLUGIN_VERSION"
say "** Image         : $IMAGE_TYPE"
say "** Model         : $BOX_MODEL"
say "** Device family : $DEVICE_FAMILY"
say "** Architecture  : $ARCH"
say "** Python        : $PYTHON_VERSION"
say "** Package type  : $PKG_TYPE"
say "** Package file  : $PKG_FILE"
say '************************************************************'
say ''

confirm_old_version_removal

rm -f "$MY_TMP_FILE" >/dev/null 2>&1

say "$MY_SEP"
say "Downloading $PKG_FILE ..."
say "$PKG_URL"
say "$MY_SEP"
say ''

download_package
DOWNLOAD_RET=$?

if [ $DOWNLOAD_RET -eq 0 ] && [ -s "$MY_TMP_FILE" ]; then
    # Prevent a DEB payload from writing into /etc/epgimport.
    sanitize_deb_config_payload
    SANITIZE_RET=$?
    if [ $SANITIZE_RET -ne 0 ]; then
        say ''
        say "Failed to protect $EPGIMPORT_CONFIG_DIR. Installation aborted."
        exit 1
    fi

    ensure_install_directories
    DIR_RET=$?
    if [ $DIR_RET -ne 0 ]; then
        say ''
        say 'Failed to prepare installation directories.'
        exit 1
    fi

    say ''
    say "$MY_SEP"
    say 'Installation started'
    say "$MY_SEP"
    say ''

    install_package
    MY_RESULT=$?

    say ''
    say ''
    if [ $MY_RESULT -eq 0 ]; then
        say '>>>> SUCCESSFULLY INSTALLED <<<<'
        show_install_success_message
        say ''
        say '>>>> RESTARTING ENIGMA2    <<<<'
        restart_enigma2
    else
        say '>>>> INSTALLATION FAILED! <<<<'
    fi
    say ''
    say '**************************************************'
    say '**                   FINISHED                   **'
    say '**************************************************'
    say ''
    exit $MY_RESULT
else
    say ''
    say 'Download failed!'
    say "URL: $PKG_URL"
    exit 1
fi
