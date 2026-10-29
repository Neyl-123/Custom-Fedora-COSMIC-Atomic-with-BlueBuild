function wake-desktop
    echo "Waking desktop server via embedded Raspberry Pi..."
    ssh user@<pi-mesh-ip> "sudo etherwake -i eth0 <DESKTOP_LAN_MAC>"
end

function boot-desktop-windows
    echo "Instructing desktop to boot into Windows League of Legends runtime..."
    ssh user@<desktop-mesh-ip> "sudo grub-reboot 'Windows Boot Manager' && sudo reboot"
end
