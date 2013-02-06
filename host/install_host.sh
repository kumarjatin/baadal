Normal_pkg_lst=(python kvm qemu qemu-kvm libvirt-bin libvirt0 python-libvirt gettext python-urlgrabber python-gtk-vnc virtinst nfs-common virt-top kvm-ipxe vlan munin-node munin-libvirt-plugins)

Chk_Root_Login()
{
	username=`whoami`
	if test $username != "root"; then

  		echo "LOGIN AS SUPER USER(root) TO INSTALL BAADAL!!!"
  		exit 1
	fi

	echo "User Logged in as Root............................................"
}


#Function that install all the packages packages
Instl_Pkgs()
{	
	echo "Installing some useful packages"
	echo "==============================="

	Pkg_lst=()
	Pkg_lst=${Normal_pkg_lst[@]}

	for pkg_multi_vrsn in ${Pkg_lst[@]}; do

		pkg_status=0
		pkg_multi_vrsn=(`echo $pkg_multi_vrsn | tr ":" " "`)
 		
		for pkg in ${pkg_multi_vrsn[@]}; do

			dpkg-query -S $pkg>/dev/null;
	  		status=$?;
 	
			if test $status -eq 1;  then 

		        	echo "$pkg Package not installed................"
				echo "Installing Package: $pkg.................."
				apt-get -y install $pkg --force-yes
				status=$?

				if test $status -eq 0 ; then 
		      
					echo "$pkg Package Installed Successfully" 
					pkg_status=1
					break
			 	fi

		        elif test $status -eq 0 ; then

		        	echo "$pkg Package Already Installed" 
				pkg_status=1;break     
			fi
		done
		
		if test $pkg_status -eq 0; then
			
			echo "PACKAGE INSTALLATION UNSUCCESSFULL: ${pkg_multi_vrsn[@]} !!!"
			echo "NETWORK CONNECTION ERROR/ REPOSITORY ERROR!!!"
			exit 1 
		fi	
	done

	echo "Packages Installed Successfully..................................."
}


Enbl_Modules()
{

echo "Enabling KVM support"
echo "===================="

modprobe kvm
modprobe kvm_intel

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
}

#Script

Chk_Root_Login
Instl_Pkgs
Enbl_Modules
