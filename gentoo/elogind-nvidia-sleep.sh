#!/bin/sh
# NVIDIA suspend/resume hook for elogind
# Install to: /etc/elogind/system-sleep/nvidia-sleep.sh
# Replaces: systemd nvidia-suspend.service / nvidia-resume.service
#
# NVIDIA only provides systemd service files for sleep — without this,
# GPU state is lost on suspend (black screen on wake).
#
# Also requires kernel param: NVreg_PreserveVideoMemoryAllocations=1

case "$1" in
    pre)
        /usr/bin/nvidia-sleep.sh "suspend"
        ;;
    post)
        /usr/bin/nvidia-sleep.sh "resume"
        ;;
esac
