# shell_scripts
Public repo with shell (.sh) scripts
<br/>
Script name: **<ins>stats_cpu_utilization_percore.sh</ins>**<br/>
Description: This plugin performs numeric calculations on tables with per-core CPU metrics.
             Self detects number of cores and sum amount of cpu per-core extracted data.
<br/>
Script name: **<ins>stats_snmp_interfaces64.sh</ins>**<br/>
Description: This plugin performs SNMP (ver.2c only, RFC1213(IF-MIB), 32/64-bit counter) checks to collect metrics and status of network interface.
             Conversions results in summaric ${DEVICE} internet speed as volume of information that is sent over a connection
             in a measured amount of time presented in G|M|K bits per secend (bps).
<br/>
Plugin name: **<ins>stats_snmp_interfaces64_cumulative.sh</ins>**<br/>
Description: This plugin performs operations on SNMP (ver.2c only, RFC1213(IF-MIB), 32/64-bit counter) metrics to calculate cumulative speed of network interfaces.
             This version gives as a results summaric ${NET_DEVICE} internet speed as volume of information that is sent over a connection
             in a measured amount of time presented in G|M|K bits per secend (bps).
<br/>
Author: Marcin Bednarski (e-mail: marcin.bednarski@gmail.com)<br/>
