#!/bin/bash
#
# SPDX-FileCopyrightText: 2016 The CyanogenMod Project
# SPDX-FileCopyrightText: 2017-2024 The LineageOS Project
# SPDX-License-Identifier: Apache-2.0
#

set -e

DEVICE=peridot
VENDOR=xiaomi

# Load extract_utils and do some sanity checks
MY_DIR="${BASH_SOURCE%/*}"
if [[ ! -d "${MY_DIR}" ]]; then MY_DIR="${PWD}"; fi

ANDROID_ROOT="${MY_DIR}/../../.."

# If XML files don't have comments before the XML header, use this flag
# Can still be used with broken XML files by using blob_fixup
export TARGET_DISABLE_XML_FIXING=true

HELPER="${ANDROID_ROOT}/tools/extract-utils/extract_utils.sh"
if [ ! -f "${HELPER}" ]; then
    echo "Unable to find helper script at ${HELPER}"
    exit 1
fi
source "${HELPER}"

# Default to sanitizing the vendor folder before extraction
CLEAN_VENDOR=true

KANG=
SECTION=

while [ "${#}" -gt 0 ]; do
    case "${1}" in
        -n | --no-cleanup )
            CLEAN_VENDOR=false
            ;;
        -k | --kang )
            KANG="--kang"
            ;;
        -s | --section )
            SECTION="${2}"; shift
            CLEAN_VENDOR=false
            ;;
        * )
            SRC="${1}"
            ;;
    esac
    shift
done

if [ -z "${SRC}" ]; then
    SRC="adb"
fi

function blob_fixup() {
    case "${1}" in
        odm/etc/camera/enhance_motiontuning.xml|odm/etc/camera/motiontuning.xml|odm/etc/camera/night_motiontuning.xml)
            [ "$2" = "" ] && return 0
            sed -i 's/xml=version/xml version/g' "${2}"
            ;;
        odm/lib64/libwrapper_dlengine.so)
            [ "$2" = "" ] && return 0
            "${PATCHELF_0_17_2}" --add-needed "libwrapper_dlengine_shim.so" "${2}"
            ;;    
        system_ext/lib64/libwfdmmsrc_system.so)
            [ "$2" = "" ] && return 0
            grep -q "libgui_shim.so" "${2}" || "${PATCHELF}" --add-needed "libgui_shim.so" "${2}"
            ;;
        system_ext/lib64/libwfdnative.so)
            [ "$2" = "" ] && return 0
            ${PATCHELF} --remove-needed "android.hidl.base@1.0.so" "${2}"
            grep -q "libbinder_shim.so" "${2}" || "${PATCHELF}" --add-needed "libbinder_shim.so" "${2}"
            grep -q "libinput_shim.so" "${2}" || "${PATCHELF}" --add-needed "libinput_shim.so" "${2}"
            ;;
        vendor/bin/init.qcom.usb.sh)
            [ "$2" = "" ] && return 0
            sed -i 's/ro.product.marketname/ro.product.odm.marketname/g' "${2}"
            ;;
        vendor/lib64/libqcodec2_core.so)
	    [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libcodec2_shim.so" "${2}"
            ;;
        vendor/lib64/vendor.libdpmframework.so)
	    [ "$2" = "" ] && return 0
            "${PATCHELF}" --add-needed "libhidlbase_shim.so" "${2}"
            ;;
        vendor/etc/media_codecs.xml|vendor/etc/media_codecs_cliffs_v0.xml|vendor/etc/media_codecs_performance_cliffs_v0.xml)
            [ "$2" = "" ] && return 0
            sed -i -E '/media_codecs_(google_audio|google_c2|google_telephony|vendor_audio)/d' "${2}"
            ;;
        vendor/etc/seccomp_policy/atfwd@2.0.policy|vendor/etc/seccomp_policy/wfdhdcphalservice.policy|vendor/etc/seccomp_policy/gnss@2.0-qsap-location.policy|vendor/etc/seccomp_policy/qsap_sensors.policy|vendor/etc/seccomp_policy/qesdksec.policy)
            [ "$2" = "" ] && return 0
            grep -q "gettid: 1" "${2}" || echo -e "\ngettid: 1" >> "${2}"
            ;;
        *)
            return 1
            ;;
    esac

    return 0
}

function blob_fixup_dry() {
    blob_fixup "$1" ""
}

# Initialize the helper
setup_vendor "${DEVICE}" "${VENDOR}" "${ANDROID_ROOT}" false "${CLEAN_VENDOR}"

extract "${MY_DIR}/proprietary-files.txt" "${SRC}" "${KANG}" --section "${SECTION}"

"${MY_DIR}/setup-makefiles.sh"
