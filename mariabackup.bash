#!/bin/bash
#v1.0 written by Harry Pask
#Mariabackup tool for full and incremental backups for non-encrypted tables
#Built in backup retention, email on backup failure and easy to change Mariabackup options

#create user 'backup'@'localhost' identified by 'password';
#grant reload,process,lock tables,binlog monitor,connection admin,slave monitor on *.* to 'backup'@'localhost';

# Define the backup directory
backup_dir=/media/backups/

# Define the mariadb user and password
user=backup
password=password

#emaillist, spaces in-between, no commas
emails="harry.pask@hotmail.com"
fromemail="mariabackupalerts@6dglinux.com"

#number of days to keep backups
#0= just today's backup | 1= today and yesterday | 2=today,yesterday,day before etc
backupdays=0

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

#------------variables------------


# Get the current date
current_date=$(date +"%Y-%m-%d")
current_datetime=$(date +"%Y-%m-%d-%T")
current_date_folder=$backup_dir/$current_date

# Define the extra lsdir for incremental backups
extra_lsndir=$current_date_folder

# Define the full backup file
full_backup_file=$current_date_folder/full.backup

# Create the current date folder
incremental_folder=$current_date_folder/incr/$current_datetime
fullbackuplocation=$current_date_folder/fullbackup
mkdir -p $current_date_folder

#------backup process-------
cd $current_date_folder
# Check if full backup file exists
if [ -f $full_backup_file ]; then
	# Perform incremental backup if $full_backup_file exists
	mkdir -p $incremental_folder
	mariabackup "${backup_options_inc[@]}" 2>> $current_date_folder/backup.log | gzip > $incremental_folder/incremental.backup.gz
else
	# Perform full backup and create create $full_backup_file
	mkdir -p $fullbackuplocation
	mariabackup "${backup_options_full[@]}" 2>> $current_date_folder/backup.log | gzip > $fullbackuplocation/full_backup.gz
	#touch $full_backup_file
	#mv $current_date_folder/full_backup.gz $fullbackuplocation
fi

#-----Check backup was successful-------

#check backup log
checkstatus=$(tail -n 2 /$current_date_folder/backup.log| grep -c "completed OK")

#if completed OK! is at the end of the backup log file then add status to backup_status.log
#if not then send backup.log to email address and delete failed incremental backup folder so prepare script doesn't break
#If full backup is successful then make $full_backup_file, if fullbackup fails then file is not created so on next run a fullbackup is tried again

if [[ $checkstatus -eq 1 ]]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') mariabackup completed okay" >> $current_date_folder/backup_status.log
	touch $full_backup_file
	find $backup_dir -maxdepth 1 -name '20*' -mtime +$backupdays | xargs rm -rf
else
    log_content=$(tail -n 200 "$current_date_folder/backup.log") 
    echo "$log_content" | mailx -r $fromemail -s "MariaBackup task for $HOSTNAME failed" $emails
		#checks if full backup completed, if it has then failed incremental backup is removed
		if [[ -f $full_backup_file ]]; then
			rm -rf $incremental_folder
			echo "$(date +'%Y-%m-%d %H:%M:%S') mariabackup failed - file $incremental_folder deleted" >> $current_date_folder/backup_status.log
		else 
			echo "$(date +'%Y-%m-%d %H:%M:%S') Full backup failed, please reslove issue and rerun backup" >> $current_date_folder/backup_status.log
		fi
fi	



