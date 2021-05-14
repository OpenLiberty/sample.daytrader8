docker-login() {
	echo "INFO: Logging in as ${DOCKER_USER}"
	docker login ${DOCKER_REGISTRY} -u ${DOCKER_USER} -p ${DOCKER_PASS} || docker login -u ${DOCKER_USER} -p ${DOCKER_PASS}
}

build-manifest-cmd-for-tag() {
    # build the manifest command for a given docker tag
    local docker_tag=$1
    if [[ ${DOCKER_OFFICIAL} = true ]]; then
        docker_uri="${DOCKER_REGISTRY}/library/${DOCKER_IMAGE}"
    else
        docker_uri="${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${DOCKER_IMAGE}"
    fi
    docker_uri=$(strip-uri ${docker_uri})

    docker_manifest_command="docker manifest create ${docker_uri}:${docker_tag}"
    for ARCH in ${SUPPORTED_ARCHITECTURES}; do
        if [[ ${DOCKER_OFFICIAL} = true ]]; then
            docker_official_uri=$(strip-uri ${DOCKER_REGISTRY}/${ARCH}/${DOCKER_IMAGE})
            docker_manifest_command="${docker_manifest_command} ${docker_official_uri}:${docker_tag}"
        fi

        if [[ ${DOCKER_OFFICIAL} = false ]]; then
            docker_manifest_command="${docker_manifest_command} ${docker_uri}:${ARCH}-${docker_tag}"
        fi
        
    done
    echo ${docker_manifest_command}
}

annotate-manifest-for-tag() {
    local manifest_tag=$1
    if [[ ${DOCKER_OFFICIAL} = true ]]; then
        docker_uri="${DOCKER_REGISTRY}/library/${DOCKER_IMAGE}"
    else
        docker_uri="${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${DOCKER_IMAGE}"
    fi
    docker_uri=$(strip-uri ${docker_uri})

    docker_manifest_command=""
    for ARCH in ${SUPPORTED_ARCHITECTURES}; do
        if [[ ${DOCKER_OFFICIAL} = true ]]; then
            docker_official_uri=$(strip-uri ${DOCKER_REGISTRY}/${ARCH}/${DOCKER_IMAGE})
            docker_manifest_command="${docker_manifest_command} && docker manifest annotate ${docker_uri}:${manifest_tag} ${docker_official_uri}:${manifest_tag} --arch ${ARCH}"
        fi
        
        if [[ ${DOCKER_OFFICIAL} = false ]]; then
            docker_manifest_command="${docker_manifest_command} && docker manifest annotate ${docker_uri}:${manifest_tag} ${docker_uri}:${ARCH}-${manifest_tag} --arch ${ARCH}"
        fi
    done
    docker_manifest_command=$(echo ${docker_manifest_command} | sed 's/^\&*//')  # strip off all leading '&' characters
    echo ${docker_manifest_command}
}

push-manifest-for-tag() {
    manifest_tag=$1
    docker_uri=$(strip-uri ${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${DOCKER_IMAGE})

    if [[ ${DOCKER_OFFICIAL} = true ]]; then
        docker_uri=$(strip-uri ${DOCKER_REGISTRY}/library/${DOCKER_IMAGE})
    fi
    docker_manifest_command="docker manifest push --purge ${docker_uri}:${manifest_tag}"
    echo ${docker_manifest_command}
}

strip-uri() {
    uri=$1
    # strip off all leading '/' characters, change `//` to `/`
    uri=$(echo ${uri} | sed 's/^\/*//;s/\/\//\//g')
    echo  ${uri}
}
