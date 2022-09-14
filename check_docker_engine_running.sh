check_docker_engine_running() {
	docker info > /dev/null
	if [ $? -eq 1 ]
	then
		echo "Docker engine is not running!"
		echo "Please start docker engine, then try again."
		exit 1
	fi
}

exit `check_docker_engine_running`