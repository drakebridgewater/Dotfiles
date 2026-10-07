# zsh tab-completion for the functions below lives in shell/zsh/completions/_siemens_utils
source "${DOTFILES_DIR:-$HOME/Dotfiles}/shell/common/logging"

function setup_build_env() {
    export PATH=/user/gitdet/bin:/user/icdet/bin:/usr/mgc/bin:/usr/bin/:/bin
    . /user/icdet/bin/detalias.sh
    . /user/pete/bin/env_init.sh
    export MGC_SERVER='/wv/mgc/mgc_server'
    export WG_SERVER='/wv/cal_wg_server'

    lserver set
}

function make_workareas() {
    # check if "ic" directory is in the iwa directory
    local IWA=${1}
    local BUILD_VCO=${2}
    local original_directory=$(pwd)

    if [ -z "$IWA" ]; then
        error "IWA variable is not set. Please provide the IWA path as the second argument."
        return 1
    fi

    IWA=$(realpath "$IWA") || return 1

    if [ ! -d "${IWA}/ic" ]; then
        error "'ic' directory not found in ${IWA}. Please run this script from the root of your work area."
        return 1
    fi
    if [ -z "$BUILD_VCO" ]; then
        error "BUILD_VCO variable is not set. Please provide the BUILD_VCO as the first argument."
        return 1
    fi

    local DIRECTORIES=("ic_superproj" "lv" "euv")

    for dir in "${DIRECTORIES[@]}"; do
        if [ -d "${IWA}/ic/${dir}" ]; then
          echo "Making work area for ic/${dir}/${BUILD_VCO}"
          cd "${IWA}/ic/${dir}" || exit
          # Check if the BUILD_VCO directory already exists
          if [ ! -d "${BUILD_VCO}" ]; then
              mkwa . . "$BUILD_VCO" -newdir || {
                  error "Failed to create work area for ${dir}/${BUILD_VCO}."
                  cd "${original_directory}" || exit
                  return 1
              }
          fi
        fi
    done
    
    # return to the original directory
    cd "${original_directory}" || exit
}

function remove_workarea() {
    # check if "ic" directory is in the iwa directory
    local current_dir
    current_dir=$(pwd)
    # if the current directory contains "ic" directory then it's the IWA
    if [ -d "${current_dir}/ic" ] && [ -z "$IWA" ]; then
        echo "IWA variable is not set, using current directory: ${current_dir}"
        IWA="${current_dir}"
    fi
    if [ ! -d "${IWA}/ic" ]; then
        error "'ic' directory not found in ${IWA}. Please run this script from the root of your work area."
        return 1
    fi
    if [ -z "$1" ]; then
      echo "Using environment variable BUILD_VCO of $BUILD_VCO"
    fi
    local BUILD_VCO=${1:-$BUILD_VCO}
    if [ -z "$BUILD_VCO" ]; then
        error "BUILD_VCO variable is not set and VCO is also not set."
        return 1
    fi

    local DIRECTORIES=("ic_superproj" "lv" "euv")
    for dir in "${DIRECTORIES[@]}"; do
        if [ -d "${IWA}/ic/${dir}/${BUILD_VCO}" ]; then
          echo "Removing work area for ic/${dir}/${BUILD_VCO}"
          echo "Are you sure? (y/n)"
          read -r answer
          if [ "$answer" != "y" ]; then
              echo "Aborting."
              return 1
          fi
          rm -rf "${IWA}/ic/${dir:?}/${BUILD_VCO}"
        fi
    done
    
    # return to the original directory
    cd "${current_dir}" || exit
}

function set_gmake_parallel() {
    echo "Setting gmake parallel"
    cpu_count=$(/home/cqi/toolsets/any/bin/systemInfo | grep 'total logical CPU units' | awk '{print $NF}')
    if [ -z "${cpu_count}" ]; then
        echo "cpu_count is empty, setting to 8"
        cpu_count=8
    fi

    if [ "${cpu_count}" -gt 60 ]; then
        echo "cpu_count is greater than 60, setting to 60"
        cpu_count=60
    fi

    export GMAKE_HDR_PARALLEL=-j${cpu_count}
    export GMAKE_LIB_PARALLEL=-j${cpu_count}
    export GMAKE_EXEC_PARALLEL=-j${cpu_count}
    export GMAKE_ICDEP_PARALLEL=-j
    export GMAKE_INC_PARALLEL=-j
}

function set_gmake_output_sync() {
    echo "Setting output sync..."
    requested_output_sync=$1
    if [ -z "${requested_output_sync}" ]; then
        requested_output_sync="target"
    fi
    # Options for --output-sync:
    #     none: This is the default: all output is sent directly as it is generated and no synchronization is performed.
    #     line: Output from each individual line of the recipe is grouped and printed as soon as that line is complete.
    #         If a recipe consists of multiple lines, they may be interspersed with lines from other recipes.
    #     target: Output from the entire recipe for each target is grouped and printed once the target is complete.
    #         This is the default if the --output-sync or -O option is given with no argument.
    #     recurse: Output from each recursive invocation of make is grouped and printed once the recursive invocation is complete.
    export MAKEFLAGS=--output-sync=${requested_output_sync}
}

# Set the make command and its arguments as an array so paths and arguments
# remain separate when the command is invoked from zsh.
get_make_cmd() {
    local BUILD_VCO=${1}
    local MAKE_CMD_BIN=gmake
    local DOCKERMAKE_ARG=""

    if echo "${BUILD_VCO}" | grep -Eq 'rhel9|rh9'; then
        echo "RHEL9 VCO detected, but no specific dockermake arguments needed at this time" >&2
    elif echo "${BUILD_VCO}" | grep -Eq 'rhel8|rh8'; then
        DOCKERMAKE_ARG="--aaw-rh8"
    else
        echo "No specific RHEL version detected in BUILD_VCO, defaulting to RHEL8 dockermake arguments" >&2
        DOCKERMAKE_ARG="--aaw-rh8"
    fi

    if echo "${BUILD_VCO}" | grep -Eq '^aaw'; then
        echo "AAW VCO detected, using dockermake" >&2
        export PATH=/user/calibre/container-tools/bin:$PATH
        RESOLVED_DOCKERMAKE=$(command -v dockermake)
        if [ -z "${RESOLVED_DOCKERMAKE}" ]; then
            error "dockermake command not found in PATH, but BUILD_VCO indicates an AAW build. Please ensure dockermake is installed and in the PATH."
            return 1
        fi
        MAKE_CMD_BIN="${RESOLVED_DOCKERMAKE}"
    else
        DOCKERMAKE_ARG=""
    fi

    MAKE_CMD=("${MAKE_CMD_BIN}")
    if [ -n "${DOCKERMAKE_ARG}" ]; then
      MAKE_CMD+=("${DOCKERMAKE_ARG}")
    fi
}

_verify_vco_host_setup() {
  # aok supports RHEL-family 8-10, aoj supports RHEL-family 7,
  # soa supports SLES, and aaw requires a Linux ARM host.
  if [ -z "${BUILD_VCO:-}" ]; then
        error "BUILD_VCO variable is not set."
        return 1
    fi

  local host_os host_arch host_id host_id_like host_version_id host_version_major
  host_os=$(uname -s) || return 1
  host_arch=$(uname -m) || return 1
  if [ "${host_os}" != "Linux" ]; then
    error "Unsupported host OS: ${host_os}"
    return 1
  fi

  if [ ! -r /etc/os-release ]; then
    error "Cannot determine Linux distribution: /etc/os-release is not readable."
    return 1
  fi

  local ID ID_LIKE VERSION_ID
  . /etc/os-release
  host_id=${ID:-}
  host_id_like=${ID_LIKE:-}
  host_version_id=${VERSION_ID:-}
  host_version_major=${host_version_id%%.*}

  local host_is_rhel_family=0
  case "${host_id}" in
    rhel|rocky|almalinux|centos|ol)
      host_is_rhel_family=1
      ;;
    *)
      case " ${host_id_like} " in
        *" rhel "*) host_is_rhel_family=1 ;;
      esac
      ;;
  esac

  case "${BUILD_VCO}" in
    aaw|aaw-*)
      case "${host_arch}" in
        arm|arm64|aarch64|armv[5-8]*|armv9*) ;;
        *)
          error "AAW VCO requires an ARM host; detected architecture: ${host_arch}."
          return 1
          ;;
      esac
      ;;
    aok|aok-*)
      if [ "${host_is_rhel_family}" -ne 1 ] ||
         ! case "${host_version_major}" in 8|9|10) true ;; *) false ;; esac; then
        error "AOK VCO requires a RHEL-family 8, 9, or 10 host; detected ${host_id} ${host_version_id}."
        return 1
      fi
      ;;
    aoj|aoj-*)
      if [ "${host_is_rhel_family}" -ne 1 ] || [ "${host_version_major}" != "7" ]; then
        error "AOJ VCO requires a RHEL-family 7 host; detected ${host_id} ${host_version_id}."
        return 1
      fi
      ;;
    soa|soa-*)
      case "${host_id}" in
        sles) ;;
        *)
          error "SOA VCO requires a SLES host; detected ${host_id} ${host_version_id}."
          return 1
          ;;
      esac
      ;;
    *)
      error "Unsupported BUILD_VCO '${BUILD_VCO}'. Expected an aok, aaw, aoj, or soa VCO."
      return 1
      ;;
    esac

  return 0
}

# Shared preamble for the mk_* helpers: resolves IWA, the build log and the VCO,
# then prepares MAKE_CMD and the gmake parallelism/output settings.
# Exposes the resolved VCO as MK_BUILD_VCO so the caller's BUILD_VCO is untouched.
_mk_setup() {
    source /user/icdet/bin/detalias.sh
    if [ -z "${BUILD_LOG_PATH}" ]; then
        error "BUILD_LOG_PATH variable is not set using stdout"
        BUILD_LOG_PATH="/dev/stdout"
    fi
    IWA=$(realpath "${IWA:-$(pwd)}")
    if [ ! -d "${IWA}/ic" ]; then
        error "'ic' directory not found in '${IWA}'. Please run this script from the root of your work area."
        return 1
    fi

    MK_BUILD_VCO=${BUILD_VCO:-$VCO}
    if [ -z "${MK_BUILD_VCO}" ]; then
        error "BUILD_VCO variable is not set and VCO is also not set."
        return 1
    fi

    get_make_cmd "${MK_BUILD_VCO}" || return 1
    set_gmake_parallel || return 1
    set_gmake_output_sync || return 1
}

# Run make targets in ${IWA}/ic/<subdir>/<vco>, appending output to the build log.
# Usage: _mk_run <subdir> <target> [target...]
_mk_run() {
    local subdir=$1
    shift
    (
        # pipefail so a make failure is not masked by tee's exit status.
        set -o pipefail
        cd "${IWA}/ic/${subdir}/${MK_BUILD_VCO}" || exit 1
        cglu || sglu || {
            error "cglu or sglu failed. Check the build log at ${BUILD_LOG_PATH} for details."
            exit 1
        }
        if [ "${BUILD_LOG_PATH}" = "/dev/stdout" ]; then
            "${MAKE_CMD[@]}" "$@"
        else
            "${MAKE_CMD[@]}" "$@" 2>&1 | tee -a "${BUILD_LOG_PATH}"
        fi
    )
}

# Fail if make exited non-zero, or if the build log recorded compiler errors.
# Usage: _mk_check_log <label> <make-exit-status>
_mk_check_log() {
    local label=$1
    local rc=${2:-0}
    if [ "${rc}" -ne 0 ]; then
        error "${label} failed (exit ${rc}). Check the build log at ${BUILD_LOG_PATH} for details."
        return 1
    fi
    if [ "${BUILD_LOG_PATH}" != "/dev/stdout" ] && grep -q -i "error: " "${BUILD_LOG_PATH}"; then
        error "${label} failed. Check the build log at ${BUILD_LOG_PATH} for details."
        return 1
    fi
}

function mk_imports() {
    echo "Starting mk_imports"
    _mk_setup || return 1
    _mk_run ic_superproj mk_imports imports
}


function make_cxx_warn_flags() {
    echo "Starting make_cxx_warn_flags"
    _mk_setup || return 1

    echo "Running mk_imports and imports to enable cxx_warn_flags generation"
    mk_imports || {
        error "imports failed. Check the build log at ${BUILD_LOG_PATH} for details."
        return 1
    }
    if [[ "${MK_BUILD_VCO}" == soa* ]]; then
        echo "Skipping cxx_warn_flags generation for VCO starting with 'soa'"
        return 0
    fi
    echo "Generating cxx_warn_flags"
    _mk_run lv cxx_warn_flags
}

function mk_ic_hdr() {
    echo "Starting mk_ic_hdr"
    _mk_setup || return 1

    echo "Current directory is $(pwd)" >> "${BUILD_LOG_PATH}"
    _mk_run lv ic_hdr
    _mk_check_log ic_hdr $?
}

function mk_euv() {
    echo "Starting mk_euv"
    _mk_setup || return 1

    if [ -d "${IWA}/ic/euv/${MK_BUILD_VCO}" ]; then
        echo "EUV directory found, building EUV headers"
        _mk_run euv lcl_lib
    else
        echo "EUV directory not found, skipping EUV build"
    fi
    _mk_check_log euv $?
}

function mk_lcl_libs() {
    echo "Starting mk_lcl_libs"
    _mk_setup || return 1

    _mk_run lv lcl_lib lcl_olib
    _mk_check_log lcl_libs $?
}

function mk_lcl_exec() {
    echo "Starting mk_lcl_exec"
    _mk_setup || return 1

    _mk_run lv lcl_exec
    _mk_check_log lcl_exec $?
}

function mk_ic_create_deps() {
    echo "Starting mk_ic_create_deps"
    _mk_setup || return 1

    _mk_run lv ic_create_deps
    _mk_check_log ic_create_deps $?
}

function mk_systests() {
    echo "Starting mk_systests"
    _mk_setup || return 1

    _mk_run lv systests
    _mk_check_log systests $?
}

function mk_lv_verify() {
    echo "Starting mk_lv_verify"
    _mk_setup || return 1

    _mk_run lv lv_verify
    _mk_check_log lv_verify $?
}


# Shared entry point for the top level build drivers: validates the arguments,
# exports the build environment, rotates the previous log and creates the work areas.
# Usage: _mk_build_start <caller-name> <IWA> <BUILD_VCO> <BUILD_LOG_PATH>
_mk_build_start() {
    local caller=$1
    IWA=${2}
    BUILD_VCO=${3}
    BUILD_LOG_PATH=${4:="/dev/stdout"}

    if [ -z "${IWA}" ] || [ -z "${BUILD_VCO}" ] ; then
        echo "Usage: ${caller} <IWA> <BUILD_VCO> <BUILD_LOG_PATH>"
        return 1
    fi
    _verify_vco_host_setup || return 1
    source /user/icdet/bin/detalias.sh
    IWA=$(realpath "${IWA}")
    export IWA
    export BUILD_VCO

    if [ "${BUILD_LOG_PATH}" != "/dev/stdout" ]; then
        touch "${BUILD_LOG_PATH}"
        BUILD_LOG_PATH=$(realpath "${BUILD_LOG_PATH}")
        # Move build log to RETRY_${BUILD_LOG_PATH} if it exists (force)
        if [ -f "${BUILD_LOG_PATH}" ]; then
            mv -f "${BUILD_LOG_PATH}" "RETRY_${BUILD_LOG_PATH}"
        fi
    fi
    export BUILD_LOG_PATH
    echo "Build log path: ${BUILD_LOG_PATH}"
    echo "Build VCO: ${BUILD_VCO}"
    echo "IWA: ${IWA}"

    echo "Starting build process..."
    setup_build_env

    echo "Making work areas..."
    make_workareas "${IWA}" "${BUILD_VCO}" || echo "Warning: make_workareas reported a failure, continuing."
}

function mk_calibre() {
    _mk_build_start mk_calibre "$@" || return 1

    echo "Building cxx_warn_flags, lcl_libs, and lcl_exec..."
    make_cxx_warn_flags || return 1
    mk_lcl_exec || return 1
    mk_ic_create_deps || return 1
}

function mk_calibre_with_systest() {
    _mk_build_start mk_calibre_with_systest "$@" || return 1

    echo "Building cxx_warn_flags, lcl_libs, and lcl_exec..."
    make_cxx_warn_flags || return 1
    mk_lcl_exec || return 1
    mk_ic_create_deps || return 1
    mk_systests || return 1
    mk_lv_verify || return 1
}

function mk_all() {
    _mk_build_start mk_all "$@" || return 1

    echo "Building cxx_warn_flags, ic_hdr, euv, and lcl_libs..."
    make_cxx_warn_flags || return 1
    mk_ic_hdr || return 1
    mk_euv || return 1
    mk_lcl_libs || return 1
}
