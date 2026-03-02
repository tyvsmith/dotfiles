function format-drive --description 'Format entire drive as single exFAT partition'
    if test (count $argv) -ne 2
        echo "Usage: format-drive <device> <name>"
        echo "Example: format-drive /dev/sda 'My Stuff'"
        echo ""
        echo "Available drives:"
        lsblk -d -o NAME -n | awk '{print "/dev/"$1}'
        return 1
    end

    set -l device $argv[1]
    set -l name $argv[2]

    echo "WARNING: This will completely erase all data on $device and label it '$name'."
    gum confirm "Are you sure you want to continue?"; or return

    sudo wipefs -a $device
    sudo dd if=/dev/zero of=$device bs=1M count=100 status=progress
    sudo parted -s $device mklabel gpt
    sudo parted -s $device mkpart primary 1MiB 100%
    sudo parted -s $device set 1 msftdata on

    set -l partition
    if string match -q '*nvme*' $device
        set partition {$device}p1
    else
        set partition {$device}1
    end

    sudo partprobe $device; or true
    sudo udevadm settle; or true
    sudo mkfs.exfat -n $name $partition

    echo "Drive $device formatted as exFAT and labeled '$name'."
end
