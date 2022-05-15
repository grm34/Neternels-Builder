#!/usr/bin/env bash

# Copyright (c) 2021-2022 @grm34 Neternels Team
#
# Permission is hereby granted, free of charge, to any person
# obtaining a copy of this software and associated documentation
# files (the "Software"), to deal in the Software without restriction,
# including without limitation the rights to use, copy, modify, merge,
# publish, distribute, sublicense, and/or sell copies of the Software,
# and to permit persons to whom the Software is furnished to do so,
# subject to the following conditions:
#
# The above copyright notice and this permission notice shall be
# included in all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
# CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
# TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
# SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.


# SET COMPILER BUILD OPTIONS
# ==========================
# - export target variables (CFG)
# - append toolchains to the $PATH, export and verify
# - get current toolchain compiler options
# - get and export toolchain compiler version
# - get CROSS_COMPILE and CC (to handle Makefile)
# - set Link Time Optimization (LTO)
# - DEBUG MODE: display $PATH
#
_export_path_and_options() {
    if [[ $BUILDER == default ]]; then BUILDER=$(whoami); fi
    if [[ $HOST == default ]]; then HOST=$(uname -n); fi
    export KBUILD_BUILD_USER=$BUILDER
    export KBUILD_BUILD_HOST=$HOST
    export PLATFORM_VERSION ANDROID_MAJOR_VERSION
    case $COMPILER in
        "$PROTON_CLANG_NAME")
            export PATH=${PROTON_DIR}/bin:$PATH
            _check_toolchain_path "$PROTON_DIR"
            TC_OPTIONS=("${PROTON_CLANG_OPTIONS[@]}")
            _get_tc_version "$PROTON_VERSION"
            export TCVER=${tc_version##*/}
            cross=${PROTON_CLANG_OPTIONS[1]/CROSS_COMPILE=}
            ccross=${PROTON_CLANG_OPTIONS[3]/CC=}
            ;;
        "$EVA_GCC_NAME")
            export PATH=${GCC_ARM64_DIR}/bin:${GCC_ARM_DIR}/bin:$PATH
            _check_toolchain_path "$GCC_ARM64_DIR" "$GCC_ARM_DIR"
            TC_OPTIONS=("${EVA_GCC_OPTIONS[@]}")
            _get_tc_version "$GCC_ARM64_VERSION"
            export TCVER=${tc_version##*/}
            cross=${EVA_GCC_OPTIONS[1]/CROSS_COMPILE=}
            ccross=${EVA_GCC_OPTIONS[3]/CC=}
            ;;
        "$LOS_GCC_NAME")
            export PATH=${LOS_ARM64_DIR}/bin:${LOS_ARM_DIR}/bin:$PATH
            _check_toolchain_path "$LOS_ARM64_DIR" "$LOS_ARM_DIR"
            TC_OPTIONS=("${LOS_GCC_OPTIONS[@]}")
            _get_tc_version "$LOS_ARM64_VERSION"
            export TCVER=${tc_version##*/}
            cross=${LOS_GCC_OPTIONS[1]/CROSS_COMPILE=}
            ccross=${LOS_GCC_OPTIONS[3]/CC=}
            ;;
        "$PROTON_GCC_NAME")
            eva_path=${GCC_ARM64_DIR}/bin:${GCC_ARM_DIR}/bin
            export PATH=${PROTON_DIR}/bin:${eva_path}:$PATH
            _check_toolchain_path "$PROTON_DIR" "$GCC_ARM_DIR" \
                "$GCC_ARM64_DIR"
            TC_OPTIONS=("${PROTON_GCC_OPTIONS[@]}")
            _get_tc_version "$PROTON_VERSION"; v1=$tc_version
            _get_tc_version "$GCC_ARM64_VERSION"; v2=$tc_version
            export TCVER="${v1##*/} ${v2##*/}"
            cross=${PROTON_GCC_OPTIONS[1]/CROSS_COMPILE=}
            ccross=${PROTON_GCC_OPTIONS[3]/CC=}
    esac
    if [[ $LTO == True ]]
    then
        export LD_LIBRARY_PATH=${PROTON_DIR}/lib
        TC_OPTIONS[6]="LD=$LTO_LIBRARY"
    fi
    if [[ $DEBUG_MODE == True ]]
    then echo -e "\n${BLUE}PATH: ${NC}${YELLOW}${PATH}$NC"
    fi
}


# ENSURE $PATH HAS BEEN CORRECTLY SET
# ===================================
#  $? = toolchain DIR
#
_check_toolchain_path() {
    for toolchain_path in "$@"
    do
        if [[ $PATH != *${toolchain_path}/bin* ]]
        then _error "$MSG_ERR_PATH"; echo "$PATH"; _exit
        fi
    done
}


# GET TOOLCHAIN VERSION
# =====================
#  $1 = toolchain lib DIR
#
_get_tc_version() {
    tc_version=$(find "${DIR}/toolchains/$1" \
        -mindepth 1 -maxdepth 1 -type d | head -n 1)
}


# GET CROSS_COMPILE and CC FROM MAKEFILE
_get_and_display_cross_compile() {
    r1=("^CROSS_COMPILE\s.*?=.*" "CROSS_COMPILE\ ?=\ ${cross}")
    r2=("^CC\s.*=.*" "CC\ =\ ${ccross}\ -I${KERNEL_DIR}")
    c1=$(sed -n "/${r1[0]}/{p;}" "${KERNEL_DIR}/Makefile")
    c2=$(sed -n "/${r2[0]}/{p;}" "${KERNEL_DIR}/Makefile")
    if [[ -z $c1 ]]
    then _error "$MSG_ERR_CC"; _exit
    else echo "$c1"; echo "$c2"
    fi
}


# HANDLES Makefile CROSS_COMPILE and CC
# =====================================
# - display them on TERM so user can check before
# - ask to modify them in the kernel Makefile
# - edit the kernel Makefile (SED) while True
# - warn the user when they not seems correctly set
# - DEBUG MODE: display edited Makefile values
#
_handle_makefile_cross_compile() {
    _note "$MSG_NOTE_CC"
    _get_and_display_cross_compile
    _ask_for_edit_cross_compile
    if [[ $EDIT_CC != False ]]
    then
        _check sed -i "s|${r1[0]}|${r1[1]}|g" "${KERNEL_DIR}/Makefile"
        _check sed -i "s|${r2[0]}|${r2[1]}|g" "${KERNEL_DIR}/Makefile"
    fi
    mk=$(grep "${r1[0]}" "${KERNEL_DIR}/Makefile")
    if [[ -n ${mk##*"${cross/CROSS_COMPILE=/}"*} ]]
    then _error WARN "$MSG_WARN_CC"
    fi
    if [[ $DEBUG_MODE == True ]] && [[ $EDIT_CC != False ]]
    then
        echo -e "\n${BLUE}${MSG_DEBUG_CC}:$NC"
        _get_and_display_cross_compile
    fi
}


# RUN MAKE CLEAN
_make_clean() {
    _note "$MSG_NOTE_MAKE_CLEAN [${LINUX_VERSION}]..."
    _check unbuffer make -C "$KERNEL_DIR" clean 2>&1
}


# RUN MAKE MRPROPER
_make_mrproper() {
    _note "$MSG_NOTE_MRPROPER [${LINUX_VERSION}]..."
    _check unbuffer make -C "$KERNEL_DIR" mrproper 2>&1
}


# RUN MAKE DEFCONFIG
_make_defconfig() {
    _note "$MSG_NOTE_DEFCONFIG $DEFCONFIG [${LINUX_VERSION}]..."
    _check unbuffer make -C "$KERNEL_DIR" \
        O="$OUT_DIR" ARCH="$ARCH" "$DEFCONFIG" 2>&1
}


# RUN MAKE MENUCONFIG
_make_menuconfig() {
    _note "$MSG_NOTE_MENUCONFIG $DEFCONFIG [${LINUX_VERSION}]..."
    make -C "$KERNEL_DIR" O="$OUT_DIR" \
        ARCH="$ARCH" menuconfig "${OUT_DIR}/.config"
}


# SAVE DEFCONFIG from MENUCONFIG
# ==============================
# When an existing defconfig file is modified with menuconfig,
# the original defconfig will be saved as "example_defconfig_old"
#
_save_defconfig() {
    _note "$MSG_NOTE_SAVE $DEFCONFIG (arch/${ARCH}/configs)..."
    if [[ -f "${CONF_DIR}/$DEFCONFIG" ]]
    then
        _check cp \
            "${CONF_DIR}/$DEFCONFIG" \
            "${CONF_DIR}/${DEFCONFIG}_old"
    fi
    _check cp "${OUT_DIR}/.config" "${CONF_DIR}/$DEFCONFIG"
}


# RUN MAKE BUILD
# ==============
# - set Telegram HTML message
# - send build status on Telegram
# - CLANG: CROSS_COMPILE_ARM32 -> CROSS_COMPILE_COMPAT (linux > v4.2)
# - make new android kernel build
#
_make_build() {
    _note "${MSG_NOTE_MAKE}: ${KERNEL_NAME}..."
    _set_html_status_msg
    _send_start_build_status
    linuxversion="${LINUX_VERSION//.}"
    if [[ $(echo "${linuxversion:0:2} > 42" | bc) == 1 ]] && \
        [[ ${TC_OPTIONS[3]} == clang ]]
    then cflags=${cflags/CROSS_COMPILE_ARM32/CROSS_COMPILE_COMPAT}
    fi
    _check unbuffer make -C "$KERNEL_DIR" -j"$CORES" \
        O="$OUT_DIR" ARCH="$ARCH" "${TC_OPTIONS[*]}" 2>&1
}

