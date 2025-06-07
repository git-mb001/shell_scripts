#!/bin/bash
#
# Plugin name: stats_snmp_interfaces64.sh
# Description: This plugin performs SNMP (ver.2c only, RFC1213(IF-MIB), 32/64-bit counter) checks to collect metrics and status of network interface.
#   		   Conversions results in summaric ${DEVICE} internet speed as volume of information that is sent over a connection
#              in a measured amount of time, presented in G|M|K bits per secend (bps).
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
IFMIB='1.3.6.1.2.1.2.2.1.2'
WALK='/usr/bin/snmpwalk'
PROGRAM=${0##*/}
PROGPATH=${0%/*}

##
## Function fullusage()
##
fullusage() {

cat <<EOF

PROGRAM:
${PROGRAM}

DESCRIPTION:
This Nagios plugin performs SNMP (ver.2c only) checks for specified interface to collect metrics and status of network interface.
Plugin, during first two executions should create txt files with timestamp and calculated metrics. 

INFO: To display all available tested device interfaces for measurement, please use stats_snmp_interfaces64.sh plugin with -d|--display flag.

DATADIR (files location): ${DATADIR}

USAGE: 
${PROGRAM} -h|--help | -d|--display | -D|--debug | [-ip <address>] | [-if <interface>] | [-x <counter>] | [-C <community>] | [-s | -is <speed>] | [-w <warning>] [-c <critical>] | [-sev <severity>] | [-t <timeout>]

OPTION:
-h | --help		Print detailed help
-d | --display  Display all interfaces (just viewwise)
-D | --debug    Debug interfaces (yes|no), default is no.
-ip 			Specify host IP address for check
-if				Specify DEVICE Interface (port)
-x				Counter (32|64), default is 64.
-s | -is		Interface Speed (15G|10G|8G|4G|G|100M|10M|1M)
-w				Interface usage warning (% overall usage)
-c				Interface usage critical (% overall usage)
-C				SNMP Community string (ver.2c)
-sev			Severity, exit status depends on Interface status and its overall usage (WARN|CRIT)
-t				Timeout, default is 5s

Examples of usage:
stats_snmp_interfaces64.sh -ip 192.168.1.1 -C community_string --display
stats_snmp_interfaces64.sh -ip 192.168.1.1 -C community_string -if eth0 -s G -x 32 -D yes -t 10
stats_snmp_interfaces64.sh -ip 192.168.1.1 -C community_string -if eth0 -s G -x 64 -sev WARN
stats_snmp_interfaces64.sh -ip 192.168.1.1 -C community_string -if eth0 -s 10G -x 64 -w 75 -c 90 -sev CRIT -t 15

EOF
}

##
## Function display()
##
display() {

echo "Displaying interfaces for host address ${IP}:"

if [ -n "${IP}" ];
then  
        ${WALK} -v 2c -t ${t} -r 1 -c ${community} ${IP} .1.3.6.1.2.1.31.1.1.1.1  
        echo -e "\n\n"
        echo "Aliases:"
        ${WALK} -v 2c -t ${t} -r 1 -c ${community} ${IP} .1.3.6.1.2.1.31.1.1.1.18
else
        echo "UNKNOWN, Cannot display interfacess.. exiting!"
        exit -1
fi
}

##
## Function exit_nan_unknown() which exit from plugins with output not available ("NaN").
##
exit_nan_unknown() {
    	
		## Display unknown (NaN) results and exit -1
    	echo "UNKNOWN; Interface ${If_desc} (${If_speed}) Traffic In:"NaN" b/s ("NaN"%), Out:"NaN" b/s ("NaN"%) - Total RX Bits In:"NaN" b, Out:"NaN" b|traffic_in="NaN"Bits/s traffic_out="NaN"Bits/s"
    	exit -1
}

##
## Main program loop, with selection of functionality of plugin.
##
while :
do
        case "$1" in
        -w | --warning) warn=$2; shift 2;;
        -c | --critical) crit=$2; shift 2;;
        -ip | --address) IP=$2; shift 2;;
        -if | --interface) Interface=$2; shift 2;;
        -x | --counter) counter=$2; shift 2;;
        -C | --community) community=$2; shift 2;;
        -sev | --severity) severity=$2; shift 2;;
		-t | --timeout) t=$2; shift 2;; 
        -s | -is | --speed ) speed=$2; shift 2;;
        -D | --debug) test=$2; shift 2;;
        -d | --display) display; exit;;
        -h | --help) fullusage; exit;;
        --) # End of all options
             shift; 
             break;;
        -*) echo "Error: Unknown option: $1"
             exit 1;;
         *) # No more options;
             break;;
        esac
done

## Debug (optional)
if [[ "${test}" == "yes" ]];
then
    echo "DEBUG: Debugging enabled.."
fi

##
## Define required and default variables
##
[[ -z "${IP}" ]] && echo "UNKNOWN IP is not specified.." && exit -1
[[ -z "${Interface}" ]] && echo "UNKNOWN Interface is not specified.." && exit -1
[[ -z "${counter}" ]] && counter=64
[[ -z "${speed}" ]] && echo "UNKNOWN Interface is not specified.." && exit -1
[[ -z "${community}" ]] && echo "UNKNOWN SNMP Community is not specified.." && exit -1
[[ -z "${warn}" ]] && warn=80
[[ -z "${crit}" ]] && crit=90
[[ -z "${severity}" ]] && severity=CRIT
[[ -z "${t}" ]] && t=5

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
## Get interface number/describtion 
##
if [ ${Interface} -eq ${Interface} 2>/dev/null ];
then
        If=${Interface}
        If_desc=`${WALK} -v 2c -t ${t} -r 1 -c ${community} ${IP} ${IFMIB} |awk '{ if ( $0 ~ '"/ifDescr.${If}$/"' ) { print $NF }}'`
		[ -z "${If_desc}" ] || [[ ${$If_desc} == "" ]] && If_desc=${Interface}

elif [[ "${Interface}" =~ ^(eth|bond)* ]];
then
        If=`${WALK} -v 2c -t ${t} -r 1 -c ${community} ${IP} ${IFMIB} |awk '{ if ( $0 ~ '"/STRING: ${Interface}$/"' ) { print $1 }}' |cut -d'.' -f2`
        [[ "${If}" == "" ]] && echo "UNKNOWN Interface is not specified or not exist.." && exit -1
        If_desc=${Interface}
else
        If=`${WALK} -v 2c -t ${t} -r 1 -c ${community} ${IP} ${IFMIB} |awk '{ if ( $0 ~ '"/STRING: ${Interface}$/"' ) { print $1 }}' |awk -F'.' '{ print $NF }'`
        If_desc=`${WALK} -v 2c -t ${t} -r 2 -c ${community} ${IP} ${MIB} |awk '{ if ( $0 ~ '"/ifDescr.${If}$/"' ) { print $NF }}'`
		[ -z "${If_desc}" ] || [[ ${$If_desc} == "" ]] && If_desc=${Interface}
fi

## Debug
if [[ "${test}" == "yes" ]];
then
    echo "DEBUG: Interface number/desc: If=${If} If_desc=${If_desc} If_speed=${If_speed}"
fi

##
## State of Interface
##
state_if=`${WALK} -v 2c -t ${t} -r 1 -c ${community} ${IP} 1.3.6.1.2.1.2.2.1.8.$If | awk '{ print $4 }'`

## Debug
if [[ "${test}" == "yes" ]];
then
    echo "DEBUG: Interface status: ${state_if}"
fi

##
## Secend main program loop, depending on interface status.
##
case ${state_if} in
        *"up"* )
        up=$((up+1))
        ;;
        *"active"* )
        up=$((up+1))
        ;;
        *"down"* )
        if [[ "${SEVERITY}" =~ "CRIT" ]];
        then
            echo "CRITICAL Network Interface ${If_desc} ($If) DOWN; State:${state_if}" && exit 2
        elif [[ "${SEVERITY}" =~ "WARN" ]];
        then
            echo "WARNING Network Interface ${If_desc} ($If) DOWN; State:${state_if}" && exit 1
        fi
        ;;
        *"testing"* )
        echo "WARNING Network Interface ${If_desc} ($If) in Testing state" && exit 1
        ;;
        *"unknown"* )
        echo "UNKNOWN Network Interface ${If_desc} ($If) in UNKNOWN state; Output: ${state_if}" && exit -1
        ;;
        *"dormant"* )
        echo "WARNING Network Interface ${If_desc} ($If) is waiting for external actions; Output: ${state_if}" && exit 1
        ;;
        *"notPresent"* )
        echo "CRITICAL Network Interface ${If_desc} ($If) has missing components; Output: ${state_if}" && exit 2
        ;;
        *"notInService"* )
        if [[ "${SEVERITY}" =~ "CRIT" ]];
        then
            echo "CRITICAL Network Interface ${If_desc} ($If) is not in Service; Output: ${state_if}" && exit 2
        elif [[ "${SEVERITY}" =~ "WARN" ]];
        then
            echo "WARNING Network Interface ${If_desc} ($If) is not in Service; Output: ${state_if}" && exit 1
        fi
        ;;
        *"destroy"* )
        if [[ "${SEVERITY}" =~ "CRIT" ]];
        then
            echo "CRITICAL Network Interface ${If_desc} ($If) destroy; Output: ${state_if}" && exit 2
        elif [[ "${SEVERITY}" =~ "WARN" ]];
        then
            echo "WARNING Network Interface ${If_desc} ($If) destroy; Output: ${state_if}" && exit 1
        fi
        ;;
        *"lowerLayerDown"* )
        echo "WARNING Network Interface ${If_desc} ($If) lowerLayerDown state; Output: ${state_if}" && exit 1
        ;;
        *)
        echo "No result, TIMEOUT or UNEXPECTED value.. Output: ${state_if}" && exit -1
        ;;
esac


calculate_traffic()
{
        total=0
        last_IfinBits=0
        last_IfOutBits=0
        Ifflg_created=0
        file="${DATADIR}/check_snmp_interfaces64_${If}_${IP}"

        ## Debug
        if [[ "${test}" == "yes" ]];
        then
                echo "DEBUG: File created: ${DATADIR}/check_snmp_interfaces64_${If}_${IP}"
        fi

        if [ -e "${file}" ]; 
        then
                buffer_init=`grep "buffer_init" ${file}`
                if [ -z ${buffer_init} ];
                then
                        last_time=`cat "${file}" |cut -d":" -f1`
                        last_IfinBits=`cat "${file}" |cut -d":" -f2`
                        last_IfOutBits=`cat "${file}" |cut -d":" -f3`
                        Ifflg_created=1
                        echo "${time_now}:${IfinBits}:${IfOutBits}" > ${file}
                else
                        last_time=`cat "${file}" |cut -d":" -f1`
                        last_IfinBits=`cat "${file}" |cut -d":" -f2`
                        last_IfOutBits=`cat "${file}" |cut -d":" -f3`
                        Ifflg_created=1
                        echo "${time_now}:${IfinBits}:${IfOutBits}" > ${file}
                        echo "UNKNOWN First execution : Buffer created...."
                        exit 3
                fi
        else
                echo "${time_now}:${last_IfinBits}:${last_IfOutBits}:buffer_init" > "${file}"
                echo "UNKNOWN First execution : Buffer in creation...."
                exit 3
        fi

        ## Debug
        if [[ "${test}" == "yes" ]];
        then
                echo "DEBUG: Time:${time_now} Last_IfinBits:${last_IfinBits} Last_IfOutBits:${last_IfOutBits} counter=${counter}"
        fi

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
                        [ ${diff_time} -eq 0 ] && diff_time=1
                        Ifin_traffic=`expr ${total} / ${diff_time}`
                fi

                [ ${Ifin_traffic} -gt ${factor} ] && Ifin_traffic=NaN

        elif [ ${diff_IfinBits} -eq 0 ];
        then
                Ifin_traffic=0
        else 
                Ifin_traffic=NaN
        fi

        ## Debug
        if [[ "${test}" == "yes" ]];
        then
                echo "DEBUG: diff_IfinBits=${diff_IfinBits} total=${total} Ifin_traffic=${Ifin_traffic} counter=${counter}"
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
        
        elif [ ${diff_IfOutBits} -eq 0 ];
        then
                IfOut_traffic=0
        else 
                IfOut_traffic=NaN
        fi

        ## Debug
        if [[ "${test}" == "yes" ]];
        then
                echo "DEBUG: diff_IfOutBits=${diff_IfOutBits} total=${total} IfOut_traffic=${IfOut_traffic} counter=${counter}"
        fi

		## Exit if NaN result
        if [[ "${Ifin_traffic}" == "NaN" ]] || [[ "${IfOut_traffic}" == "NaN" ]];
        then
			## Debug
            if [[ "${test}" == "yes" ]];
            then
                echo "DEBUG: Exiting; exit_nan_unknown exception.. factor=${factor} Ifin_traffic=${Ifin_traffic} IfOut_traffic=${IfOut_traffic}"
            fi
            exit_nan_unknown
        fi

        if [ ${IfSpeed} -ne 0 ];
        then
            Ifin_usage=`expr ${Ifin_traffic} \* 100 / ${IfSpeed}`
            IfOut_usage=`expr ${IfOut_traffic} \* 100 / ${IfSpeed}`
        else
			## Debug
            if [[ "${test}" == "yes" ]];
            then
				echo "DEBUG: UNKNOWN IfSpeed=${IfSpeed}; Cannot calculate Ifusage"
				exit 3
			else
				echo "UNKNOWN IfSpeed=${IfSpeed}; Cannot calculate Ifusage"
				exit 3
			fi
        fi

        # Debug
        if [[ "${test}" == "yes" ]];
        then
            echo "DEBUG: IfSpeed=${IfSpeed} Ifin_usage=${Ifin_usage} IfOut_usage=${IfOut_usage}"
        fi

        # For Graphs
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
}
# END of calculate_traffic()

##
## Function display_results()
##
display_results()
{
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

        ##
		## Finaly display results
        ##
		echo "${status} :: Interface ${If_desc} (${If_speed}) Traffic In:"${Ifin_traffic}" "${Ifin_prefix}"b/s ("${Ifin_usage}"%), Out:"${IfOut_traffic}" "${IfOut_prefix}"b/s ("${IfOut_usage}"%) - Total RX Bits In:"${IfinBits}" "${IfinBits_unit}"b, Out:"${IfOutBits}" "${IfOutBits_unit}"b|traffic_in="${traffic_in}"Bits/s traffic_out="${traffic_out}"Bits/s"
        exit $exit_code
}
# END of display_results()

## 
## Third main program loop, depends on secend main program loop.
##
if [ ${up} -eq 1 ]; then

        IfSpeed="${factor}"

        if [ ${counter} -eq 32 ];
        then
            # Counter32
            IfinOctets=`${WALK} -v 2c -t ${t} -r 2 -c ${community} ${IP} 1.3.6.1.2.1.2.2.1.10.${If} |awk '{ if ( $1 ~ 'Counter32' ) { print $NF }}'`
            IfOutOctets=`${WALK} -v 2c -t ${t} -r 2 -c ${community} ${IP} 1.3.6.1.2.1.2.2.1.16.${If} |awk '{ if ( $1 ~ 'Counter32' ) { print $NF }}'`

        elif [ ${counter} -eq 64 ];
        then
            # Counter64
            IfinOctets=`${WALK} -v 2c -t ${t} -r 2 -c ${community} ${IP} ifMIB.ifMIBObjects.ifXTable.ifXEntry.ifHCInOctets.${If} |awk '{ if ( $1 ~ 'Counter64' ) { print $NF }}'`
            IfOutOctets=`${WALK} -v 2c -t ${t} -r 2 -c ${community} ${IP} ifMIB.ifMIBObjects.ifXTable.ifXEntry.ifHCOutOctets.${If} |awk '{ if ( $1 ~ 'Counter64' ) { print $NF }}'`
        fi

        [ -z "${IfinOctets}" ] || [ -z "${IfOutOctets}" ] && echo "UNKNOWN SNMP Timeout or No Response from ${IP}.." && exit 3

        IfinBits=`expr ${IfinOctets} \* 8`
        IfOutBits=`expr ${IfOutOctets} \* 8`

		##
		## Invoke calculate_traffic() and display_results()
		##
        calculate_traffic
        display_results
fi

exit 0

