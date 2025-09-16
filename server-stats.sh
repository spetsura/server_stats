#!/usr/bin/env bash
# server-stats.sh — clean & accurate single-shot server stats
# Usage: ./server-stats.sh [--no-color]

set -o errexit
set -o nounset
set -o pipefail
export LC_ALL=C

NO_COLOR=0
[[ "${1-}" == "--no-color" ]] && NO_COLOR=1

if [[ "$NO_COLOR" -eq 0 && -t 1 ]]; then
  BOLD="\033[1m"; BLUE="\033[34m"; CYAN="\033[36m"; RST="\033[0m"
else
  BOLD=""; BLUE=""; CYAN=""; RST=""
fi

hr()      { printf "%s\n" "------------------------------------------------------------"; }
section() { printf "%b%s%b\n" "$BOLD" "$1" "$RST"; }

human() {
  local b; if [[ $# -gt 0 ]]; then b="$1"; else read -r b; fi
  awk -v b="$b" 'function h(x){s="B KB MB GB TB PB";split(s,a," ");
    for(i=1;i<=6;i++){if(x<1024||i==6){printf "%.1f %s", x, a[i];break}x/=1024}}
    BEGIN{h(b)}'
}

get_os_pretty() {
  if [[ -r /etc/os-release ]]; then . /etc/os-release; printf "%s" "${PRETTY_NAME:-$NAME}"
  elif command -v lsb_release >/dev/null 2>&1; then lsb_release -d | awk -F'\t' '{print $2}'
  else uname -srm; fi
}
get_uptime() {
  if [[ -r /proc/uptime ]]; then
    awk '{sec=int($1)}
         function fmt(x){d=int(x/86400);x%=86400;h=int(x/3600);x%=3600;m=int(x/60);s=x%60;
         out=""; if(d) out=out d "d "; if(h||d) out=out h "h "; if(m||h||d) out=out m "m "; out=out s "s"; print out}
         END{fmt(sec)}' /proc/uptime
  else uptime -p 2>/dev/null || true; fi
}
get_loadavg() {
  if [[ -r /proc/loadavg ]]; then awk '{printf "%s (1m)  %s (5m)  %s (15m)", $1,$2,$3}' /proc/loadavg
  else uptime | awk -F'load average: ' '{print $2}'; fi
}

cpu_total_usage() {
  read -r _ u1 n1 s1 i1 w1 q1 sq1 st1 _ _ < /proc/stat
  local idle1=$((i1 + w1)); local non1=$((u1 + n1 + s1 + q1 + sq1 + st1)); local tot1=$((idle1 + non1))
  sleep 1
  read -r _ u2 n2 s2 i2 w2 q2 sq2 st2 _ _ < /proc/stat
  local idle2=$((i2 + w2)); local non2=$((u2 + n2 + s2 + q2 + sq2 + st2)); local tot2=$((idle2 + non2))
  local dt=$((tot2 - tot1)); local didle=$((idle2 - idle1))
  if (( dt > 0 )); then awk -v t="$dt" -v i="$didle" 'BEGIN{printf "%.1f", (t-i)*100.0/t}'; else printf "0.0"; fi
}

mem_stats() {
  awk '
    /MemTotal:/     {t=$2*1024}
    /MemAvailable:/ {a=$2*1024; have=1}
    /MemFree:/      {f=$2*1024}
    /Buffers:/      {b=$2*1024}
    /Cached:/       {c=$2*1024}
    /SReclaimable:/ {sr=$2*1024}
    /Shmem:/        {sh=$2*1024}
    /SwapTotal:/    {st=$2*1024}
    /SwapFree:/     {sf=$2*1024}
    END{
      if(!have){a=f+b+c+sr-sh; if(a<0)a=0}
      used=t-a; upct=(t?used*100.0/t:0)
      su=st-sf; spct=(st?su*100.0/st:0)
      printf "%ld %ld %.1f %ld %ld %.1f\n", used,a,upct,su,sf,spct
    }' /proc/meminfo
}

disk_lines() {
  df -PT -B1 | awk '
    BEGIN{
      split("tmpfs devtmpfs proc sysfs cgroup2 cgroup pstore securityfs debugfs tracefs overlay squashfs ramfs aufs nsfs fusectl binfmt_misc efivarfs bpf autofs", ex, " ")
      for(i in ex) bad[ex[i]]=1
    }
    NR>1{
      fstype=$2; size=$3; used=$4; avail=$5; mp=$7
      if(size>0 && !bad[fstype]) print mp, size, used, avail
    }'
}

disk_summary() {
  disk_lines | awk '{sz+=$2; u+=$3; a+=$4} END{pct=(sz?u*100.0/sz:0); printf "%ld %ld %.1f\n", u, a, pct}'
}

print_per_mount_human() {
  printf "%-30s %12s %12s %7s\n" "Mount" "Used" "Avail" "Use%"
  disk_lines | while read -r mp size used avail; do
    printf "%-30s %12s %12s %6.1f%%\n" "$mp" "$(human "$used")" "$(human "$avail")" "$(awk -v u="$used" -v s="$size" 'BEGIN{print (s?u*100.0/s:0)}')"
  done
}

TOPN=5
top_by_cpu() { ps -eo pid,comm,%cpu,%mem --sort=-%cpu | awk -v n="$TOPN" 'NR>1 && NR<=n+1 {printf "%-8s %-22s %6s %6s\n",$1,$2,$3,$4}'; }
top_by_mem() { ps -eo pid,comm,%mem,%cpu --sort=-%mem | awk -v n="$TOPN" 'NR>1 && NR<=n+1 {printf "%-8s %-22s %6s %6s\n",$1,$2,$3,$4}'; }

failed_login_attempts() {
  local cnt
  if command -v journalctl >/dev/null 2>&1; then
    cnt=$(journalctl --since today _SYSTEMD_UNIT=ssh.service 2>/dev/null | grep -ci "Failed password" || true)
    [[ -n "${cnt:-}" ]] && { echo "$cnt (today via journalctl)"; return; }
    cnt=$(journalctl --since today SYSLOG_IDENTIFIER=sshd 2>/dev/null | grep -ci "Failed password" || true)
    [[ -n "${cnt:-}" ]] && { echo "$cnt (today via journalctl)"; return; }
  fi
  if command -v lastb >/dev/null 2>&1 && sudo -n lastb >/dev/null 2>&1; then
    cnt=$(sudo -n lastb | awk 'END{print (NR<2?0:NR-2)}'); echo "$cnt (total via lastb)"; return
  fi
  for f in /var/log/auth.log /var/log/secure; do
    [[ -r "$f" ]] && { cnt=$(grep -ci "Failed password" "$f" || true); echo "$cnt (from $f)"; return; }
  done
  echo "N/A"
}

section "System"
printf "%bOS%b: %s\n"      "$BLUE" "$RST" "$(get_os_pretty)"
printf "%bKernel%b: %s\n"  "$BLUE" "$RST" "$(uname -srmo 2>/dev/null || uname -a)"
printf "%bUptime%b: %s\n"  "$BLUE" "$RST" "$(get_uptime)"
printf "%bLoad avg%b: %s\n" "$BLUE" "$RST" "$(get_loadavg)"
printf "%bLogged-in users%b: %s\n" "$BLUE" "$RST" "$(who 2>/dev/null | wc -l | awk '{print $1}')"
printf "%bFailed SSH logins%b: %s\n" "$BLUE" "$RST" "$(failed_login_attempts)"
hr

section "Total CPU Usage"
CPU="$(cpu_total_usage)"
printf "%bCPU Utilization%b: %s%%\n" "$CYAN" "$RST" "$CPU"
hr

section "Memory"
read -r MU MA MPCT SU SF SPCT < <(mem_stats)
printf "%bUsed%b:       %s  (%.1f%%)\n" "$CYAN" "$RST" "$(human "$MU")" "$MPCT"
printf "%bAvailable%b:  %s\n"          "$CYAN" "$RST" "$(human "$MA")"
printf "%bSwap Used%b:  %s  (%.1f%%)\n" "$CYAN" "$RST" "$(human "$SU")" "$SPCT"
printf "%bSwap Free%b:  %s\n"          "$CYAN" "$RST" "$(human "$SF")"
hr

section "Disks (All filesystems, summary)"
read -r DUSED DFREE DPCT < <(disk_summary)
printf "%bUsed%b:   %s  (%.1f%%)\n" "$CYAN" "$RST" "$(human "$DUSED")" "$DPCT"
printf "%bFree%b:   %s\n" "$CYAN" "$RST" "$(human "$DFREE")"
printf "%bPer-mount details%b:\n" "$CYAN" "$RST"
print_per_mount_human
hr

section "Top ${TOPN} processes by CPU"
printf "%-8s %-22s %6s %6s\n" "PID" "COMMAND" "%CPU" "%MEM"
top_by_cpu
hr

section "Top ${TOPN} processes by Memory"
printf "%-8s %-22s %6s %6s\n" "PID" "COMMAND" "%MEM" "%CPU"
top_by_mem
hr
