#!/bin/bash

#dbname=$1
backup_dir="$1"
dbname="fire"
datadir=/var/lib/mysql

discardtablespace='/tmp/discard.sql'
importtablespace='/tmp/import.sql'
dropkeys='/tmp/drop.sql'
addkeys='/tmp/add.sql'

#Removing old files as MariaDB can't overwrite files
rm -f $discardtablespace
rm -f $importtablespace
rm -f $dropkeys
rm -f $addkeys

echo "$(date +'%Y-%m-%d %H:%M:%S') Appending database name $dbname to variable for sql script to generate files for process"

#Add SET @databasename to the top of the file, outputs file with variable needed for .sql file
echo -e "SET @databasename = '$dbname';\n$(cat grabresults.sql)" > grabresults2.sql

#Apply data structure for $dbname
mariadb $dbname < /home/harrypask/scripts/testing/nodata.sql

#Pipe generated file into mariadb to export four .sql files for process
mariadb < grabresults2.sql

#drop keys
echo "$(date +'%Y-%m-%d %H:%M:%S') Dropping keys for database $dbname"
mariadb $dbname < $dropkeys

#discard tablespace
echo "$(date +'%Y-%m-%d %H:%M:%S') Discarding tablespaces for database $dbname"
mariadb $dbname < $discardtablespace

#copy files
cp $backup_dir/$dbname/*.cfg /var/lib/mysql/$dbname
cp $backup_dir/$dbname/*.ibd /var/lib/mysql/$dbname

#grant permissions to folder
echo "$(date +'%Y-%m-%d %H:%M:%S') Granting ownership to MariaDB"
sudo chown -R mysql:mysql $datadir

#import tablespaces
echo "$(date +'%Y-%m-%d %H:%M:%S') Importing tables spaces for database $dbname"
mariadb $dbname < $importtablespace

#add keys
echo "$(date +'%Y-%m-%d %H:%M:%S') Adding keys back to database $dbname"
mariadb $dbname < $addkeys
