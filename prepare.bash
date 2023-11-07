#!/bin/bash
#Only to be run if a incremental backup is taken, if not then run prepare script manually
#To run do 
#bash prepare.bash /path/to/backup/directory 
#script will then look for fullbackup folder and loop through the incremental backups in order
#do not run if no incremental backups have been taken, run prepare manually

# Set variables for the full backup folder and the incremental backup folder

backupdir="$1"
exportoption="$2"
FULL_BACKUP_DIR=$backupdir/fullbackup/
restartfulldir=$FULL_BACKUP_DIR/*
INCREMENTAL_BACKUP_DIR=$backupdir/incr/*
incrementaldir=$backupdir/incr/
preparelog=$backupdir/prepare.log

#reset backup directory if prepare script has been ran before


full_backup_file=$backupdir/full_backup.gz
echo $full_backup_file 
if [ -f $full_backup_file ]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') Prepare script has been ran before. resetting directory for next prepare run"
    echo "$(date +'%Y-%m-%d %H:%M:%S') Emptying the $FULL_BACKUP_DIR directory"
    rm -rf $restartfulldir
    echo "$(date +'%Y-%m-%d %H:%M:%S') Moving full backup zip file back to $FULL_BACKUP_DIR"
    mv $backupdir/full_backup.gz $FULL_BACKUP_DIR
    echo "$(date +'%Y-%m-%d %H:%M:%S') Archiving prepare file"
    archivelog=$backupdir/old-prepare-$(date +'%H:%M:%S').log
    mv $preparelog $archivelog
    echo "$(date +'%Y-%m-%d %H:%M:%S') Directory reset, starting prepare process as normal"   
    
else

    echo "$(date +'%Y-%m-%d %H:%M:%S') First time running prepare. running process as normal"
fi

# Change directory, unzip file and run prepare fullbackup
cd $FULL_BACKUP_DIR
unpigz -c $FULL_BACKUP_DIR/* | mbstream -x
mariabackup --prepare --target-dir=$FULL_BACKUP_DIR 2>> $preparelog
mv $FULL_BACKUP_DIR/full_backup.gz ..

# Loop through incremental backup folders, unzip and apply them to the full backup

for DIR in $INCREMENTAL_BACKUP_DIR
do
    checkstatus=$(tail -n 2 $preparelog | grep -c "completed OK")
    
    if [[ $checkstatus -eq 1 ]]; then
        cd $DIR
        gunzip -c $DIR/* | mbstream -x
        echo "$(date +'%Y-%m-%d %H:%M:%S') Applying $DIR incremental updates to fullbackup"
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
    echo "$(date +'%Y-%m-%d %H:%M:%S') Deleting uncompressed $DIR leaveing zipped file alone"
done

lastcheckstatus=$(grep -c "completed OK" $preparelog)

incbackups=$(find $incrementaldir -mindepth 1 -maxdepth 1 -type d | wc -l)
includefull=$(($incbackups + 1))

#if number of prepared backups = number of backups process was succesfully
if [[ $lastcheckstatus -eq $includefull ]]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') Prepare completed successfully and ready to restore from backup directory $FULL_BACKUP_DIR"
    echo "Restore with either command:"
    echo "mariabackup --copy-back --target-dir=$FULL_BACKUP_DIR"
    echo "mariabackup --move-back --target-dir=$FULL_BACKUP_DIR"
else
    echo "$(date +'%Y-%m-%d %H:%M:%S') Prepare failed, check $preparelog for more details. number of backups did not equal number of prepared backups"
fi
 

if [[ $2 == "--export" ]]; then
    echo "$(date +'%Y-%m-%d %H:%M:%S') Export option select, preparing the full backup with .cfg files for tablespace import"
    mariabackup --prepare --export --target-dir=$FULL_BACKUP_DIR 2>> $preparelog
fi
