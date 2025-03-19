#!/bin/bash

split_list=()
split_list+=( tmux new-session -n 'watcher' )
split_list+=( tmux rename-winodw 'cassandra' )
split_list+=( ssh 'mars@cassandra-04' 'tail -f /var/log/mars/*.log' ';' )
split_list+=( split-window ssh 'mars@cassandra-05' 'tail -f /var/log/mars/*.log' ';' )
split_list+=( split-window ssh 'mars@cassandra-06' 'tail -f /var/log/mars/*.log' ';' )
split_list+=( split-window ssh 'mars@iescassandra-01' 'tail -f /var/log/mars/*.log' ';' )
split_list+=( split-window ssh 'mars@iescassandra-02' 'tail -f /var/log/mars/*.log' ';' )
split_list+=( split-window ssh 'mars@iescassandra-03' 'tail -f /var/log/mars/*.log' ';' )

split_list+=( new-winodw -n 'mars01:*.log' )
split_list+=( split-window ssh 'mars@orw-mars01-rh7' 'tail -F /var/log/mars/*.log' ';' )
split_list+=( split-window ssh 'mars@ies-mars01-rh7' 'tail -F /var/log/mars/*.log' ';' )
split_list+=( split-window ssh 'mars@amy-mars01-rh7' 'tail -F /var/log/mars/*.log' ';' )

split_list+=( new-winodw -n 'worker:*.log' )
split_list+=( split-window ssh 'mars@marsworker-01' 'tail -F /var/log/mars/*.log' ';' )
split_list+=( split-window ssh 'mars@marsworker-02' 'tail -F /var/log/mars/*.log' ';' )
split_list+=( split-window ssh 'mars@ies-marsw01-ct7' 'tail -F /var/log/mars/*.log' ';' )
split_list+=( split-window ssh 'mars@ies-marsw02-ct7' 'tail -F /var/log/mars/*.log' ';' )


tmux new-session ssh "${ssh_list[0]}" ';' \
	"${split_list[@]}" \
	select-layout tiled ';' \
	set-option -w synchronize-panes

