#!/bin/bash
#
# Plugin name: stats_snmp_interfaces64_cumulative.sh
# Description: This plugin performs operations on SNMP (ver.2c only, RFC1213(IF-MIB), 32/64-bit counter) metrics to calculate cumulative speed of network interfaces.
#	       This version gives as a results summaric ${NET_DEVICE} internet speed as volume of information that is sent over a connection
#              in a measured amount of time presented in G|M|K bits per secend (bps).
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
test='no'
time_now=`date +%s`
DATADIR='/var/lib/centreon/metrics-interfaces'
STRING32='1.3.6.1.2.1.2.2.1'
STRING64='ifMIB.ifMIBObjects.ifXTable.ifXEntry'
WALK='/usr/bin/snmpwalk'
PROGRAM=${0##*/}
PROGPATH=${0%/*}

##
## Define networking device name and interfaces description, plus specify all interfaces which should be counted, separated by space.
##
DEVICE="Catalyst_2960-L-SM-24TQ_Rack1_Switch1"
INTERFACES="1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24"
INTERFACES_DESC="g1-g24"

##
## Function fullusage()
##
fullusage() {
cat <<EOF

PROGRAM:
${PROGRAM}

DESCRIPTION:
This plugin calculate cumulative statistics of internet speed for all {NET_DEVICE} specified interfaces.
Script during first two executions is creating buffers with metrics for cumulation (allow two dry executions).

DATADIR (buffer files location):        ${DATADIR}
NET_DEVICE:                             ${DEVICE}
INTERFACES FOR CALCULATIONS:            ${INTERFACES}
INTERFACES_DESC:                        ${INTERFACES_DESC}

INFO: To display all available {NET_DEVICE} interfaces for measurement (useful) please use plugin with --display flag.

USAGE: 
${PROGRAM} -h|--help | -D|--debug | -d | --display | [-ip <address>] | [-x <counter>] | [-C <community>] | [-s|-is <speed>] | [-w <warning>] | [-c <critical>] | [-sev <severity>]

OPTION:
-h | --help             Print detailed help
-d | --display          Display all interfaces
-D | --debug            Debug interfaces (yes|no)
-ip                     NET_DEVICE address to check
-x                      Counter (32|64), default is 64.
-s | -is                Interfaces Speed (15G|10G|8G|4G|G|100M|10M|1M)
-w                      Interfaces usage warning (% cumulative usage sum)
-c                      Interfaces usage critical (% cumulative usage sum)
-C                      SNMP Community string (ver.2c)
-sev                    Severity, exit status depends on Interface status, eg. unreachable/faulty (WARN|CRIT)

Examples of usage:
stats_snmp_interfaces64_cumulative.sh -ip 192.168.1.1 -C community_string --display
stats_snmp_interfaces64_cumulative.sh -ip 192.168.1.1 -C community_string -s G -x 32 -D yes
stats_snmp_interfaces64_cumulative.sh -ip 192.168.1.1 -C community_string -s G -x 64 -sev WARN
stats_snmp_interfaces64_cumulative.sh -ip 192.168.1.1 -C community_string -s G -x 64 -w 75 -c 90 -sev CRIT

EOF
}

##
## Function display()
##
display() {

echo "Displaying interfaces for host ${IP}:"

if [ -n "${IP}" ];
then  
        ${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} .1.3.6.1.2.1.31.1.1.1.1  
        echo -e "\n\n"
        echo "Aliases:"
        ${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} .1.3.6.1.2.1.31.1.1.1.18
else
        echo "UNKNOWN, Cannot display interfacess.. exiting!"
        exit -1
fi
}

##
## Function exit_nan_unknown() which exit from plugins with output not available ("NaN").
##
exit_nan_unknown() {
    ## Display results
    echo "UNKNOWN; Interfaces ${INTERFACES_DESC} (${If_speed}) Traffic In:"NaN" b/s ("NaN"%), Out:"NaN" b/s ("NaN"%) - Total RX Bits In:"NaN" b, Out:"NaN" b|traffic_in="NaN"Bits/s traffic_out="NaN"Bits/s"
    exit -1
}

##
## Main program loop, with selection of functionality of plugin.
##
while :
do
        case "$1" in
        -w | --warning) warn=$2; shift 2;;
        -c | --critical)  crit=$2; shift 2;;
        -ip | --address) IP=$2; shift 2;;
        -x | --counter) counter=$2; shift 2;;
        -C | --COMMUNITY) COMMUNITY=$2; shift 2;;
        -s | -is | --speed ) speed=$2; shift 2;;
        -D | --debug) test=$2; shift 2;;
	-d | --display) display; exit;;
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

## Debug
if [[ "${test}" == "yes" ]];
then
    echo "Debugging enabled.."
fi

[[ -z "$IP" ]] && echo "UNKNOWN IP is not specified.." && exit -1
[[ -z "$counter" ]] && counter=64
[[ -z "$speed" ]] && echo "UNKNOWN Interface is not specified.." && exit -1
[[ -z "$COMMUNITY" ]] && echo "UNKNOWN SNMP Community is not specified.." && exit -1
[[ -z "$warn" ]] && warn=80
[[ -z "$crit" ]] && crit=90
[[ -z "$SEVERITY" ]] && SEVERITY=CRIT

##
## Speed factor calculation
##
if [[ "${speed}" == "15G" ]];
then
        factor=16106127360
        If_speed=15Gb
elif [[ "${speed}" == "10G" ]];
then
        factor=10737418240
        If_speed=10Gb
elif [[ "${speed}" == "8G" ]];
then
        factor=8589934592
        If_speed=8Gb
elif [[ "${speed}" == "4G" ]];
then
        factor=4294967296
        If_speed=4Gb
elif [[ "${speed}" == "G" ]] || [[ "${speed}" == "1G" ]];
then
        factor=1073741824
        If_speed=1Gb
elif [[ "${speed}" == "100M" ]];
then
        factor=104857600
        If_speed=100Mb
elif [[ "${speed}" == "M" ]] || [[ "${speed}" == "1M" ]];
then
        factor=1048576
        If_speed=1Mb
elif [[ "${speed}" == "10M" ]];
then
        factor=10485760
        If_speed=10Mb
fi

## 
## Function calculate_traffic()
##
calculate_traffic()
{
        total=0
        last_IfinBits=0
        last_IfOutBits=0
        file="${DATADIR}/check_snmp_interfaces64_${If}_${DEVICE}"

        # Debug
        if [[ "${test}" == "yes" ]];
        then
                echo "Debug: File: ${DATADIR}/check_snmp_interfaces64_${If}_${DEVICE}"
        fi

        if [ -e "$file" ]; 
        then
                buffer_init=`grep "buffer_init" ${file}`
                if [ -z ${buffer_init} ];
                then
                        last_time=`cat "${file}" |cut -d":" -f1`
                        last_IfinBits=`cat "${file}" |cut -d":" -f2`
                        last_IfOutBits=`cat "${file}" |cut -d":" -f3`
						Ifflg_file=0
                        Ifflg_created=0
                        echo "${time_now}:${IfinBits}:${IfOutBits}" > ${file}
                else
                        last_time=`cat "${file}" |cut -d":" -f1`
                        last_IfinBits=`cat "${file}" |cut -d":" -f2`
                        last_IfOutBits=`cat "${file}" |cut -d":" -f3`
						Ifflg_created=1
                        echo "${time_now}:${IfinBits}:${IfOutBits}" > ${file}
                        echo "UNKNOWN First execution : Buffer created.... "
                        #exit 3
                fi
        else
		## First execution and creation of {file}
		Ifflg_file=1
                echo "${time_now}:${last_IfinBits}:${last_IfOutBits}:buffer_init" > ${file}
                echo "UNKNOWN First execution : Buffer in creation.... "
                #exit 3
        fi

        ## Debug
        if [[ "${test}" == "yes" ]];
        then
	    echo "Debug: Interface ${If} IfinBits=${IfinBits} IfOutBits=${IfOutBits} Ifflg_created=${Ifflg_created}"
            echo "Debug: Interface ${If} Time:${time_now} Last_IfinBits:${last_IfinBits} Last_IfOutBits:${last_IfOutBits}"
        fi

	if [ ${Ifflg_created} -eq 0 ] && [ ${Ifflg_file} -eq 0 ];
	then

        diff_IfinBits=`expr ${IfinBits} - ${last_IfinBits}`
        diff_IfOutBits=`expr ${IfOutBits} - ${last_IfOutBits}`
        diff_time=`expr ${time_now} - ${last_time}`

        if [ ${diff_IfinBits} -ne 0 ] && [ -n "${last_IfinBits}" ];
        then
                if [ ${diff_IfinBits} -lt 0 ] && [ ${counter} -eq 64 ]; 
                then
                        total=`expr 18446744073709551615 - ${last_IfinBits}`
                        total=`expr ${total} + ${IfinBits}`
                        Ifin_traffic=`expr ${total} / ${diff_time}`

                elif [ ${diff_IfinBits} -lt 0 ] && [ ${counter} -eq 32 ];
                then
                        total=`expr 4294967295 - ${last_IfinBits}`
                        total=`expr ${total} + ${IfinBits}`
                        Ifin_traffic=`expr ${total} / ${diff_time}`
                else 
                        total=${diff_IfinBits}
                        [ ${diff_time} -eq 0 2>/dev/null ] && diff_time=1
                        Ifin_traffic=`expr ${total} / ${diff_time}`
                fi

                [ ${Ifin_traffic} -gt ${factor} ] && Ifin_traffic=NaN

        elif [ ${diff_IfinBits} -eq 0 2>/dev/null ];
        then
                Ifin_traffic=0
        else 
                Ifin_traffic=NaN
        fi

        # Debug
        if [[ "${test}" == "yes" ]];
        then
                echo "Debug: Interface ${If} diff_IfinBits=${diff_IfinBits} total=${total} Ifin_traffic=${Ifin_traffic} counter=${counter}"
        fi

        if [ ${diff_IfOutBits} -ne 0 ] && [ -n "${last_IfOutBits}" ];
        then
                if [ ${diff_IfOutBits} -lt 0 ] && [ ${counter} -eq 64 ]; 
                then
                        total=`expr 18446744073709551615 - ${last_IfOutBits}`
                        total=`expr ${total} + ${IfOutBits}`
                        IfOut_traffic=`expr ${total} / ${diff_time}`
                elif [ ${diff_IfOutBits} -lt 0 ] && [ ${counter} -eq 32 ];
                then
                        total=`expr 4294967295 - ${last_IfOutBits}`
                        total=`expr ${total} + ${IfOutBits}`
                        IfOut_traffic=`expr ${total} / ${diff_time}`
                else 
                        total=${diff_IfOutBits}
                        [ ${diff_time} -eq 0 ] && diff_time=1
                        IfOut_traffic=`expr ${total} / ${diff_time}`
                fi

                [ ${IfOut_traffic} -gt ${factor} ] && IfOut_traffic=NaN
        
        elif [ ${diff_IfOutBits} -eq 0 2>/dev/null ];
        then
                IfOut_traffic=0
        else 
                IfOut_traffic=NaN
        fi

        # Debug
        if [[ "${test}" == "yes" ]];
        then
            echo "Dubug: Interface ${If} diff_IfOutBits=${diff_IfOutBits} total=${total} IfOut_traffic=${IfOut_traffic} counter=${counter}"
        fi

	## Exit if NaN result
        if [[ "${Ifin_traffic}" == "NaN" ]] || [[ "${IfOut_traffic}" == "NaN" ]];
        then
            if [[ "${test}" == "yes" ]];
            then
                echo "Exiting; exit_nan_unknown exception.. Interface ${If} factor=${factor} Ifin_traffic=${Ifin_traffic} IfOut_traffic=${IfOut_traffic}"
            fi
            exit_nan_unknown
        fi

	##
	## Sum traffic and write to _summary_ buffer
	##
	sum_file="${DATADIR}/check_snmp_interfaces64_summary_"${DEVICE}"_"${INTERFACES_DESC}""

	if [ -e "${sum_file}" ];
        then
		if [ ${Ifflg_created} -eq 0 ];
		then
			last_sum_time=`cat "${sum_file}" |cut -d":" -f1`
                        last_sum_Ifin_traffic=`cat "${sum_file}" |cut -d":" -f2`
                        last_sum_IfOut_traffic=`cat "${sum_file}" |cut -d":" -f3`

			diff_sum_Ifin_traffic=`expr ${last_sum_Ifin_traffic} + ${Ifin_traffic}`
        	        diff_sum_IfOut_traffic=`expr ${last_sum_IfOut_traffic} + ${IfOut_traffic}`
		fi
		echo "${last_sum_time}:${diff_sum_Ifin_traffic}:${diff_sum_IfOut_traffic}" > ${sum_file}
	else
            echo "${time_now}:${Ifin_traffic}:${IfOut_traffic}" > ${sum_file}
        fi

	## Debug
        if [[ "${test}" == "yes" ]];
        then
			echo "Debug: sum_file ${sum_file}"
			echo "Debug: last_sum_time=${last_sum_time}; last_sum_Ifin_traffic=${last_sum_Ifin_traffic}; last_sum_IfOut_traffic=${last_sum_IfOut_traffic}"
			echo "Debug: Ifin_traffic=${Ifin_traffic}; IfOut_traffic=${IfOut_traffic}"
			echo "Debug: diff_sum_Ifin_traffic=${diff_sum_Ifin_traffic}; diff_sum_IfOut_traffic=${diff_sum_IfOut_traffic}"
			echo "====="
        fi

	fi
}
##
## END of calculate_traffic()
##

##
## Interfaces check (perform Interfaces state check and write results into output files)
##

for If in ${INTERFACES}; do

## Debug
if [[ "${test}" == "yes" ]];
then
    echo "TEST: Checking Interface: ${If} If_speed=${If_speed}"
fi

if [ ${If} -eq ${If} 2>/dev/null ];
then
	:
elif [[ "${If}" =~ ^(eth|bond)* ]];
then
        If=`${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} 1.3.6.1.2.1.2.2.1.2 |awk '{ if ( $0 ~ '"/STRING: ${If}/"' ) { print $1 }}' |cut -d'.' -f2`
        [[ "${If}" == "" ]] && echo "UNKNOWN Interface ${If} is not specified or not exist.." && exit -1
else
        If=`${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} 1.3.6.1.2.1.2.2.1.2 |awk '{ if ( $0 ~ '"/STRING: ${If}/"' ) { print $1 }}' |awk -F'.' '{ print $NF }'`
        If_desc=`${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} 1.3.6.1.2.1.2.2.1.2 |awk '{ if ( $0 ~ '"/ifDescr.${If} /"' ) { print $NF }}'`
        [ -z "${If_desc}" ] || [[ ${$If_desc} == "" ]] && If_desc=${If}
fi

##
## State of Interface
##
up=0; down=0
state_if=`${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} 1.3.6.1.2.1.2.2.1.8.$If | awk '{ print $4 }'`

# Debug
if [[ "${test}" == "yes" ]];
then
    echo "Debug: Interface ${If} status: ${state_if}"
fi

case $state_if in
        *"up"* )
        up=$((up+1))
        ;;
        *"active"* )
        up=$((up+1))
        ;;
        *"down"* )
		down=$((down+1))
        ;;
        *"testing"* )
		down=$((down+1))
        ;;
        *"unknown"* )
		down=$((down+1))
        ;;
        *"dormant"* )
		down=$((down+1))
        ;;
        *"notPresent"* )
		down=$((down+1))
        ;;
        *"notInService"* )
		down=$((down+1))
        ;;
        *"destroy"* )
		down=$((down+1))
        ;;
        *"lowerLayerDown"* )
		down=$((down+1))
        ;;
        *)
		down=$((down+1))
        ;;
esac


IfSpeed="${factor}"

if [ ${up} -eq 1 2>/dev/null ]; 
then
        if [ ${counter} -eq 32 ];
        then
            ## Counter32
            IfinOctets=`${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} 1.3.6.1.2.1.2.2.1.10.$If |awk '{ if ( $1 ~ 'Counter32' ) { print $NF }}'`
            IfOutOctets=`${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} 1.3.6.1.2.1.2.2.1.16.$If |awk '{ if ( $1 ~ 'Counter32' ) { print $NF }}'`
        elif [ ${counter} -eq 64 ];
        then
            ## Counter64
            IfinOctets=`${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} ifMIB.ifMIBObjects.ifXTable.ifXEntry.ifHCInOctets.${If} |awk '{ if ( $1 ~ 'Counter64' ) { print $NF }}'`
            IfOutOctets=`${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} ifMIB.ifMIBObjects.ifXTable.ifXEntry.ifHCOutOctets.${If} |awk '{ if ( $1 ~ 'Counter64' ) { print $NF }}'`
        fi

        [ -z "${IfinOctets}" ] || [ -z "${IfOutOctets}" ] && echo "UNKNOWN SNMP Timeout or No Response from $IP.." && exit -1

	[ ${IfinOctets} -eq 0 2>/dev/null ] && IfinBits=0 || IfinBits=`expr ${IfinOctets} \* 8`
        [ ${IfOutOctets} -eq 0 2>/dev/null ] && IfOutBits=0 || IfOutBits=`expr ${IfOutOctets} \* 8`

elif [ ${down} -eq 1 2>/dev/null ];
then
        if [ ${counter} -eq 32 ];
        then
            ## Counter32
            IfinOctets=`${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} 1.3.6.1.2.1.2.2.1.10.${If} |awk '{ if ( $1 ~ 'Counter32' ) { print $NF }}'`
            IfOutOctets=`${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} 1.3.6.1.2.1.2.2.1.16.${If} |awk '{ if ( $1 ~ 'Counter32' ) { print $NF }}'`
        elif [ ${counter} -eq 64 ];
        then
            ## Counter64
            IfinOctets=`${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} ifMIB.ifMIBObjects.ifXTable.ifXEntry.ifHCInOctets.${If} |awk '{ if ( $1 ~ 'Counter64' ) { print $NF }}'`
            IfOutOctets=`${WALK} -v 2c -t 5 -r 2 -c ${COMMUNITY} ${IP} ifMIB.ifMIBObjects.ifXTable.ifXEntry.ifHCOutOctets.${If} |awk '{ if ( $1 ~ 'Counter64' ) { print $NF }}'`
        fi

        [ -z "${IfinOctets}" ] || [ -z "${IfOutOctets}" ] && echo "UNKNOWN SNMP Timeout or No Response from $IP.." && exit -1

        IfinBits=0
        IfOutBits=0
fi

## Debug
if [[ "${test}" == "yes" ]];
then
    echo "Debug: Octects recalculation: Interface ${If} IfSpeed=${IfSpeed} IfinOctets=${IfinOctets} IfOutOctets=${IfOutOctets} IfinBits=${IfinBits} IfOutBits=${IfOutBits}"
fi

##
## Invoke calculate_trafic
##
if [ ${down} -eq 1 2>/dev/null ];
then
    file="${DATADIR}/check_snmp_interfaces64_${If}_${DEVICE}"
    echo "${time_now}:${IfinOctets}:${IfOutOctets}" > ${file}
    Ifflg_file=0
    Ifflg_created=0

elif [ ${up} -eq 1 2>/dev/null ];
then
    calculate_traffic
else
    "UNKNOWN; Cumulative bandwidth of ${DEVICE} interfaces ${INTERFACES_DESC}: (Max_throughput:${If_speed}); Unknown status of interface ${If}."
    exit -1
fi

done
##
## END of Interfaces Check
##

## 
## Recalculate all traffic
##
recalculate_all_traffic()
{
if [ ${Ifflg_created} -eq 0 ] && [ ${Ifflg_file} -eq 0 ];
then
	sum_file="${DATADIR}/check_snmp_interfaces64_summary_"${DEVICE}"_"${INTERFACES_DESC}""
	sum_Ifin_traffic=`cat "${sum_file}" |cut -d":" -f2`
	sum_IfOut_traffic=`cat "${sum_file}" |cut -d":" -f3`
	
	##
	## Calculate traffic usage in %
	##
        if [ ${IfSpeed} -ne 0 ];
        then
                Ifin_usage=`expr ${sum_Ifin_traffic} \* 100 / ${IfSpeed}`
                IfOut_usage=`expr ${sum_IfOut_traffic} \* 100 / ${IfSpeed}`
        else
                echo "UNKNOWN Interfaces ${INTERFACES} IfSpeed=${IfSpeed}; Cannot calculate Ifusage"
                exit -1
        fi

        ## Debug
        if [[ "${test}" == "yes" ]];
        then
                echo "Debug: Interfaces ${INTERFACES} IfSpeed=${IfSpeed} Ifin_usage=${Ifin_usage} IfOut_usage=${IfOut_usage}"
        fi

        ## For Graphs
	Ifin_traffic=${sum_Ifin_traffic}
	IfOut_traffic=${sum_IfOut_traffic}
        Ifin_traffic_graph=${Ifin_traffic}
        IfOut_traffic_graph=${IfOut_traffic}

        if [ ${Ifin_traffic} -gt 1000 ];
        then
                Ifin_traffic=`expr ${Ifin_traffic} / 1000`
                Ifin_prefix="k"

                if [ ${Ifin_traffic} -gt 1000 ];
                then
                        Ifin_traffic=`expr ${Ifin_traffic} / 1000`
                        Ifin_prefix="M"
                fi

                if [ ${Ifin_traffic} -gt 1000 ];
                then
                        Ifin_traffic=`expr ${Ifin_traffic} / 1000`
                        Ifin_prefix="G"
                fi
        fi

        if [ ${IfOut_traffic} -gt 1000 ];
        then
                IfOut_traffic=`expr ${IfOut_traffic} / 1000`
                IfOut_prefix="k"

                if [ ${IfOut_traffic} -gt 1000 ];
                then
                        IfOut_traffic=`expr ${IfOut_traffic} / 1000`
                        IfOut_prefix="M"
                fi

                if [ ${IfOut_traffic} -gt 1000 ];
                then
                        IfOut_traffic=`expr ${IfOut_traffic} / 1000`
                        IfOut_prefix="G"
                fi
        fi

        IfinBits_unit=""
        IfinBits=`expr ${IfinBits} / 1048576`
        if [ ${IfinBits} -gt 1000 ];
        then
                IfinBits=`expr ${IfinBits} / 1000`
                IfinBits_unit="G"
        else 
            IfinBits_unit="M"
        fi

        IfOutBits_unit=""
        IfOutBits=`expr ${IfOutBits} / 1048576`
        if [ ${IfOutBits} -gt 1000 ];
        then
                IfOutBits=`expr ${IfOutBits} / 1000`
                IfOutBits_unit="G"
        else
            IfOutBits_unit="M"
        fi
fi
}

reset_sum_file()
{
	sum_file="${DATADIR}/check_snmp_interfaces64_summary_"${DEVICE}"_"${INTERFACES_DESC}""
	time_now=`date +%s`
	echo "${time_now}:0:0" > ${sum_file}
}

display_results()
{
if [ ${Ifflg_created} -eq 0 ] && [ ${Ifflg_file} -eq 0 ];
then
        status="OK"
        exit_code=0

        if [ ${Ifin_usage} -gt ${warn} ] || [ ${IfOut_usage} -gt ${warn} ];
        then 
                status="WARNING"
                exit_code=1
        fi

        if [ ${Ifin_usage} -gt ${crit} ] || [ ${IfOut_usage} -gt ${crit} ];
        then

                if [[ "${SEVERITY}" =~ "CRIT" ]];
                then
                        status="CRITICAL"
                        exit_code=2

                elif [[ "${SEVERITY}" =~ "WARN" ]];
                then
                        status="WARNING"
                        exit_code=1
                fi
        fi

        traffic_in=${Ifin_traffic_graph}
        traffic_out=${IfOut_traffic_graph}
fi

##
## Display results
##
if [ ${Ifflg_created} -eq 0 ] && [ ${Ifflg_file} -eq 0 ];
then
       	echo "${status} :: Cumulative bandwidth of ${DEVICE} interfaces ${INTERFACES_DESC}: (Max_throughput:${If_speed}) Traffic In:"${Ifin_traffic}" "${Ifin_prefix}"b/s ("${Ifin_usage}"%), Out:"${IfOut_traffic}" "${IfOut_prefix}"b/s ("${IfOut_usage}"%) |traffic_in="${traffic_in}"Bits/s traffic_out="${traffic_out}"Bits/s"
	reset_sum_file
       	exit ${exit_code}
else
	echo "UNKNOWN; Cumulative bandwidth of ${DEVICE} interfaces ${INTERFACES_DESC}: (Max_throughput:${If_speed}) statistics buffered during first execution.."
	exit -1
fi
}
##
## END of display_results()
##
recalculate_all_traffic
display_results

exit 0


