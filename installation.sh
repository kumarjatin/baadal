################################ FILE CONSTANTS USED ###########################

Normal_pkg_lst=(ssh zip unzip tar openssh-server build-essential python2.7:python2.5 python-dev apache2 libapache2-mod-wsgi postfix wget mysql-server libapache2-mod-gnutls apache2.2-common python-matplotlib python-reportlab mercurial libvirt-bin python-libvirt)

Ldap_pkg_lst=(perl-modules libpam-krb5 libpam-cracklib php5-auth-pam libnss-ldap krb5-user ldap-utils libldap-2.4-2 nscd ca-certificates ldap-auth-client krb5-config:libkrb5-dev)

Mysql_pkg_lst=(mysql-server-5.5:mysql-server-5.1 libapache2-mod-auth-mysql php5-mysql mysql-client-core-5.5:mysql-client-core-5.1)

Conf_file="installation.cfg"

Auth_type='sqlite'

############################### FUNCTIONS USED #################################

Chk_Root_Login()
{
	username=`whoami`
	
	if test $username != "root"; then

  		echo "LOGIN AS SUPER USER(root) TO INSTALL BAADAL!!!"
  		exit 1
	fi
}

Cnfgr_Ldap_Srvc()
{
	cp krb5.conf /etc/krb5.conf -f
	cp ldap.conf /etc/ldap.conf -f
	cp nsswitch.conf /etc/nsswitch.conf -f
	cp common-account /etc/pam.d/common-account -f
	cp common-auth /etc/pam.d/common-auth -f
	cp common-password /etc/pam.d/common-password -f
	cp common-session /etc/pam.d/common-session -f
}

Populate_Pkg_Lst()
{
	str=`cat $Conf_file | grep -P "AUTHENTICATION:" |tr -d ' '`
	str=${str##"AUTHENTICATION:"}
	Auth_type=$str

	case $Auth_type in 
		
		ldap) Auth_type='ldap' 
		      Cnfgr_Ldap_Srvc 
		      Pkg_lst=("${Normal_pkg_lst[@]}" "${Ldap_pkg_lst[@]}" "${Mysql_pkg_lst[@]}")
		      ;;
	       mysql) Auth_type='mysql' 
		      Pkg_lst=("${Normal_pkg_lst[@]}" "${Mysql_pkg_lst[@]}") 
		      ;;
	   sqlite|"") Pkg_lst=${Normal_pkg_lst[@]}
		      ;;
		   *) echo "ERROR IN CONFIGURATION FILE"
		      exit 1
		      ;;
	esac
}

Instl_Pkgs()
{	
	Pkg_lst=()
	Populate_Pkg_Lst

	for pkg_multi_vrsn in ${Pkg_lst[@]}; do

		pkg_status=0
		pkg_multi_vrsn=(`echo $pkg_multi_vrsn | tr ":" " "`)
 		
		for pkg in ${pkg_multi_vrsn[@]}; do

			dpkg-query -S $pkg>/dev/null;
	  		status=$?;
 	
			if test $status -eq 1;  then 

		        	echo "$pkg Package not installed................................................"
				echo "Installing Package: $pkg.................................................."

		        	apt-get -y install $pkg --force-yes
				status=$?
		
				if test $status -eq 0 ; then 
		      
					echo "$pkg Package Installed Successfully" 
					pkg_status=1
					break
			 	fi

		        elif test $status -eq 0 ; then

		        	echo "$pkg Package Already Installed"; pkg_status=1; break     
			fi
		done
		
		if test $pkg_status -eq 0; then
			
			echo "PACKAGE INSTALLATION UNSUCCESSFULL: ${pkg_multi_vrsn[@]} !!!"
			echo "NETWORK CONNECTION ERROR/ REPOSITORY ERROR!!!"
			exit 1 
		fi	
	done
}


Setup_Web2py()
{
	Instl_Web2py=1
#	Auth_type='sqlite'
	
        if [ -d "/home/www-data/web2py/" ]; then
		echo "Web2py Already Exists!!!"
		
		while true; do
			
			echo "Would you like to re-install?(Y/n)"
			read ans
			
			case $ans in

				n|N) Instl_Web2py=0; break; ;;
			     y|Y|"") break; ;;
				  *) echo "Invalid Input!!!!"; ;;
			esac
		done
	fi

	if test $Instl_Web2py -ne 0; then
		
		wget http://www.web2py.com/examples/static/web2py_src.zip

		if test ! -f "web2py_src.zip"; then

			echo "UNABLE TO DOWNLOAD LATEST VERSION FROM REPOSITORY"
	
			while true
			do
				echo "Install previous Version?(Y/n)"
			        read ans
				
				case $confirm in
					
				     y|Y|"") cp web2py_tmp.zip web2py_src.zip; break; ;;
		  		        n|N) exit 1; ;;
		       			  *) echo "Invalid Input!!!!"; ;;
    				esac   
		        done
          
			if [ ! -f "web2py_src.zip" ]; then
				echo "some error in copying old version"
				exit 1
			fi
		else
			rm -rf web2py_tmp.zip; cp web2py_src.zip web2py_tmp.zip
		fi

		rm -rf web2py/
		unzip web2py_src.zip

		if test ! -d web2py/; then

			echo "UNABLE TO EXTRACT WEB2PY!!!"
			exit 1		
		fi

		rm -rf web2py_src.zip
		rm -rf /home/www-data/
		mkdir /home/www-data/
		cp -r web2py/ /home/www-data/web2py/
		
		if test $? -ne '0'; then
			echo "UNABLE TO SETUP WEB2PY!!!"
			exit 1
		else
			rm -rf web2py/
		fi
	fi		

	rm -rf /home/www-data/web2py/applications/baadal/
	cp -r baadal/ /home/www-data/web2py/applications/baadal/

	if test $? -ne '0'; then
		echo "UNABLE TO SETUP BAADAL!!!"
		exit 1
	fi

	shopt -s nocasematch
	case $Auth_type in

		ldap) mv /home/www-data/web2py/applications/baadal/models/db.py.ldap /home/www-data/web2py/applications/baadal/models/db.py
		      mv /home/www-data/web2py/applications/baadal/models/functions.py.ldap /home/www-data/web2py/applications/baadal/models/functions.py
		      mv /home/www-data/web2py/applications/baadal/private/process.py.ldap /home/www-data/web2py/applications/baadal/private/process.py
		      ;;
	       mysql) mv /home/www-data/web2py/applications/baadal/models/db.py.mysql /home/www-data/web2py/applications/baadal/models/db.py
		      mv /home/www-data/web2py/applications/baadal/models/functions.py.mysql /home/www-data/web2py/applications/baadal/models/functions.py
		      mv /home/www-data/web2py/applications/baadal/private/process.py.mysql /home/www-data/web2py/applications/baadal/private/process.py
		      ;;
		   *) mv /home/www-data/web2py/applications/baadal/models/db.py.sqlite /home/www-data/web2py/applications/baadal/models/db.py
		      mv /home/www-data/web2py/applications/baadal/models/functions.py.sqlite /home/www-data/web2py/applications/baadal/models/functions.py
		      mv /home/www-data/web2py/applications/baadal/private/process.py.sqlite /home/www-data/web2py/applications/baadal/private/process.py
	esac

	chown -R www-data:www-data /home/www-data/


}

Enbl_Modules()
{

#	echo "Enabling Apache Modules.........................................."
#	a2enmod ssl
#	a2enmod proxy
#	a2enmod proxy_http
#	a2enmod headers
#	a2enmod expires

	shopt -s nocasematch
	case $Auth_type in
		
		ldap|mysql) /etc/init.d/mysql restart

			    if test $? -ne 0; then
				echo "UNABLE TO RESTART MYSQL!!!"
				exit 1
			    fi


			    if [ -d /var/lib/mysql/baadal ] ; then

				    mysql -uroot -p -e "drop database baadal"
			    fi

			    mysql -uroot -p -e "create database baadal"
			    
			    if test $? -ne 0; then
				echo "UNABLE TO CREATE DATABASE!!!"
				exit 1
			    fi
	esac

}

Create_SSL_Certi()
{
	mkdir /etc/apache2/ssl
	echo "creating Self Signed Certificate................................."
	openssl genrsa 1024 > /etc/apache2/ssl/self_signed.key
	chmod 400 /etc/apache2/ssl/self_signed.key
	openssl req -new -x509 -nodes -sha1 -days 365 -key /etc/apache2/ssl/self_signed.key > /etc/apache2/ssl/self_signed.cert
	openssl x509 -noout -fingerprint -text < /etc/apache2/ssl/self_signed.cert > /etc/apache2/ssl/self_signed.info
}

Rewrite_Apache_Conf()
{
	echo "rewriting your apache config file to use mod_wsgi"

	echo '
		NameVirtualHost *:80
		NameVirtualHost *:443
		# If the WSGIDaemonProcess directive is specified outside of all virtual
		# host containers, any WSGI application can be delegated to be run within
		# that daemon process group.
		# If the WSGIDaemonProcess directive is specified
		# within a virtual host container, only WSGI applications associated with
		# virtual hosts with the same server name as that virtual host can be
		# delegated to that set of daemon processes.
		WSGIDaemonProcess web2py user=www-data group=www-data

		<VirtualHost *:80>
		  WSGIProcessGroup web2py
		  WSGIScriptAlias / /home/www-data/web2py/wsgihandler.py
		  WSGIPassAuthorization On
		
		  <Directory /home/www-data/web2py>
		    AllowOverride None
		    Order Allow,Deny
		    Deny from all
		    <Files wsgihandler.py>
		      Allow from all
		    </Files>
		  </Directory>
		
		  AliasMatch ^/([^/]+)/static/(.*) \
		           /home/www-data/web2py/applications/$1/static/$2
		  <Directory /home/www-data/web2py/applications/*/static/>
		    Options -Indexes
		    Order Allow,Deny
		    Allow from all
		  </Directory>
		
		  <Location /admin>
		  Deny from all
		  </Location>
		
		  <LocationMatch ^/([^/]+)/appadmin>
		  Deny from all
		  </LocationMatch>
		
		  CustomLog /var/log/apache2/access.log common
		  ErrorLog /var/log/apache2/error.log
		</VirtualHost>

		<VirtualHost *:443>
		  SSLEngine on
		  SSLCertificateFile /etc/apache2/ssl/self_signed.cert
		  SSLCertificateKeyFile /etc/apache2/ssl/self_signed.key
		
		  WSGIProcessGroup web2py
		  WSGIScriptAlias / /home/www-data/web2py/wsgihandler.py
		  WSGIPassAuthorization On
		
		  <Directory /home/www-data/web2py>
		    AllowOverride None
		    Order Allow,Deny
		    Deny from all
		    <Files wsgihandler.py>
		      Allow from all
		    </Files>
		  </Directory>

		  AliasMatch ^/([^/]+)/static/(.*) \
		        /home/www-data/web2py/applications/$1/static/$2
		
		  <Directory /home/www-data/web2py/applications/*/static/>
		    Options -Indexes
		    ExpiresActive On
		    ExpiresDefault "access plus 1 hour"
		    Order Allow,Deny
		    Allow from all
		  </Directory>
		
		  CustomLog /var/log/apache2/access.log common
		  ErrorLog /var/log/apache2/error.log
		</VirtualHost>
		' > /etc/apache2/sites-available/default

	# TO INTEGRATE WITH PAM UNCOMMENT THE BELOW
	# echo "setting up PAM"
	# sudo apt-get install pwauth
	# sudo ln -s /etc/apache2/mods-available/authnz_external.load /etc/apache2/mods-enabled
	# ln -s /etc/pam.d/apache2 /etc/pam.d/httpd
	# usermod -a -G shadow www-data
		
	echo "Restarting Apache................................................"
	
	/etc/init.d/apache2 restart

	if test $? -ne 0; then
		echo "UNABLE TO RESTART APACHE!!!"
		exit 1
	fi
	
}

Configure_Pwdless_Ssh()
{
	
	mkdir /var/www/.ssh
	chown -R www-data:www-data /var/www/.ssh
	su www-data -c "ssh-keygen -t rsa"

	while true; do

	        echo "Press (y) to add a new baadal host and (n) to stop adding baadal host"
	        read confirm
		case $confirm in
			y|Y) 
				echo "Enter the ipaddress of the host"
	                        read ip
				su www-data -c "ssh root@$ip mkdir -p .ssh"
				su www-data -c "cat ~/.ssh/id_rsa.pub | ssh root@$ip 'cat >> .ssh/authorized_keys'"

				ssh-keygen -t rsa
				ssh root@$ip mkdir -p .ssh
				cat ~/.ssh/id_rsa.pub | ssh root@$ip 'cat >> .ssh/authorized_keys'
				#<send-cron-file>
				scp install_package.sh root@$ip:.
				scp bridge root@$ip:.
				ssh root@$ip 'sh install_package.sh ; cp /etc/network/interfaces /etc/network/interfaces_orig; cat bridge /etc/network/interfaces > /etc/network/interfaces; /etc/init.d/networking restart;'
				ssh root@$ip 'brctl stp br0 on; mkdir /mnt; mkdir /mnt/baadalcse;'
				#ssh root@$ip 'mount filer03:/vol/baadalcse /mnt/baadalcse'
				#<set-cron-tab-host>
                            	;;
		       n|N) echo "We assume that u have configured passwordless ssh for all hosts" ; break ;; 
		       *)echo "Press 'y' if you want to configure passwordless ssh for a baadal and press 'n' to come outhost your can enter only (y/n)"
    		esac            
         done
 
}

Start_Web2py()
{
	cd /home/www-data/web2py
	sudo -u www-data python -c "from gluon.widget import console; console();"
	sudo -u www-data python -c "from gluon.main import save_password;import getpass;save_password(getpass.getpass(prompt='Web2py Admin Password: '),443)"
	nohup python /home/www-data/web2py/web2py.py -S baadal -M -R /home/www-data/web2py/applications/baadal/private/hostpower.py &
	nohup python /home/www-data/web2py/web2py.py -S baadal -M -R /home/www-data/web2py/applications/baadal/private/process.py &
	echo "*/45 * * * * www-data python /home/www-data/web2py/applications/baadal/cron/check_status.py" >> /etc/crontab
}

################################ SCRIPT ########################################

Chk_Root_Login
Instl_Pkgs
Setup_Web2py
Enbl_Modules
Create_SSL_Certi
Rewrite_Apache_Conf
Configure_Pwdless_Ssh
Start_Web2py
echo "done!"
