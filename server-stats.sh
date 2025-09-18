#!/usr/bin/env bash
# ultra-minimal, but still correct script for server stats

export LC_ALL=C

echo "######################"
echo "# System Uptime Info #"
echo "######################"
uptime
echo

echo "###################"
echo "# Total CPU Usage #"
echo "###################"
top -bn1 | awk -F'[, ]+' '/Cpu\(s\):/{
  for(i=1;i<=NF;i++) if($i ~ /^id$/){idle=$(i-1); gsub("%","",idle); printf("Usage: %.1f%%\n", 100-idle)}
}'
echo

echo "######################"
echo "# Total Memory Usage #"
echo "######################"
free -m | awk '/^Mem:/{
  total=$2; avail=$7; used=total-avail;
  printf "Total: %.1fGi\nUsed: %.1fGi (%.2f%%)\nFree: %.1fGi (%.2f%%)\n",
         total/1024, used/1024, used*100/total, avail/1024, avail*100/total
}'
echo

echo "####################"
echo "# Total Disk Usage #"
echo "####################"
df -h --total -x tmpfs -x devtmpfs -x overlay -x squashfs -x proc -x sysfs 2>/dev/null \
| awk 'END{printf "Total: %s\nUsed: %s (%s)\nFree: %s\n", $2, $3, $5, $4}'
echo

echo "###################################"
echo "# Top 5 Processes by Memory Usage #"
echo "###################################"
ps aux --sort=-%mem | sed 1d | head -n 5 | awk '{print $1 "\t" $2 "\t" $4 "\t" $11}'
echo

echo "################################"
echo "# Top 5 Processes by CPU Usage #"
echo "################################"
ps aux --sort=-%cpu | sed 1d | head -n 5 | awk '{print $1 "\t" $2 "\t" $3 "\t" $11}'
