# Server Performance Stats Script 
A simple Bash script that prints a quick snapshot of a Linux server: uptime & load, total CPU usage, memory and swap, disk totals, and top-5 processes (by memory and by CPU).

# server-stats.sh

`server-stats.sh` is a simple, cross-distro Bash script for quickly checking server performance stats in a clean and readable format.

## Features

- **Uptime & load average** - from (`uptime`).
- **CPU usage** - parsed from `top` (100 - idle).
- **Memory usage** - Total / Used / Free (via `free`), **Swap** Used / Free.
- **Disk (summary)** - Total / Used / Free from `df --total` (excluding tmpfs/devtmpfs/overlay/squashfs, proc, sysfs).
- **Top processes** - top 5 processes by CPU and by memory.

## Usage

Clone the repository or download the script:

```bash
git clone https://github.com/spetsura/server_stats.git
cd server_stats/
```
Make the script executable and run it:

```bash
chmod +x server-stats.sh
./server-stats.sh
```
## Reference to:

```bash
https://roadmap.sh/projects/server-stats
```
