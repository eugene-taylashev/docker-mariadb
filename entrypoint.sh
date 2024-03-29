#!/bin/sh
set -e

#=============================================================================
#
#  Variable declarations
#
#=============================================================================
SVER="20211208"         #-- When updated
#VERBOSE=1              #-- 1 - be verbose flag, defined outside of the script

MDB_CONF="/etc/my.cnf"
DIR_CONF="/etc/my.cnf.d"
DIR_RUN="/run/mysqld"
DIR_DB="/var/lib/mysql"

#-- Externally defined variables
#USER=mysql
#PUID=1000
#PGID=1000
#TZ America/Toronto
#MYSQL_ROOT_PASSWORD
#MYSQL_DATABASE
#MYSQL_USER
#MYSQL_PASSWORD
#MYSQL_CHARSET
#MYSQL_COLLATION
#MYSQL_REPLICATION_USER
#MYSQL_REPLICATION_PASSWORD
#MYSQL_REPLICA_FIRST
#VERBOSE=0

source /functions.sh  #-- Use common funcations


#=============================================================================
#
#  MAIN()
#
#=============================================================================
dlog '============================================================================='
dlog "[ok] - starting entrypoint.sh ver $SVER"

#-- get additional information
get_container_details
ip addr show eth0
dlog "User details (uid,gid):"
id $USER

#-----------------------------------------------------------------------------
# Adjust parameters
#-----------------------------------------------------------------------------

#-- Modify Group ID if needed
CGID=$(id -g $USER)
if [ $PGID -ne $CGID ] ; then
    groupmod --gid $PGID $USER
	is_good "[ok] - changed gid from $CGID to $PGID for $USER" \
	"[not ok] - changing gid from $CGID to $PGID for $USER" 
fi

#-- Modify User and Group ID if needed
CUID=$(id -u $USER)
if [ $PUID -ne $CUID ] ; then
    usermod --gid $PGID --uid $PUID $USER
	is_good "[ok] - changed uid from $CUID to $PUID for $USER" \
	"[not ok] - changing gid from $CUID to $PUID for $USER" 
fi

#-- Modify TimeZone  if needed
if [ "$TZ" != "$(cat /etc/timezone)" ] ; then
    cp /usr/share/zoneinfo/$TZ /etc/localtime; \
    echo "$TZ" >  /etc/timezone;
fi

#-----------------------------------------------------------------------------
# Work with MariaDB
#-----------------------------------------------------------------------------
if [ ! -d $DIR_RUN ]; then
    dlog "[ok] -  mysqld not found, creating...."
    mkdir -p $DIR_RUN
else
    dlog "[ok] - mysqld exists, skipping creation"
fi
chown -R $USER:$USER $DIR_RUN


#-- Verify if configuration directory exists
if [ ! -d $DIR_CONF ]; then
    dlog "[ok] -  directory $DIR_CONF not found, creating...."
    mkdir -p $DIR_CONF
else
    dlog "[ok] - directory $DIR_CONF exists, skipping creation"
fi
chown -R $USER:$USER $DIR_CONF

#-- Verify if configuration file exists
if [ ! -s $MDB_CONF ] ; then
    dlog "[ok] -  configuration file $MDB_CONF not found, creating...."
    #-- Create a simple config file
    cat << EOC > $MDB_CONF
[client-server]

# include *.cnf from the config directory
!includedir /etc/my.cnf.d
EOC
else 
    dlog "[ok] - configuration file $MDB_CONF exists, skipping creation"
fi

#-- Create new Database, if needed
if [ ! -d $DIR_DB/mysql ]; then
    #-- Copied from: https://github.com/yobasystems/alpine-mariadb/blob/master/alpine-mariadb-amd64/files/run.sh
    dlog "[ok] - MySQL data directory not found, creating initial DBs"

    chown -R $USER:$USER $DIR_DB

    mysql_install_db --user=$USER --ldata=$DIR_DB > /dev/null

    if [ "$MYSQL_ROOT_PASSWORD" = "" ]; then
        MYSQL_ROOT_PASSWORD=`pwgen 16 1`
        echo "[ok] - MySQL root Password: $MYSQL_ROOT_PASSWORD"
    fi

    MYSQL_DATABASE=${MYSQL_DATABASE:-""}
    MYSQL_USER=${MYSQL_USER:-""}
    MYSQL_PASSWORD=${MYSQL_PASSWORD:-""}

    tfile=`mktemp`
    if [ ! -f "$tfile" ]; then
        return 1
    fi

    cat << EOF > $tfile
USE mysql;
FLUSH PRIVILEGES ;
GRANT ALL ON *.* TO 'root'@'%' identified by '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION ;
GRANT ALL ON *.* TO 'root'@'localhost' identified by '$MYSQL_ROOT_PASSWORD' WITH GRANT OPTION ;
SET PASSWORD FOR 'root'@'localhost'=PASSWORD('${MYSQL_ROOT_PASSWORD}') ;
DROP DATABASE IF EXISTS test ;
FLUSH PRIVILEGES ;
EOF

    if [ "$MYSQL_DATABASE" != "" ]; then
        dlog "[ok] - Creating database: $MYSQL_DATABASE"
        if [ "$MYSQL_CHARSET" != "" ] && [ "$MYSQL_COLLATION" != "" ]; then
            dlog "[ok] - with character set [$MYSQL_CHARSET] and collation [$MYSQL_COLLATION]"
            echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET $MYSQL_CHARSET COLLATE $MYSQL_COLLATION;" >> $tfile
        else
            dlog "[ok] - with character set: 'utf8' and collation: 'utf8_general_ci'"
            echo "CREATE DATABASE IF NOT EXISTS \`$MYSQL_DATABASE\` CHARACTER SET utf8 COLLATE utf8_general_ci;" >> $tfile
        fi

     if [ "$MYSQL_USER" != "" ]; then
        dlog "[ok] - Creating user: $MYSQL_USER with password $MYSQL_PASSWORD"
        echo "GRANT ALL ON \`$MYSQL_DATABASE\`.* to '$MYSQL_USER'@'%' IDENTIFIED BY '$MYSQL_PASSWORD';" >> $tfile
        fi
    fi

    /usr/bin/mysqld --user=$USER --bootstrap --verbose=0 --skip-name-resolve --skip-networking=0 < $tfile
    rm -f $tfile

    dlog '[ok] - MySQL init process done. Ready for start up.'

    echo "exec /usr/bin/mysqld --user=$USER --console --skip-name-resolve --skip-networking=0" "$@"
else
    chown -R $USER:$USER $DIR_DB
    dlog "[ok] - MySQL directory exists, skipping creation"
fi

#-- Check if First Cluster node requires
if [ $MYSQL_REPLICA_FIRST -gt 0 ] ; then
    WSREP="--wsrep-new-cluster"
    dlog "[ok] - first node in the cluster"
else 
    WSREP=""
fi
#--skip-networking=0
exec /usr/bin/mysqld --user=$USER --console ${WSREP} --skip-name-resolve $@
