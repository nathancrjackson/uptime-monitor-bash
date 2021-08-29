# Uptime Monitor

[Git Repo](https://github.com/nathancrjackson/uptime-monitor-bash)

A bash script to be run as a cronjob for monitoring websites and anything else that will respond to a ping. After x amount of consecutive successes or failures that contradict the current state (3 by default) the state is changed and then a Discord and/or Teams message can be sent via webhook. One instance of this is currently comfortably running every minute pinging 100 IPs and curling 10 webpages. When given a list of URLs to check it runs asynchronously by calling itself as a separate processs for each URL.

#### Options:
```
 -s             --skip-internet-test          Skip testing the internet connection
 -S             --skip-internet-test-quietly  Skip testing the internet connection quietly
 -c             --change-status-count         Set what count if required to change status
 -p             --change-ping-count           Set how many pings are sent
 -t <URL>       --test <URL>                  Test specified URL
 -l <URL list>  --list <URL list>             Test URLs in string list (comma-separated)
 -f <file>      --file <file>                 Test URLs in file (newline-separated)
 -h             --help                        Basic help
 -H             --extended-help               Extended help information
```

#### Example accepted URLs:
- http://example.com
- https://example.com
- ping://example.com

#### Example commands

Single test skipping internet test
```
./uptime-monitor.sh --test "https://njit.io" --skip-internet-test
```

Test a couple of URLs
```
./uptime-monitor.sh --test "https://njit.io, ping://github.com"
```

Test a list of URLs saved in a file
```
./uptime-monitor.sh --file "~/misc-config/test.urls"
```

#### Information on using files for test URLs list
- Leading and trailing whitespace is ignored (using xargs)
- Using # as first non-whitespace character denotes comment lines
- You cannot comment after a URL on the same line

#### Example of a perfectly valid test URLs file
```
# Testing my website
https://njit.io

    # Testing a website that was big back in 2006
	https://myspace.com
	

```

#### This script has the following software dependencies
- bash
- echo
- cat
- cut
- awk
- xargs
- ping
- curl
- date
- md5sum

#### Possible future additions
- More consistent bash code
- Configuration file
- More generalised webhook options
- Better logging
- Nice installation guide

#### Rough installation guide
- Git clone this repo or download `uptime-monitor.sh` to your machine
- Ensure `uptime-monitor.sh` is executable
- Create a folder that the user running the script can write to
- Update `FILEFOLDER` variable in script with the full path of that folder
- Update both/either `DISCORD_WEBHOOK_URL` and/or `TEAMS_WEBHOOK_URL` with the appropriate webhook you want to use
- Create a cronjob as the user that you want running the script (not root please), perhaps with `cronttab -e`
