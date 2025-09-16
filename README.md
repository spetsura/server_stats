# Server Performance Stats Script 
A simple cross-platform Bash script that shows server performance stats: CPU, memory, swap, disks, top processes, system info, and failed SSH login attempts

# server-stats.sh

`server-stats.sh` is a simple, cross-distro Bash script for quickly checking server performance stats in a clean and readable format.

## Features

- **CPU usage** — sampled from `/proc/stat` for accurate percentage.
- **Memory usage** — shows RAM used/available and Swap usage.
- **Disk usage** — total summary and per-mount breakdown, excluding pseudo filesystems.
- **Top processes** — top 5 processes by CPU and by memory.
- **System info** — OS, kernel, uptime, load average, logged-in users.
- **Security info** — failed SSH login attempts (via `journalctl` / `lastb` / log files).

## Usage

Make the script executable and run it:

```bash
chmod +x server-stats.sh
./server-stats.sh
