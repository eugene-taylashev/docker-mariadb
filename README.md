# Another MariaDB Docker image running on Alpine Linux

Docker has an [official image](https://hub.docker.com/_/mariadb) maintained by [MariaDB developer community](https://github.com/MariaDB/mariadb-docker). This variation is inspired by [yobasystems](https://github.com/yobasystems/alpine-mariadb).

## Intro

Brief description:
* The image uses Alpine:latest and MariaDB:latest. As compiled now they are v3.13.2 and v10.5.8.
* Non-privileged user id ``mysql`` is used to run the service. The ``mysql`` user ID is adjustable. As compiled: ``uid=1002(mysql) gid=1000(mysql)``
* Volume structure:
  * ``/etc/my.cnf.d`` for configuration files and X.509 certificates
  * ``/var/lib/mysql`` - Database files
* Environment Variables:
  * ``MYSQL_ROOT_PASSWORD``: specify the root password for Mariadb. If not specified for new installation, a random password will be generated and outputed into the log.
  * ``MYSQL_DATABASE``: specify the name of the database
  * ``MYSQL_USER``: specify the User@'%' for the database
  * ``MYSQL_PASSWORD``: specify the User password for the database
  * ``MYSQL_CHARSET``: default charset (utf8) for Mariadb
  * ``MYSQL_COLLATION``: default collation (utf8_general_ci) for Mariadb
  * ``VERBOSE``: if set to 1, the image generates more logs during start

## Usage

## Creating a new instance
It will create a new DB in the specified volume and set mysql root password (random if not specified):
```
docker run -d \
  --name mariadb \
  -e VERBOSE=1 \
  -e MYSQL_ROOT_PASSWORD="Hard2Gue$$Password" \
  -v /data/mariadb/db:/var/lib/mysql \
  -p 3306:3306  \
  etaylashev/mariadb
```
This image can also be used as a client to itself or other MariaDB:
``docker exec -it mariadb sh -c "exec mysql -u root -p"``

To copy default configuration files from the container to the local disk:
``docker cp f8787f6c08db:/etc/my.cnf.d/* .``

## Running an existing DB
To run the exitsting DB:
```
docker run -d \
  --name mariadb \
  -e VERBOSE=1 \
  -v /data/mariadb/conf:/etc/my.cnf.d \
  -v /data/mariadb/db:/var/lib/mysql \
  -p 3306:3306  \
  etaylashev/mariadb
```
To run it like a pod:
```
apiVersion: v1
kind: Pod
metadata:
  name: mariadb
  namespace: default
  labels:
    app: mariadb
    purpose: database
spec:
  volumes:
    - name: "maria-conf"
      hostPath:
        path: "/data/mariadb/conf"
    - name: "maria-data"
      hostPath:
        path: "/data/mariadb/db"
  containers:
    - name: mariadb
      image: etaylashev/mariadb
      env: 
        - name: VERBOSE
          value: "1"
      volumeMounts:
        - name: "maria-conf"
          mountPath: "/etc/my.cnf.d"
        - name: "maria-data"
          mountPath: "/var/lib/mysql"
      ports:
        - containerPort: 3306
          protocol: TCP
```

To configure TLS, copy certificate and key files to your configuration volume (i.e. ``/data/mariadb/conf``) and add to the file ``server.cnf`` the following:
```
[server]
ssl=on
ssl-ca=/etc/my.cnf.d/ca-chain.pem
ssl-cert=/etc/my.cnf.d/db01.crt
ssl-key=/etc/my.cnf.d/db01.key
```
To connect a client overt TLS:
``mysql -h 10.0.0.13 --ssl -u root -p``

To verify connection and used ciphers, run the command:
```
MariaDB [(none)]>status
```
and check in the output line like 
```
SSL:   Cipher in use is TLS_AES_256_GCM_SHA384
```

Check [documentation](https://mariadb.com/kb/en/secure-connections-overview/) to see more about encryption-in-transit for MariaDB.

## Backup DBs
To backup DBs from the running container into a SQL file execute the following:
```
export MYSQL_ROOT_PASSWORD="Hard2Gue$$Password"
docker exec mariadb sh -c "exec mysqldump --all-databases -uroot -p\"$MYSQL_ROOT_PASSWORD\" " >/backup/my_db.sql
```

## Restore DBs
To restore DBs from a SQL file to the running container execute the following:
```
export MYSQL_ROOT_PASSWORD="Hard2Gue$$Password"
docker exec -i mariadb sh -c "exec mysql -uroot -p\"$MYSQL_ROOT_PASSWORD\" " </backup/my_db.sql
```

## Upgrade DBs
Upgrading could be complex. Check [official documentation](https://mariadb.com/kb/en/upgrading-between-major-mariadb-versions/) first. 
Or try the following: 
```
export MYSQL_ROOT_PASSWORD="Hard2Gue$$Password"
docker exec -it mariadb sh -c "exec mysql_upgrade -uroot -p\"$MYSQL_ROOT_PASSWORD\" "
```
