#!/bin/bash
#Only to be run if a incremental backup is taken, if not then run prepare script manually
#To run do 
#bash prepare.bash /path/to/backup/directory 
#script will then look for fullbackup folder and loop through the incremental backups in order
#do not run if no incremental backups have been taken, run prepare manually

# Set variables for the full backup folder and the incremental backup folder

backupdir="$1"
FULL_BACKUP_DIR=$backupdir/fullbackup/
INCREMENTAL_BACKUP_DIR=$backupdir/incr/*
incrementaldir=$backupdir/incr/
preparelog=$backupdir/prepare.log

# Change directory, unzip file and run prepare fullbackup
cd $FULL_BACKUP_DIR
gunzip -c $FULL_BACKUP_DIR/* | mbstream -x
mariabackup --prepare --target-dir=$FULL_BACKUP_DIR 2>> $preparelog
mv $FULL_BACKUP_DIR/full_backup.gz ..

# Loop through incremental backup folders, unzip and apply them to the full backup

for DIR in $INCREMENTAL_BACKUP_DIR
do
    checkstatus=$(tail -n 2 $preparelog | grep -c "completed OK")
    if [[ $checkstatus -eq 1 ]]; then
        cd $DIR
        gunzip -c $DIR/* | mbstream -x
        mariabackup --prepare --target-dir=$FULL_BACKUP_DIR --incremental-dir=$DIR 2>> $preparelog
    else
        echo "$(date +'%Y-%m-%d %H:%M:%S') Last incremental failed to run, please check $preparelog for more details"
        echo "$(date +'%Y-%m-%d %H:%M:%S') Check incremental folder for compressed file. Backup might be corrpted, prepare to last good incremental" >> $preparelog
    fi
done



#delete incrmental uncompressed files after they are appiled to fullbackup to save space
for DIR in $INCREMENTAL_BACKUP_DIR
do
    cd $DIR
    find $DIR/* ! -name 'incremental.backup.gz' | xargs rm -rf
    echo "$(date +'%Y-%m-%d %H:%M:%S') Deleted uncompressed files for incremental $DIR" >> $preparelog
done

lastcheckstatus=$(grep -c "completed OK" $preparelog)

incbackups=$(find $incrementaldir -mindepth 1 -maxdepth 1 -type d | wc -l)
includefull=$(($incbackups + 1))

if [[ $lastcheckstatus -eq $includefull ]]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') Prepare completed successfully and ready to restore from backup directory $FULL_BACKUP_DIR"
else
    echo "$(date +'%Y-%m-%d %H:%M:%S') Prepare failed, check $preparelog for more details. number of backups did not equal number of prepared backups. If you are running this a second time and didn't delete prepare.log then ignore error and check $preparelog"
fi
 
