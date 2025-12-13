#!/bin/sh
#
# Due to the fact that pcscd will not rescan the usb bus on hotplug events
# when --disable-polkit is used on the command line, We have to handle it 
# through this mdev script
#
VENDOR=$(cat /sys$DEVPATH/idVendor 2>/dev/null)
PRODUCT=$(cat /sys$DEVPATH/idProduct 2>/dev/null)

if [ "$VENDOR" = "072f" ]; then
    case "$ACTION" in
        add)
  	    # 
	    # Start pcscd when the reader is plugged in
	    #
            logger "ACS device plugged in: $VENDOR:$PRODUCT"
            pcscd --disable-polkit --force-reader-polling &
            ;;
        remove)
            logger "ACS device removed: $VENDOR:$PRODUCT"
            #
	    # Kill the pcscd daemon when the reader is removed
	    #
            PCSC_PID=$(cat /run/pcscd/pcscd.pid)
	    kill $PCSC_PID
            ;;
    esac
fi
