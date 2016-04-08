#git clone https://github.com/waghsk/i2b2-install


BASE=$1

#sudo yum -y install git php perl wget zip unzip httpd 

install_postgres(){
	if [ -d /var/lib/pgsql/9.4/data/ ]
	then echo "postgres already installed"
	else
		sudo yum install -y http://yum.postgresql.org/9.4/redhat/rhel-6-x86_64/pgdg-redhat94-9.4-1.noarch.rpm
		sudo yum install -y postgresql94-contrib  postgresql94-server 
		sudo rm -rf /var/lib/pgsql/9.4/
		sudo mkdir /var/lib/pgsql/9.4/
		chown -R postgres:postgres /var/lib/pgsql/9.4/
		sudo [ -f /usr/pgsql-9.4/bin/postgresql94-setup ] && sudo /usr/pgsql-9.4/bin/postgresql94-setup initdb || sudo service postgresql-9.4 initdb
		sudo chkconfig postgresql-9.4 on 
		sudo cp conf/postgresql/pg_hba.conf  /var/lib/pgsql/9.4/data/
		sudo service postgresql-9.4 start
		
	fi
}

install_httpd(){
		if [ -f /etc/httpd/conf.d/i2b2_proxy.conf ]; then
			echo "httpd already installed"
		else
			echo "ProxyPreserveHost on" > /etc/httpd/conf.d/i2b2_proxy.conf		
			echo "ProxyPass /i2b2/ http://localhost:9090/i2b2/" >> /etc/httpd/conf.d/i2b2_proxy.conf		
			echo "ProxyPassReverse /i2b2/ http://localhost:9090/i2b2/" >> /etc/httpd/conf.d/i2b2_proxy.conf		
			sudo chkconfig httpd on 
			sudo service httpd start
			sudo /usr/sbin/setsebool httpd_can_network_connect 1
			sudo sed -i s/SELINUX=enforcing/SELINUX=disabled/ /etc/sysconfig/selinux 
		fi
}

load_demo_data(){

	echo "drop database i2b2;" |psql -U postgres

	BASE="/home/ec2-user/i2b2-install"
	DATA_BASE="$BASE/unzipped_packages/i2b2-data-master"
	cat create_database.sql |psql -U postgres 
	cat create_users.sql |psql -U postgres i2b2

	cd "$DATA_BASE/edu.harvard.i2b2.data/Release_1-7/NewInstall/Crcdata/"
	echo "pwd:$PWD"
	cat scripts/crc_create_datamart_postgresql.sql|psql -U postgres i2b2
	cat scripts/crc_create_query_postgresql.sql|psql -U postgres i2b2
	cat scripts/crc_create_uploader_postgresql.sql|psql -U postgres i2b2
	cat scripts/expression_concept_demo_insert_data.sql|psql -U postgres i2b2
	cat scripts/expression_obs_demo_insert_data.sql|psql -U postgres i2b2
	for x in $(ls scripts/postgresql/); do cat scripts/postgresql/$x|psql -U postgres i2b2;done;

	cd "$DATA_BASE/edu.harvard.i2b2.data/Release_1-7/NewInstall/Hivedata/"
	mkdir ~/tmp
	for x in "create_postgresql_i2b2hive_tables.sql" "work_db_lookup_postgresql_insert_data.sql" "ont_db_lookup_postgresql_insert_data.sql" "im_db_lookup_postgresql_insert_data.sql" "crc_db_lookup_postgresql_insert_data.sql"
	do echo "SET search_path TO i2b2hive;">~/tmp/t ;cat scripts/$x>>~/tmp/t;cat ~/tmp/t|psql -U postgres i2b2 ;done;

	cd ../Pmdata/
	for x in "create_postgresql_i2b2pm_tables.sql" "create_postgresql_triggers.sql"
	do echo $x;cat scripts/$x|psql -U postgres i2b2 ;done;
	cat scripts/pm_access_insert_data.sql|psql -U postgres i2b2

	echo "grant all privileges on all tables in schema i2b2hive to i2b2hive;"|psql -U postgres i2b2

	cd "$DATA_BASE/edu.harvard.i2b2.data/Release_1-7/NewInstall/Metadata/"
	for x in $(ls scripts/*postgresql*); do echo $x;cat $x|psql -U postgres i2b2 ;done;
	for x in $(ls demo/scripts/*.sql); do echo $x;cat $x|psql -U postgres i2b2 ;done;
	for x in $(ls demo/scripts/postgresql/*); do echo $x;cat $x|psql -U postgres i2b2 ;done;
	cat scripts/pm_access_insert_data.sql|psql -U postgres i2b2

	cd "$DATA_BASE/edu.harvard.i2b2.data/Release_1-7/NewInstall/Workdata/";
	x="scripts/create_postgresql_i2b2workdata_tables.sql"; echo $x;cat $x|psql -U postgres i2b2;
	x="scripts/workplace_access_demo_insert_data.sql"; echo $x;cat $x|psql -U postgres i2b2;

	cd "$BASE"
	cat grant_privileges.sql |psql -U postgres i2b2
}

install_i2b2webclient(){
	BASE=$1
	IP=$2
	BASE_CORE=$BASE/unzipped_packages
	echo "BASE_CORE:$BASE_CORE"
	[ -d $BASE_CORE/i2b2-webclient-master/ ]|| echo " webclient source not found"  
	[ -d $BASE_CORE/i2b2-webclient-master/ ]||  exit 

	if [ -d /var/www/html/webclient ]
	then echo "webclient folder already exists"
	else 
		copy_webclient_dir $BASE $IP /var/www/html
	fi
}

copy_webclient_dir(){
	local BASE=$1
	local IP=$2
	local TAR=$3
	UNZIP_DIR=$BASE/unzipped_packages
		mkdir $TAR/admin
		mkdir $TAR/webclient/
		cp -rv $UNZIP_DIR/i2b2-webclient-master/* $TAR/admin/
		cp -rv $UNZIP_DIR/i2b2-webclient-master/* $TAR/webclient/
		cp $BASE/conf/webclient/i2b2_config_data.js $TAR/webclient/
		cp $BASE/conf/admin/i2b2_config_data.js $TAR/admin/
		sed -i -- "s/127.0.0.1/$IP/" $TAR/webclient/i2b2_config_data.js
		sed -i -- "s/127.0.0.1/$IP/" $TAR/admin/i2b2_config_data.js

}
#install_httpd
#install_webclient
#install_postgres
#load_demo_data
