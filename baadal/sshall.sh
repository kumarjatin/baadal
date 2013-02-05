#sudo -u www-data ssh-keygen -t rsa -P ''
sudo ssh-keygen -t rsa -P ''
for j in {9..13}
do
    echo blade$j
    #sudo -u www-data cat /var/www/.ssh/id_rsa.pub | ssh root@blade$j 'cat >> .ssh/authorized_keys2'
	sudo  cat /root/.ssh/id_rsa.pub | ssh root@blade$j 'cat >> .ssh/authorized_keys2'
done

