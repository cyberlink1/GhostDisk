#!/bin/bash

# Detect rotation from monitor-sensor
monitor-sensor | while read line; do
    case "$line" in
        *"normal"*)
            xrandr --output eDP-1 --rotate normal
            xinput map-to-output "GDIX0000:00 27C6:0E01" eDP-1
            xinput map-to-output "GDIX0000:00 27C6:0E01 Stylus" eDP-1
            ;;
        *"right-up"*)
            xrandr --output eDP-1 --rotate right
            xinput map-to-output "GDIX0000:00 27C6:0E01" eDP-1
            xinput map-to-output "GDIX0000:00 27C6:0E01 Stylus" eDP-1
            ;;
        *"left-up"*)
            xrandr --output eDP-1 --rotate left
            xinput map-to-output "GDIX0000:00 27C6:0E01" eDP-1
            xinput map-to-output "GDIX0000:00 27C6:0E01 Stylus" eDP-1
            ;;
        *"bottom-up"*)
            xrandr --output eDP-1 --rotate inverted
            xinput map-to-output "GDIX0000:00 27C6:0E01" eDP-1
            xinput map-to-output "GDIX0000:00 27C6:0E01 Stylus" eDP-1
            ;;
    esac
done

