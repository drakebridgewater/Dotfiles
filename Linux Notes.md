
## Output rate in terminal

* Pipe Viewer prints stats about the data passing through it, and can run anywhere in your pipeline, since it pipes stdin directly over to stdout. For example:
tail -f /var/log/nginx/access.log | pv --line-mode --rate › /dev/null
* The pv command prints to stderr the current number of lines per second (the default is bytes per second), which, for this particular data source (Nginx’s default log file), equates to incoming web requests per second. I only care about the counts, so I pipe stdout into /dev/null. There are also options like:
  * `-b` (total number of lines),
  * `--average-rate` (average rate since starting), and
  * `--timer` (tracks how long the pipe has been going).

## Logrotate

* Stored in /etc/logrotate.d/

```bash
/var/log/mars/grid_status.log {
    missingok
    compress
    notifempty
    daily
    dateext
    maxage 5
    rotate 5
}
```

## Disk Space issues

* Figure out what partition is causing the problems `df -hl`
* Figure out what directory is causing the problems `du -mx / > /tmp/du.txt`
  * use `sort -n /tmp/du.txt to isolate the larger directories

## Services

* chkconfig: The chkconfig command can also be used to activate and deactivate services. The chkconfig —list command displays a list of system services and whether they are started (on) or stopped (off) in runlevels 0–6. Standard run level use is ‘345′
* `chkconfig --level 345 nscd off`

## System D

Is a utility found in RHEL7 and up that allows running a process as a daemon very easily

* To get started you need the configuration script which looks like:

```ini
[Unit]
Description=Host Updating Service
After=network.target remote-fs.target nss-lookup.target autofs.service

[Service]
User=mars
Environment="MARS_ENV=devel"
ExecStart=/wv/dbridgew/Projects/mars/sbin/host_status/host_updaterd
Restart=on-failure
StandardOutput=null

[Install]
WantedBy=multi-user.target
```

* There are two ways of linking the script into place:
  * Actually copy the file into /lib/systemd/system
  * Or use the systemctl command to do all the heavy lifting. Link the config script into systemD: systemctl enable /path/to/config/service_name
    * If the source code changes, when you run systemctl restart /path/to/config/service_name it will let you know and give you the command to re-link to source.
* Start the service: systemctl start service_name
* If modification are done to the service you can run: systemctl reload service_name

# MySQL

* Add user:
  * `create user ‘mars’@’%’ identified by ‘DANGER_I_KNOW_THE_RISKS’;`
* Grant access to mars to any database that starts with mars_grid_status_devel
  * `GRANT SELECT, INSERT, UPDATE, DELETE, DROP, CREATE ON`mars\_grid\_status\_devel\_% . * to ‘mars’@’%’;`
* See the processes running on the host
  * `grant process on * . * to ‘processlister’@’%’;`
* <https://www.digitalocean.com/community/tutorials/how-to-create-a-new-user-and-grant-permissions-in-mysql>

```sql
SELECT
    column_1, column_2, ...
FROM
    table_1
[INNER | LEFT |RIGHT] JOIN table_2 ON conditions
WHERE
    conditions
GROUP BY column_1
HAVING group_conditions
ORDER BY column_1
LIMIT offset, length;
```

# TMUX Stuff

Synchronized input on all panes in window: prefix then :setw synchronize-panes
