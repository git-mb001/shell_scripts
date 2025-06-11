#!/bin/bash
#
# Plugin name: stats_count_mem_usage_app.sh
# Description: This plugin performs precise count memory usage by app.
#
# Last updated: 2025/06/11  
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
## Initial variables
##
PROGRAM=${0##*/}
PROGPATH=${0%/*}

fullusage() {
cat <<EOF

PROGRAM:
${PROGRAM}

DESCRIPTION:
This plugin performs precise count memory usage by app.

USAGE: 
${PROGRAM} [-h|--help] | [-p|--process_name]  

OPTION:
-h | --help             Print detailed help
-p | --process_name     Specify process/application name

EOF
}

##
## Main program loop, with selection of functionality of plugin.
##
while :
do
        case "${1}" in
		-p | --process_name) max_cores=${2}; shift 2;;
        -h | --help) fullusage; exit;;
        --) ## End of all options
             shift; break;;
        -*) echo "Error: Unknown option: ${1}"
             exit 1;;
         *) ## No more options;
             break;;
        esac
done

## Check if process/app where specified
if [[ "${1}" == "" ]] | [ -z "${1}" ]; then
    echo "Error, Process name is not present.."
    fullusage
    exit 1
fi

## Get the process/app name
PROCESS_NAME="${1}"

## Find and isolate PIDs
PIDS=$(pgrep "${PROCESS_NAME}")

## Check if PIDs where find
if [[ "${PIDS}" == "" ]] | [ -z "${PIDS}" ]; then
    echo "Error, No PIDs found for '${PROCESS_NAME}'.."
    exit 1
fi

## Variable to hold summaric memory
TOTAL_MEMORY=0

## Iteration for found PIDs
for PID in ${PIDS}; do
    ## Read RSS from file /proc/<PID>/status
    MEMORY=$(egrep -i "VmRSS" /proc/"${PID}"/status 2>/dev/null | awk '{print $2}')
    ## Add memory usage to total memory variable
    if [ ! -z "${MEMORY}" ]; then
        TOTAL_MEMORY=$((TOTAL_MEMORY + MEMORY))
    fi
done

# Calculate memory usage in GB
TOTAL_USAGE=$(bc <<< "scale=2; $TOTAL_MEMORY / 1048576")

## Display results
echo -e "OK :: Process '${PROCESS_NAME}' overall is using ${TOTAL_USAGE} GB |total_usage="${TOTAL_USAGE}"GB;;;;"

## Exit plugin normally
exit 0