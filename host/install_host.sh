apt-get -y update
apt-get -y dist-upgrade
path=/root/
echo "Configure networking"
echo "Setting up network configuration on the host.
Note : This will override your present network configuration. But you can backup the network anytime from the backup file created.
==========================================================="

echo "Installing some useful packages"
echo "==============================="
apt-get install -y python
apt-get install -y kvm
apt-get install -y qemu
apt-get install -y qemu-kvm
#apt-get install -y virt-manager
apt-get install -y libvirt-bin
apt-get install -y libvirt0
apt-get install -y python-libvirt
apt-get install -y gettext
apt-get install -y python-urlgrabber
apt-get install -y python-gtk-vnc
apt-get install -y virtinst
apt-get install -y nfs-common
apt-get install -y virt-top
apt-get install -y kvm-pxe
apt-get install -y vlan
apt-get install -y munin-node
apt-get install -y munin-libvirt-plugins

echo "Enabling KVM support"
echo "===================="
modprobe kvm
modprobe kvm_intel

#lsmod | grep kvm
#/etc/init.d/libvirtd start
mkdir /vms
mkdir /vms/ds_kvm1
mkdir /vms/ds_kvm2
#Assuming your host is already in our export list
size=`cat /etc/fstab |wc -l`|head -n $(($size-2)) /etc/fstab > /etc/fstab


echo "Editing /etc/libvirt/qemu.conf to set\n user=\"root\"\n group=\"root\. Bkup file created in local folder\n"
cp /lib/libvirt/qemu.conf  bkup-qemu.conf
echo "user=root" >> /etc/libvirt/qemu.conf
echo "group=root" >> /etc/libvirt/qemu.conf
echo "Restarting libvirt \n"
invoke-rc.d libvirt-bin restart

# Need to set the NEED_IDMAPD condition to YES in /etc/default/nfs-common
# For any changes, we just need to change ideal-nfs-common in one place.
echo "Replacing /etc/default/nfs-common with ideal-nfs-common. Bkup in bkup-nfs-common"
cp /etc/default/nfs-common bkup-nfs-common
cp ideal-nfs-common /etc/default/nfs-common


echo "Configuring munin"
echo "If you have done all the steps correctly, Congos!!! you are done with adding the host"
#echo "Restarting the system"
#shutdown -r now
