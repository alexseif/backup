#!/bin/bash

#########################
######TO BE MODIFIED#####

# What folders should be backup'd?
declare -a what_to_backup=('path1' 'path2');

# Path where the backup and the backup folders should be stored
BACKUP_PATH="/root/backup/"
# Name of the folders to store the backups in
SQL_FOLDERNAME="db"
DATA_FOLDERNAME=""

BACKUP_MYSQL="1"
# MySql login information
MYSQL_USER=""
MYSQL_PASSWORD=""

### FTP server Setup ###
SEND_FTP="1"
FTPD="FTP FOLDER"
FTPU="FTP USERNAME"
FTPP="FTP PASSWORD"
FTPS="FTP HOST"

######DO NOT MAKE MODIFICATION BELOW#####
#########################################

### Binaries ###
TAR="$(which tar)"
GZIP="$(which gzip)"
SFTP="$(which sftp)"
SCP="$(which scp)"
MYSQL="$(which mysql)"
MYSQLDUMP="$(which mysqldump)"

# File backup name segments
HOSTNAME=$(hostname -s)
NOW=$(date +"%Y-%m-%d")

# TODO: implement verbosity
# override & verbosity
for flag in "$@"
do
	if [ "$flag" == "-o" ]; then
		FLAG_OVERWRITE="1"
	fi

	if [ "$flag" == "-v" ]; then
		FLAG_VERBOSE="1"
	fi
done
# Check freediskspace
FREE_DISCSPACE=`df / -h | awk '{ print $4 }' | tail -n 1 | cut -d "G" -f1`

# If discspace is lower than 1 GB, abort
if [[ $FREE_DISCSPACE -lt 1 ]]; then
	echo "Discspace is low! ( Less than 15 GB free. ) Backup aborted."
	exit
fi
# Create directory structure
if [ ! -d "$BACKUP_PATH/$NOW" ]; then
	mkdir $BACKUP_PATH/$NOW > /dev/null
	if [ $? -gt 0 ]; then
	    echo "Error while creating folder $BACKUP_PATH/$NOW. Aborting."
	    exit
	fi
fi

if [ ! -d "$BACKUP_PATH/$NOW/$SQL_FOLDERNAME" ]; then
	mkdir $BACKUP_PATH/$NOW/$SQL_FOLDERNAME > /dev/null
	if [ $? -gt 0 ]; then
	    echo "Error while creating folder $BACKUP_PATH/$NOW/$SQL_FOLDERNAME. Aborting."
	    exit
	fi
fi

if [ ! -d "$BACKUP_PATH/$NOW/$DATA_FOLDERNAME" ]; then
	mkdir $BACKUP_PATH/$NOW/$DATA_FOLDERNAME
	if [ $? -gt 0 ]; then
	    echo "Error while creating folder $BACKUP_PATH/$NOW/$DATA_FOLDERNAME. Aborting."
	    exit
	fi
fi

# Backup mysql
cd $BACKUP_PATH/$NOW/$SQL_FOLDERNAME/

if [ "$BACKUP_MYSQL" == "1" ]; then
	if [ ! -f ./database_backup.$NOW.tgz ] || [ "$FLAG_OVERWRITE" == "1" ]; then
		### Get all databases name ###
		DBS="$($MYSQL -u $MYSQL_USER -h $MYSQL_HOST -p$MYSQL_PASSWORD -Bse 'show databases')"
		for db in $DBS
		do
			### Backup dbs in individual files ###
			FILE=$BACKUP_PATH/$NOW/$SQL_FOLDERNAME/$db-$NOW.sql.gz
			echo $db; $MYSQLDUMP --opt --add-drop-table --allow-keywords -q -c -u $MYSQL_USER -h $MYSQL_HOST -p$MYSQL_PASSWORD $db | $GZIP -9 > $FILE
		done
	else
		echo "Database backup for date $NOW already exists, skipping."
	fi
fi

# Backup files
cd $BACKUP_PATH/$NOW/$DATA_FOLDERNAME/

DIRECTORY=$NOW

cd $BACKUP_PATH/$NOW/

for i in "${what_to_backup[@]}"
do	
	SPLIT=$(echo $i | tr "/" "\n")
	for x in $SPLIT
	do
		LAST=$x
	done

	if [ -d "$i" ]; then
		if [ ! -f ./$LAST.$NOW.tgz ] || [ "$FLAG_OVERWRITE" == "1" ]; then
			echo "Copying files from $i for packing..."
			cp -r $i ./
			echo "Done. Packing files..."
			tar -zcvf $LAST.$NOW.tgz ./$LAST >> $NOW.content.log
			echo "Done. Removing unpacked files..."
			rm -rf ./$LAST
			echo "Done. Folder backupped in $LAST.$NOW.tgz..."
		else
			echo "File $LAST.$NOW.tgz exists, skipping."
		fi
	else
		echo "Backup location $i wasn't found. Skipping."
	fi
done

### Compress all backups in one nice file to upload ###
ARCHIVE=$BACKUP_PATH/$HOSTNAME-$NOW.tar.gz
ARCHIVED=$NOW
cd $BACKUP_PATH/

$TAR -cvf $ARCHIVE $ARCHIVED

if [ "$SEND_FTP" == "1" ]; then
	### Dump backups using FTP ###
	cd $BACKUP_PATH
	DUMPFILE=$HOSTNAME-$NOW.tar.gz
	$SCP $DUMPFILE $FTPU@$FTPS:$FTPD/
fi
### Delete the backup dir and keep archive ###
rm -rf $ARCHIVED
