#!/bin/bash
echo "start dbus"
systemctl start dbus
echo "start udevd"
systemctl start systemd-udevd

