scp setup.sh root@blade9:.
scp bridge root@blade9:.
ssh blade9 './setup.sh ; cp /etc/network/interfaces /etc/network/interfaces_orig;
            cat bridge /etc/network/interfaces > /etc/network/interfaces; /etc/init.d/networking restart'

scp cs1080542@palasi:BTP/2012/BaadalCSE/huzur/cloud/setup.sh .
