#! /bin/bash

m_user=$(id -un)

user_local_tmp="/usr/local/lib/python3.10/site-packages/p4/tmp"
user_local_srv="/usr/local/lib/python3.10/site-packages/p4/server"
local_phy="/home/$m_user/.local/lib/python3.10/site-packages/p4"
tmp_set=0
srv_set=0


if [ -d "$local_phy/tmp" ]; then
	echo "p4.tmp already installed"
	tmp_set=1
fi

if [ -d "$local_phy/server" ]; then
	echo "p4.server already installed"
	srv_set=1
fi


if [ ! -d "$user_local_tmp" ]; then
	echo "no p4.tmp - you are missing p4lang-pi"
	exit
fi

if [ ! -d "$user_local_srv" ]; then
	echo "no p4.server - you are missing p4lang-pi"
	exit
fi

if [ ! -d "$local_phy" ]; then
	echo "no p4 - you are missing p4runtime\nTry 'pip3 install p4runtime==1.3.0'"
	exit
fi


if [ "$tmp_set" = 0 ]; then
	sudo cp -r $user_local_tmp $local_phy
fi

if [ "$srv_set" = 0 ]; then
	sudo cp -r $user_local_srv $local_phy
fi

sudo chown -R $m_user:$m_user $local_phy

echo "Done\n"
tree $local_phy -L 2

