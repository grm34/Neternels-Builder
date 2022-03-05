#!/usr/bin/bash

#    Copyright (c) 2022 @grm34 Neternels Team
#
#    Permission is hereby granted, free of charge, to any person
#    obtaining a copy of this software and associated documentation
#    files (the "Software"), to deal in the Software without restriction,
#    including without limitation the rights to use, copy, modify, merge,
#    publish, distribute, sublicense, and/or sell copies of the Software,
#    and to permit persons to whom the Software is furnished to do so,
#    subject to the following conditions:
#
#    The above copyright notice and this permission notice shall be
#    included in all copies or substantial portions of the Software.
#
#    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
#    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
#    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
#    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
#    CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
#    TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
#    SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

# Telegram API URL
API="https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN}"


_send_msg() {
    curl --progress-bar -o /dev/null -fL \
        -X POST "${API}/sendMessage" \
        -d "parse_mode=html" \
        -d "chat_id=${TELEGRAM_CHAT_ID}" \
        -d "text=${1}" \
        | tee /dev/null
}


_send_file() {
    curl --progress-bar -o /dev/null -fL \
        -X POST "${API}/sendDocument" \
        -F "document=@${1}" \
        -F "caption=${2}" \
        -F "chat_id=${TELEGRAM_CHAT_ID}" \
        -F "disable_web_page_preview=true" \
        | tee /dev/null
}


_upload_build_on_telegram() {
    if [[ ${BUILD_STATUS} == True ]]; then
        _note "Uploading build on Telegram..."
        FILE="${BUILD_DIR}/${BUILD_NAME}-${DATE}-signed.zip"
        MD5=$(md5sum "${FILE}" | cut -d' ' -f1)
        _send_file "${FILE}" "MD5 Checksum: ${MD5}"
    fi
}


_send_msg_option() {
    if [[ ${TELEGRAM_CHAT_ID} ]] && [[ ${TELEGRAM_BOT_TOKEN} ]]; then
        _note "Sending message on Telegram...";
        _send_msg "${OPTARG}"
        _exit
    else
        _error "you must configure Telegram API settings first !"
        _exit
    fi
}


_send_file_option() {
    if [[ -f ${OPTARG} ]]; then
        if [[ ${TELEGRAM_CHAT_ID} ]] && [[ ${TELEGRAM_BOT_TOKEN} ]]; then
            _note "Uploading ${OPTARG} on Telegram..."
            _send_file "${OPTARG}"
            _exit
        else
            _error "you must configure Telegram API settings first !"
            _exit
        fi
    else
        _error "file not found: ${OPTARG} !"
        _exit
    fi
}
