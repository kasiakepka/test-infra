#!/usr/bin/env bash

function start_docker() {
    echo "Docker in Docker enabled, initializing..."
    printf '=%.0s' {1..80}; echo
    # If we have opted in to docker in docker, start the docker daemon,
    service docker start
    # the service can be started but the docker socket not ready, wait for ready
    local WAIT_N=0
    local MAX_WAIT=20
    while true; do
        # docker ps -q should only work if the daemon is ready
        docker ps -q > /dev/null 2>&1 && break
        if [[ ${WAIT_N} -lt ${MAX_WAIT} ]]; then
            WAIT_N=$((WAIT_N+1))
            echo "Waiting for docker to be ready, sleeping for ${WAIT_N} seconds."
            sleep ${WAIT_N}
        else
            echo "Reached maximum attempts, not waiting any longer..."
            break
        fi
    done
    printf '=%.0s' {1..80}; echo
    
    docker-credential-gcr configure-docker
    echo "Done setting up docker in docker."
}

function authenticate() {
    echo "Authenticating"
    gcloud auth activate-service-account --key-file "${GOOGLE_APPLICATION_CREDENTIALS}"
}

function init() {
    echo "Initializing"

    if [[ ! -z "${GOOGLE_APPLICATION_CREDENTIALS}" ]]; then
        authenticate
    fi

    if [[ "${DOCKER_IN_DOCKER_ENABLED}" == true ]]; then
        start_docker
    fi
}