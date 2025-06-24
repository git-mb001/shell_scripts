#!/bin/bash
#
# Plugin name: stats_cpu_utilization_percore.sh
# Description: This plugin performs numeric calculations with per-core CPU metrics.
#              Self detects number of cores and sum amount of cpu per-core extracted data.
#
# Last updated: 2025/06/07  
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
This plugin performs numeric calculations with per-core CPU metrics.
Self detects number of cores and sum amount of cpu per-core extracted data.

USAGE: 
${PROGRAM} [-h|--help] | [-m|--max_cores]  

OPTION:
-h | --help            Print detailed help
-m | --max_cores       Set maximum number of cores; this value can be larger then actual number of cores, but shouldn't be lower (default is 100).

EOF
}

##
## Main program loop, with selection of functionality of plugin.
##
while :
do
        case "$1" in
            -m | --max_cores) max_cores=$2; shift 2;;
            -h | --help) fullusage; exit;;
            --) ## End of all options
              shift;
              break;;
            -*) echo "Error: Unknown option: $1"
              exit 1;;
            *) ## No more options;
              break;;
        esac
done

##
## Checking if max_cores has been setup.
##
if [[ ${max_cores} == "" ]] | [ -z ${max_cores} ];
then
    max_cores=100
    fullusage
    echo "Info: Unable to read max_cores initial variable, so used default one (max_cores=100)"
fi

##
## Function get_cpu_stats() to parse /proc/stat and extract per-core metrics and extracts the 
## user, nice, system, idle, iowait, irq, and softirq values to show it summarized for each core.
##
get_cpu_stats() {

    if ! grep '^cpu[0-'${max_cores}']' /proc/stat &>/dev/null; 
    then
        echo "Error: Unable to read CPU stats from /proc/stat; Use root/sudo to access /proc filesystem; Exiting."
        exit 2
    fi

    grep '^cpu[0-'${max_cores}']' /proc/stat |
    while read -r line; do
        core=$(echo "${line}" | awk '{print $1}')
        user=$(echo "${line}" | awk '{print $2}')
        nice=$(echo "${line}" | awk '{print $3}')
        system=$(echo "${line}" | awk '{print $4}')
        idle=$(echo "${line}" | awk '{print $5}')
        iowait=$(echo "${line}" | awk '{print $6}')
        irq=$(echo "${line}" | awk '{print $7}')
        softirq=$(echo "${line}" | awk '{print $8}')
        total=$((user + nice + system + idle + iowait + irq + softirq))
        echo "${core} ${user} ${nice} ${system} ${idle} ${total}"
    done
}

##
## Function calculate_cpu_usage() to calculate CPU per-core usage.
## It captures the CPU stats twice, separated by a 1-second interval, then computes the metrics.
##
calculate_cpu_usage() {

    declare -A previous_stats
    declare -A current_stats

    ## Check for initial metrics from /proc/stat 
    if ! get_cpu_stats > /dev/null; then
        echo "Error: Unable to collect initial CPU stats; look for get_cpu_stats function issue; Exiting."
        exit 2
    fi

    while read -r core user nice system idle total; do
        previous_stats[${core}]="${user} ${nice} ${system} ${idle} ${total}"
    done < <(get_cpu_stats)

    ## Pause for 1-second to measure CPU usage over time
    sleep 1

    ## Check for updated metrics from /proc/stat
    if ! get_cpu_stats > /dev/null; then
        echo "Error: Unable to collect updated CPU stats" >&2
        exit 1
    fi

    while read -r core user nice system idle total; do
        current_stats[${core}]="${user} ${nice} ${system} ${idle} ${total}"
    done < <(get_cpu_stats)

    output="OK :: CPU per-core usage: "     ## Summaric output for Nagios
    perf_data=""                            ## Performance data for Nagios

    ## Calculate CPU usage per-core
    for core in "${!current_stats[@]}"; 
    do
        ## Read previous and current stats for each core
        read -r prev_user prev_nice prev_system prev_idle prev_total <<< "${previous_stats[${core}]}"
        read -r curr_user curr_nice curr_system curr_idle curr_total <<< "${current_stats[${core}]}"

        ## Compute differences between the two snapshots
        delta_total=$((curr_total - prev_total))
        delta_idle=$((curr_idle - prev_idle))
        delta_usage=$((delta_total - delta_idle))

        ## Calculate usage percentage
        usage_percent=$(awk "BEGIN {printf \"%.2f\", (${delta_usage} / ${delta_total}) * 100}")

        ## Append the usage data to the output strings
        output+="${core}=${usage_percent}%%, "
        perf_data+="${core}=${usage_percent}%%;;;; "

    done

    ## Trim trailing comma and space from the output strings
    output=${output%, }
    perf_data=${perf_data%, }

    ## Print the Nagios-style output with performance data
    echo "${output} | ${perf_data}"
}

##
## BEGIN :)
## Main script execution which calls the function calculate_cpu_usage() to calculate and display CPU usage stats.
##
calculate_cpu_usage

## 
## END :))
## Exit plugin normally
##
exit 0
