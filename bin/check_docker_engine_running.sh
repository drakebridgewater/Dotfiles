#!/bin/sh
check_docker_engine_running() {
	docker info >/dev/null
	if [ $? -eq 1 ]; then
		echo "Docker engine is not running!"
		echo "Please start docker engine, then try again."
		return 1
	fi
	return 0
}

exit "$(check_docker_engine_running)"
