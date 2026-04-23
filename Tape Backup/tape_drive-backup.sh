#!/bin/bash
#
# Plugin name: tape_drive-backup.sh
# Description: This comprehensive script performs TBU (tape drive unit) backup/restore using pre-prepared .txt and .in files with paths to NFS and SMB
#              shares and important TBU inventory info. Script has also functionality to rewind, show library status, tape content or load/unload the tape.
#
# Last updated: 23/04/2026  
# Author: Marcin Bednarski (e-mail: marcin.bednarski@gmail.com)
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.
#

##
## Initial Variables
##
ARG=${1}
TAPE=/dev/nst0
DRIVE=/dev/sg3
PASSWD=xxxxxxxx
EMAIL=tbu-backup-report@mycorp.org
NOW=$(date +"%d%m%y")
NFS_list=backup_files_nfs.txt
SMB_list=backup_files_smb.txt
NFS_FILES=$(cat ${NFS_list} |grep -v "^#")
SMB_FILES=$(cat ${SMB_list} |grep -v "^#")
SMB_MOUNT=$(cat backup_smb_mount.txt |grep -v "^#")
LOG=tape_drive-backup.${NOW}.log
OPERLOG=tape_drive-operations.log
TAPE_TEST_FILE=tape-test.in
TAPE_TEST_DIR=backup-test
TAPE_TEST_SUM="84e3dd34643a67cf861d8e28899ff889"
CIFS_USER=backup
CIFS_PASSWD=xxxxxxxx
PROGRAM=${0##*/}
PROGPATH=${0%/*}
pos=0;total=0;total_nfs=0;total_smb=0;size=0

##
## Function print_help
##
print_help() 
{
	echo -e ""
    echo -e "PROGRAM:"
	echo -e "${PROGRAM}"
    echo -e ""
    echo -e "DESCRIPTION:"
	echo -e "This comprehensive script performs TBU (tape drive unit) backup/restore using pre-prepared .txt and .in files with paths to NFS and SMB"
    echo -e "shares and important TBU inventory info. Script has also functionality to rewind, show library status, tape content or load/unload the tape."
	echo -e ""
    echo -e "USAGE:"
    echo -e "`basename $0` -backup\t run tape backup; backup content listed in files:" 
    echo -e "\t\t\t NFS shares: backup_files_nfs.txt"
    echo -e "\t\t\t SMB shares: backup_files_smb.txt\n"
    echo -e "\t\t\t Tape in drive will be used, if no tape in drive first available tape will be used." 
    echo -e "\t\t\t If Tape in drive is unloaded; Check and Load proper tape; then restart backup process." 
    echo -e "\t\t\t After backup Tape will be rewound and prepared for eject (offline)."
    echo -e "\t\t\t Backup log: ${LOG}" 
    echo -e "\n"
    echo -e "`basename $0` -restore [position] [destination_dir]"
    echo -e "\n\t\t\t Restore content from tape into specified directory."
    echo -e "\t\t\t Parameters:"
    echo -e "\t\t\t [position]\t\t The tape is positioned at the beginning of the specified file; check `basename $0` -list"
    echo -e "\t\t\t [destination_dir]\t Path to destination folder; WARNING: Check for disk space!"
    echo -e "\nOther options:"
    echo -e "`basename $0` -rew\t\t rewind tape to beggining."
    echo -e "`basename $0` -stat\t\t show library status; print library drive status and inventory."
    echo -e "`basename $0` -list\t\t show tape content; rewind tape and list full content of the tape. Use redirect to file.."
    echo -e "`basename $0` -off\t\t rewind the tape and put it offline; prepare tape for eject."
    echo -e "`basename $0` -load n\t\t load the tape (optional: specify tape number); prepare tape for backup."
    echo -e "`basename $0` -unload n\t unload the tape (optional: specify position number); if no possition specified tape will be moved to position #7."
    echo -e "`basename $0` -test\t\t run tape write/read verification."
    echo -e "`basename $0` -h\t\t print this help"
    exit 0
}

sendmail_check()
{
	if [[ $(/etc/init.d/sendmail status) =~ 'running' ]];
	then
		: #do nothing
	else
		/etc/init.d/sendmail start 2>&1 | tee -a ${LOG}
	fi
}

report()
{
	case ${1} in
      tape_not_bot)
			echo -e "\nError: Backup terminated; Tape not at beggining or not Online.." 2>&1 | tee -a ${LOG}
			notification="Problem"
            exit_state=2
            ;;
	  tape_unloaded)
			echo -e "\nWarning: Tape in drive is OFFLINE and prepared for eject; Verify and Load proper tape.." 2>&1 | tee -a ${LOG}
			notification="Warning"
            exit_state=1
            ;;
	  tape_loaded_not_ready)
			echo -e "\nError: Backup terminated; Tape in drive and loaded, but not available (check status).." 2>&1 | tee -a ${LOG}
			notification="Problem"
            exit_state=2
            ;;
	  no_tape_to_load)
			echo -e "\nError: Backup terminated; No free tape to load.." 2>&1 | tee -a ${LOG}
            notification="Problem"
            exit_state=2
			;;
	  rew_tape_not_bot)
			echo -e "\nError: Tape rewind failed.." 2>&1 | tee -a ${LOG}
            notification="Problem"
            exit_state=2
            ;;
	  backup_error)
			echo -e "\nError: Backup terminated; Backup process failed; Failed file: ${2}" 2>&1 | tee -a ${LOG}
			notification="Problem"
			exit_state=2
            ;;
	  oversize)
			sendmail_check
			echo -e "\nWarning: Backup size exceeds 95% of Tape capacity (400G).." 2>&1 | tee -a ${LOG}
			echo -e "\nWarning: Backup size exceeds 95% of Tape capacity (400G).." | mail -s "Tape Backup Oversize Report" ${EMAIL}
			;;
	  backup_job)
			echo -e "\nOK: Backup done.." 2>&1 | tee -a ${LOG}
			notification="Success"
			exit_state=0
            ;;
	  missing_dir)
			echo -e "\nError: Backup terminated.." 2>&1 | tee -a ${LOG}
			notification="Problem"
			exit_state=2
			;;
	  restore_no_dir)
			echo -e "\nError: ${2} directory does not exits!" 2>&1 | tee -a ${LOG}
			exit 2
			;;
	  tape_test_error)
			echo -e "\nError: Tape Test Failed" 2>&1 | tee -a ${LOG}
			notification="Problem"
            exit_state=2
			;;
	  missing_test_file)
			echo -e "\nError: Test file ${TAPE_TEST_FILE} is missing.." 2>&1 | tee -a ${LOG}
    	    notification="Problem"
            exit_state=2
			;;
	  missing_test_res_file)
			echo -e "\nError: Restored Test file ${TAPE_TEST_DIR}/${TAPE_TEST_FILE} is missing.." 2>&1 | tee -a ${LOG}
            notification="Problem"
            exit_state=2
            ;;
	  restore_missing_args)
			echo -e "\nError: Missing arguments.."
			print_help
			;;
	esac

	if [ -n "${exit_state}" ];
	then
		sendmail_check
		message=$(cat ${LOG})
		echo "${message}" | mail -s "Tape Backup ${notification} Report" ${EMAIL}
		exit ${exit_state}
	fi
}


attempt_to_load_then_rewind()
{
	echo -e "Loading tape ${TAPE}.." 2>&1 | tee -a ${LOG}
	mt -f ${TAPE} load 2>&1 | tee -a ${LOG}
	rewind
}

rewind()
{
	check_pos=`mt -f ${TAPE} status | egrep -i "(DR_OPEN IM_REP_EN|OFFLINE)"`
	[ -n "${check_pos}" ] && attempt_to_load_then_rewind

	echo -e "Rewinding tape ${TAPE}.." 2>&1 | tee -a ${LOG}
	mt -f ${TAPE} rewind 2>&1 | tee -a ${LOG}

	check_pos=`mt -f ${TAPE} status | grep -i "BOT ONLINE IM_REP_EN"`
    [ -z "${check_pos}" ] && report rew_tape_not_bot
}

offline()
{
	echo -e "Rewinding and preparing for eject tape ${TAPE}.." 2>&1 | tee -a ${LOG}
	mt -f ${TAPE} offline 2>&1 | tee -a ${LOG}
}

get_number_of_files()
{
	mt -f ${TAPE} eod
	files=`mt -f ${TAPE} stat |awk -F'=' '{ if ( $0 ~ "File number=" ) { print $2 }}' |cut -d',' -f1`
	echo "Files on Tape: ${files}" 2>&1 | tee -a ${LOG}
}

show_status()
{
	echo -e "Library status:" 
	mt -f ${TAPE} status
	echo -e "\nLibrary load:"
	/usr/sbin/mtx -f ${DRIVE} status
}

show_content()
{
	i=0
	#get_number_of_files
	rewind

	while true;
	do
		echo -e "\n\n*** Content of Tape file# ${i} ***"
		dd if=${TAPE} |openssl des3 -d -salt -k "${PASSWD}" | tar ztPf - || break;
		i=$((i+1));
	done

	echo -e "\n"
	rewind
}

restore_dir()
{
	mt -f ${TAPE} asf ${1}
	if [ $? -eq 0 ];
	then
		echo "Destination directory: ${2}"
		[ -d "${2}" ] && cd ${2} || report restore_no_dir
		dd if=${TAPE} |openssl des3 -d -salt -k "${PASSWD}" | tar zxfv -
		rewind
	else
		echo "Tape positioning failed! Exiting.." 2>&1 | tee -a ${LOG}
		exit 2
	fi
}

load_tape()
{
	if [ -z "${1}" ];
	then
		echo "No Tape number specified; Attempting to load tape in drive.." 2>&1 | tee -a ${LOG}
		/usr/sbin/mtx -f ${DRIVE} load 2>&1 | tee -a ${LOG}
	else
		echo "Loading Tape #${1} into drive.." 2>&1 | tee -a ${LOG}
		/usr/sbin/mtx -f ${DRIVE} load ${1} 2>&1 | tee -a ${LOG}
	fi
	
	# Rewinding loaded tape
	rewind
}

unload_tape()
{
	echo "Unloading Tape from drive into position #7." 2>&1 | tee -a ${LOG}
	/usr/sbin/mtx -f ${DRIVE} unload ${1} 2>&1 | tee -a ${LOG}
}


load_first_available()
{
  echo "Attempting to load first available OFFSITE Tape.." 2>&1 | tee -a ${LOG}
  for i in {1..8..1};
  do
    full=`/usr/sbin/mtx -f ${DRIVE} status |grep "Storage Element ${i}:Full" |grep "OFFSITE"`
    [ -n "${full}" ] && tape_to_load=${i} && break
  done

  [ -z "${tape_to_load}" ] && report no_tape_to_load || load_tape ${tape_to_load}
}

check_barcode()
{
	in_drive=`/usr/sbin/mtx -f ${DRIVE} status |grep "Data Transfer Element 0:Full"`
	barcode=`echo "${in_drive}" |awk -F'=' '{ if ( $0 ~ "VolumeTag" ) { print $NF }}'`
	if [[ ${barcode} =~ 'OFFSITE' ]];
	then
		echo "Tape Barcode: ${barcode}" 2>&1 | tee -a ${LOG} 
	else
		load_first_available
		check_barcode
	fi
}

prepare_tape()
{
	check_pos=`mt -f ${TAPE} status | egrep -i "(DR_OPEN IM_REP_EN|OFFLINE)"`
    if [ -n "${check_pos}" ];
	then
		empty=`/usr/sbin/mtx -f ${DRIVE} status |grep "Data Transfer Element 0:Empty"`
		if [ -n "${empty}" ];
		then
			load_first_available
			prepare_tape
		else
	 		report tape_unloaded
		fi
	else
		in_drive=`/usr/sbin/mtx -f ${DRIVE} status |grep "Data Transfer Element 0:Full" |egrep -iv "(unknown|fail|err)"`
		if [ -n "${in_drive}" ];
        then
			check_barcode
			echo "Tape is ready in Drive.." 2>&1 | tee -a ${LOG}
			rewind
		else
			report tape_loaded_not_ready
		fi
	fi
}


verify_nfs_dirs()
{
	local s=0
	for dir in ${NFS_FILES}
	do
		if [ ! -e ${dir} ];
		then
			message+=$(echo -e "\nNFS Error: ${dir} file/directory does not exits!")
			echo "NFS Error: ${dir} file/directory does not exits!" 2>&1
			s=1 # found missing dir
		fi;
	done

	if [ ${s} -eq 1 ];
	then
		echo "$message" >> ${LOG}
		report missing_dir
	fi
}

verify_smb_dirs()
{
    local s=0
	echo "${SMB_FILES}" | while read line; 
    do
        dir=$(echo "${line}" |cut -d' ' -f2)
        if [ ! -e ${dir} ];
        then
            message+=$(echo -e "\nSMB Error: ${dir} file/directory does not exits!")
            echo "SMB Error: ${dir} file/directory does not exits!" 2>&1
            s=1 # found missing dir
        fi;
    done

    if [ ${s} -eq 1 ];
    then
        echo "$message" >> ${LOG}
        report missing_dir
    fi
}

run_tape_test()
{
	[ ! -d "${TAPE_TEST_DIR}" ] && mkdir -p ${TAPE_TEST_DIR}

	prepare_tape
	check_pos=`mt -f ${TAPE} status | grep -i "BOT ONLINE IM_REP_EN"`
    [ -z "${check_pos}" ] && report tape_not_bot

	[ ! -e "${TAPE_TEST_FILE}" ] && report missing_test_file
	echo "Starting Tape Write Test.." 2>&1 | tee -a ${LOG}
    tar zcPf - ${TAPE_TEST_FILE} | openssl des3 -salt -k "${PASSWD}" | dd of=${TAPE} 2>&1 | tee ${OPERLOG}

    # Simple error detection
    if_err=`cat ${OPERLOG} | egrep -i "(err|fail|crit|warn)"`
    [ -n "$if_err" ] && cat ${OPERLOG} | tee -a ${LOG} && report tape_test_error

	echo "Starting Tape Read Test.." 2>&1 | tee -a ${LOG}
	restore_dir 0 ${TAPE_TEST_DIR}

	echo "Checking md5sum of test file.." 2>&1 | tee -a ${LOG}
	CHECK_SUM=`md5sum ${TAPE_TEST_DIR}/${TAPE_TEST_FILE} | cut -d' ' -f1`
	if [ -n "${CHECK_SUM}" ] && [[ "${CHECK_SUM}" == "${TAPE_TEST_SUM}" ]];
	then
		echo "OK: Tape test passed.." 2>&1 | tee -a ${LOG}

		if [ -e "${TAPE_TEST_DIR}/${TAPE_TEST_FILE}" ];
		then
			find ${TAPE_TEST_DIR} -maxdepth 0 -type d -atime 0 -exec rm -rf {} \; 2>>${LOG}
		else
			report missing_test_res_file
		fi
	else
		echo "Calculated TAPE_TEST_SUM=${TAPE_TEST_SUM} is not correct.." 2>&1 | tee -a ${LOG}
		report tape_test_error
	fi
}

show_snapshots()
{
echo "Setting up cifs.show_snapshot on.." 2>&1

for netapp in '192.168.2.16' '192.168.2.17';
do
/usr/bin/expect <<!
	set timeout -1
	set stty_init -echo

	spawn ssh -t ${netapp} -l tape_backup "options cifs.show_snapshot on"
	match_max 100000
	expect "*?assword:*"
	send -- "CQbvVsveKsU52\r"
	stty echo
expect
!
done
}

hide_snapshots()
{
echo "Setting up cifs.show_snapshot off.." 2>&1

for netapp in '192.168.2.16' '192.168.2.17';
do
/usr/bin/expect <<!
        set timeout -1
        set stty_init -echo

        spawn ssh -t ${netapp} -l tape_backup "options cifs.show_snapshot off"
        match_max 100000
        expect "*?assword:*"
        send -- "CQbvVsveKsU52\r"
        stty echo
expect
!
done
}

mount_cifs()
{
	echo "${SMB_MOUNT}" | while read line;
	do
		mpoint=$(echo "${line}" |cut -d' ' -f2 |cut -d'/' -f1-5)
		cifs=$(echo "${line}" |cut -d' ' -f1)

		mount -t cifs ${cifs} ${mpoint} -o ro,username=${CIFS_USER},password=${CIFS_PASSWD} 2>>${LOG}
	done
	show_snapshots
}

umount_cifs()
{
	echo "${SMB_MOUNT}" | while read line;
	do
		mpoint=$(echo "${line}" |cut -d' ' -f2 |cut -d'/' -f1-5)
		umount ${mpoint} 2>>${LOG}
	done
	hide_snapshots
}

run_backup()
{
	echo "Staring Backup @ `date`" 2>&1 | tee -a ${LOG}

	verify_nfs_dirs
	run_tape_test
	rewind
	#prepare_tape

	check_pos=`mt -f ${TAPE} status | grep -i "BOT ONLINE IM_REP_EN"`
	[ -z "${check_pos}" ] && report tape_not_bot

	echo "Starting NFS backup.." 2>&1 | tee -a ${LOG}
	for file in ${NFS_FILES};
	do
	    echo -e "Position on Tape #${pos}; NFS Files: ${file}" 2>&1 | tee -a ${LOG}
	    tar zcPf - ${file} | openssl des3 -salt -k "${PASSWD}" | dd of=${TAPE} 2>&1 | tee ${OPERLOG}
	    results=`cat ${OPERLOG}`

	    # Simple error detection
	    if_err=$(echo "${results}" | egrep -i "(err|fail|crit|warn)")
	    [ -n "${if_err}" ] && report backup_error ${file}

	    size=$(echo "${results}" |awk '{ if ( $0 ~ "copied" ) { print $1 }}')
        transfer=$(echo "${results}" |awk '{ if ( $0 ~ "copied" ) { print $3 $4", "$6 $7" "$8 $9 }}')
        echo -e "Transfered: ${transfer}\n" | tee -a ${LOG}

	    total_nfs=$(echo "scale=0; ${total_nfs} + ${size}" | bc)
	    pos=$((pos+1))
	done

	mount_cifs
	verify_smb_dirs

	echo "Starting CIFS backup.." 2>&1 | tee -a ${LOG}
	for file in $(echo "${SMB_FILES}" |cut -d' ' -f2);
	do
        echo -e "Position on Tape #${pos}; CIFS Files: ${file}" 2>&1 | tee -a ${LOG}
	    tar zcPf - ${file} | openssl des3 -salt -k "${PASSWD}" | dd of=${TAPE} 2>&1 | tee ${OPERLOG}
	    results=`cat ${OPERLOG}`

	    # Simple error detection
        if_err=$(echo "${results}" | egrep -i "(err|fail|crit|warn)")
        if [ -n "${if_err}" ];
	    then
	        umount_cifs
	        report backup_error ${file}
	    fi

	    size=$(echo "${results}" |awk '{ if ( $0 ~ "copied" ) { print $1 }}')
        transfer=$(echo "${results}" |awk '{ if ( $0 ~ "copied" ) { print $3 $4", "$6 $7" "$8 $9 }}')
        echo -e "Transfered: ${transfer}\n" | tee -a ${LOG}

	    total_smb=$(echo "scale=0; ${total_smb} + ${size}" | bc)
        pos=$((pos+1))
    done

	total=$(echo "scale=0; ${total_nfs} + ${total_smb}" | bc)
	size_calc=$(echo "scale=0; ${total} / 1000000" | bc)

	if [ ${size_calc} -gt 1000 ];
	then
	    	size_calc=$(echo "scale=1; ${size_calc} / 1000" | bc)
	    	unit="GB"
	else 
	    	unit="MB"
	fi

	echo "Backup finished @ `date`" 2>&1 | tee -a ${LOG}
	echo "Backup size: ${total} bytes (${size_calc} ${unit})" 2>&1 | tee -a ${LOG}

	umount_cifs

	[ ${total} -gt 380000000000 ] && report oversize
	
	rewind
	offline
	report backup_job
}


##
## BEGIN
##
[ -z "${ARG}" ] && print_help

case ${ARG} in
	-h)
	    print_help
	    ;;
    --help)
        print_help
        ;;
	-list)  # show tape content
	    show_content
	    ;;
	-stat)  # show TBU status
	    show_status
	    ;;
	-backup)  # run full backup
	    echo -e "Executing backup.."
	    run_backup
	    ;;
	-restore)  # restore dir to current dir
	    [ -z "${2}" ] || [ -z "${3}" ] && report restore_missing_args
	    echo -e "Restoring content from position #${2}.. "
	    restore_dir ${2} ${3}
	    ;;
	-rew) # rewind tape
	    rewind
	    ;;
	-off) # put tape offline and prepare for eject
	    offline
	    ;;
	-load) #load the tape
	    load_tape ${2}
	    ;;
	-unload) #unload the tape (move to position #7)
	    unload_tape ${2}
	    ;;
	-test) #Test Tape
	    run_tape_test
	    ;;
	-snapon) #Test snapon
	    show_snapshots
	    ;;
	-snapoff) #Test snapoff
        hide_snapshots
        ;;
	*)
	    print_help
	    ;;
esac

# Normal exit from script
exit 0
