#!/bin/bash

LOGO_LIGHT="/usr/share/icingaweb2/public/img/neteye/logo-light.png"
LOGO_LIGHT_CUSTOM="/usr/share/icingaweb2/public/img/neteye/logo-light.png.customer"

if [ -f $LOGO_LIGHT_CUSTOM ] ; then
    cp -f ${LOGO_LIGHT_CUSTOM} ${LOGO_LIGHT}
    echo "[+] Install customer NetEye Logo Light."
fi
