#!/bin/bash
#Only to be run if an incremental backup is taken, if not then run mariabackup --prepare command manually
#To run do 
#bash prepare.bash /path/to/backup/directory 
#script will then look for fullbackup folder and loop through the incremental backups in order
#do not run if no incremental backups have been taken, run prepare manually

# Set variables for the full backup folder and the incremental backup folder

backupdir="$1"
FULL_BACKUP_DIR=$backupdir/fullbackup/
INCREMENTAL_BACKUP_DIR=$backupdir/incr/*


# Change directory, unzip file and run prepare fullbackup
cd $FULL_BACKUP_DIR
gunzip -c $FULL_BACKUP_DIR/* | mbstream -x
mariabackup --prepare --target-dir=$FULL_BACKUP_DIR 2>> $backupdir/perpare.log
mv $FULL_BACKUP_DIR/full_backup.gz ..

# Loop through incremental backup folders, unzip and apply them to the full backup

for DIR in $INCREMENTAL_BACKUP_DIR
do
    cd $DIR
    gunzip -c $DIR/* | mbstream -x
    mariabackup --prepare --target-dir=$FULL_BACKUP_DIR --incremental-dir=$DIR 2>> $backupdir/perpare.log
done

#delete incrmental uncompressed files after they are appiled to fullbackup to save space
for DIR in $INCREMENTAL_BACKUP_DIR
do
    cd $DIR
    find . ! -name 'incremental.backup.gz' | xargs rm -rf
done
