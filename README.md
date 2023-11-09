# mariabackup-script
## Full and incremental script along with prepare script to uncompress and apply incremental backups to full backup ##

Parts of the scripts are standard to Rehat/yum distros which means you may find that you need to change tools used in the script to better suit your OS. You may need to install pigz, or change it to gzip and gunzip.

### This script has the following features: ###

* Full and incremental backups (compressed with gzip)
* Retention policy
* Email on failure (mailx)
* Auto removal of failed incremental backups
* Prepare script that loops through incremental backups to apply new changes to full backup

### How to use ###

```bash

bash mariabackup.bash

bash prepare.bash /media/backups/dateofback
```

### Create the backup user: ###

```SQL

create user 'backup'@'localhost' identified by 'password';
grant reload,process,lock tables,binlog monitor,connection admin,slave monitor on *.* to 'backup'@'localhost';

```

### Main script settings: ###


```bash
# Define the backup directory
backup_dir=/media/backups/

# Define the mariadb user and password
user=backup
password=password

#emaillist, spaces in-between, no commas
emails="email@emaildomain.com"
fromemail="mariabackup@emaildomain.com"

#number of days to keep backups
#0= just today's backup | 1= today and yesterday | 2=today,yesterday,day before etc
backupdays=0

#dump table sturture per for single database restores (full innodb databases only)
dumpstructure='n'
```

### Add, remove or change variables in the mariabackup options ###
Do not change, will break script|
----------------|
"--backup"|
"--user=$user"|
"--password=$password"|
"--target-dir=$fullbackuplocation"|
"--extra-lsndir=$extra_lsndir"|
"--stream=xbstream"|


#### options: ####

You have options for full and incremental backups. Having two sets of options allows you to have lots of Parrel threads for the full backup early in the morning and a few in working hours to stop the database becoming slow during the day as incremental backups shouldn't take long to complete

```bash
#----------define backup options------------
#incremental options
declare -a backup_options_inc=(
	"--backup"
	"--user=$user"
	"--password=$password"
	"--extra-lsndir=$extra_lsndir"
	"--incremental-basedir=$extra_lsndir"
	"--stream=xbstream"
	"--slave-info"
	"--parallel=1"
	)

#full backup options
declare -a backup_options_full=(
        "--backup"
        "--user=$user"
        "--password=$password"
        "--target-dir=$fullbackuplocation"
        "--extra-lsndir=$extra_lsndir"
        "--stream=xbstream"
	"--slave-info"
	"--parallel=1"
        )

```
