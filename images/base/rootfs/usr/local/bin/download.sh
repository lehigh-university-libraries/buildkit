#!/usr/bin/env bash
set -euo pipefail

ARGS=("$@")
PROGNAME=$(basename "$0")
readonly ARGS PROGNAME

function usage {
    cat <<-EOF
    usage: $PROGNAME options

    Downloads the file at the given url to the download cache folder.

    Does not re-download the file it already exists and matches the given checksum.

    Unpacks the file if the destination option is given.

    Download is placed in the directory ${DOWNLOAD_CACHE_DIRECTORY}.

    OPTIONS:
       -u --url           The url of the file to download.
       -c --sha256        The sha256 checksum to use to validate the download.
       -d --dest          The location to unpack file into (optional).
       -s --strip         Exclude the root folder when unpacking (optional, not supported with gzip or jar).
       -h --help          Show this help.
       -x --debug         Debug this script.

    Examples:
       $PROGNAME  \\
        --url https://github.com/just-containers/s6-overlay/releases/download/v1.22.1.0/s6-overlay-amd64.tar.gz
        --sha256 7f3aba1d803543dd1df3944d014f055112cf8dadf0a583c76dd5f46578ebe3c2 \\
        --dest /opt/s6-overlay
EOF
}

function cmdline {
    URL=
    CHECKSUM=
    DEST=
    STRIP=false
    REMOVE=()

    while (($# > 0)); do
        case "$1" in
        -u|--url|-c|--sha256|-d|--dest)
            if (($# < 2)); then
                echo "Option $1 requires a value" >&2
                exit 1
            fi
            case "$1" in
                -u|--url) URL=$2 ;;
                -c|--sha256) CHECKSUM=$2 ;;
                -d|--dest) DEST=$2 ;;
            esac
            shift 2
            ;;
        --url=*) URL=${1#*=}; shift ;;
        --sha256=*) CHECKSUM=${1#*=}; shift ;;
        --dest=*) DEST=${1#*=}; shift ;;
        -s|--strip)
            STRIP=true
            shift
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -x|--debug)
            set -x
            shift
            ;;
        --)
            shift
            REMOVE+=("$@")
            break
            ;;
        -*)
            echo "Invalid option: $1" >&2
            exit 1
            ;;
        *)
            REMOVE+=("$1")
            shift
            ;;
        esac
    done

    if [[ -z ${URL} || -z ${CHECKSUM} ]]; then
        echo "Missing one or more required options: --url --sha256" >&2
        exit 1
    fi

    readonly URL CHECKSUM DEST STRIP REMOVE

    return 0
}

function validate {
    local file=${1}
    local actual
    actual=$(sha256sum <"${file}")
    actual=${actual%% *}
    [[ "${actual}" == "${CHECKSUM}" ]]
}

function unpack {
    local file="${1}"
    local dest="${2}"
    local args=()
    local filename=
    mkdir -p "${dest}"
    if [[ "${STRIP}" == "true" ]]; then
        args+=("--strip-components" "1")
    fi
    filename=$(basename "${file}")
    case "${file}" in
    *.tar.xz | *.txz)
        tar -xf "${file}" -C "${dest}" "${args[@]}"
        ;;
    *.tar.gz | *.tgz)
        tar -xzf "${file}" -C "${dest}" "${args[@]}"
        ;;
    *.gz | *.gzip)
        gunzip "${file}" -f -c > "${dest}/${filename%.*}"
        ;;
    *.zip | *.war)
        if [[ "${STRIP}" == "true" ]]; then
            (
                local unpack_dir unpack_root
                local top_level=()
                unpack_dir=$(mktemp -d -t download-unpack.XXXXXXXXXX)
                trap 'rm -rf -- "${unpack_dir}"' EXIT HUP INT TERM
                unzip "${file}" -d "${unpack_dir}"
                mapfile -d '' top_level < <(find "${unpack_dir}" -mindepth 1 -maxdepth 1 -print0)
                if ((${#top_level[@]} != 1)) || [[ ! -d "${top_level[0]}" ]]; then
                    echo "ZIP strip requires exactly one top-level directory: ${file}" >&2
                    exit 1
                fi
                unpack_root=${top_level[0]}
                shopt -s dotglob nullglob
                mv "${unpack_root}"/* "${dest}"
            )
        else
            unzip "${file}" -d "${dest}"
        fi
        ;;
    *.jar)
        cp "${file}" "${dest}"
        ;;
    *)
        echo "Unable to unpack ${file} please update script to support additional formats." >&2
        exit 1
        ;;
    esac
    # Remove extraneous files.
    for i in "${REMOVE[@]}"; do
        rm -fr "${dest:?}/${i}"
    done
}

function main {
    local file
    cmdline "${ARGS[@]}"

    file="${DOWNLOAD_CACHE_DIRECTORY:?}/$(basename "${URL}")"
    # Remove the downloaded file if it exist and does not match the checksum so that it can be downloaded again.
    if [ -f "${file}" ] && ! validate "${file}"; then
        rm "${file}"
    fi
    wget -N -P "${DOWNLOAD_CACHE_DIRECTORY}" "${URL}"
    # Return non-zero if the checksum does not match the downloaded file.
    validate "${file}"
    if [[ -n "${DEST}" ]]; then
        unpack "${file}" "${DEST}"
    fi
}

if [[ "${DOWNLOAD_LIBRARY_ONLY:-false}" != "true" ]]; then
    main
fi
