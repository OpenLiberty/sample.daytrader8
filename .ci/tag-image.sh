#!/bin/bash
# set -exo pipefail

# ------------------------------------
#  ____   __   ____   __   _  _  ____ 
# (  _ \ / _\ (  _ \ / _\ ( \/ )/ ___)
#  ) __//    \ )   //    \/ \/ \\___ \
# (__)  \_/\_/(__\_)\_/\_/\_)(_/(____/
# ------------------------------------

# This script requires you to have a few environment variables set. As this is targeted
# to be used in a CICD environment, you should set these either via the Jenkins/Travis
# web-ui or in the `.travis.yml` or `pipeline` file respectfully 

# DOCKER_USER - Used for `docker login` to the private registry DOCKER_REGISTRY
# DOCKER_PASS - Password for the DOCKER_USER
# DOCKER_REGISTRY - Docker Registry to push the docker image and manifest to (defaults to docker.io)
# DOCKER_NAMESPACE - Docker namespace to push the docker image to (this is your username for DockerHub)
# SUPPORTED_ARCHITECTURES - Which architectures the docker image supports

source ./.ci/common-functions.sh > /dev/null 2>&1 || source ./ci/common-functions.sh > /dev/null 2>&1

IMAGE=""                # The docker image (including root tag) to use when making a new tag (image:tag)
TAGS=""                 # A list of new tags that the image will become i.e. "tag1 tag2 ... tagN"
DOCKER_OFFICIAL=false   # mimic the official docker publish method for images in private registries
IS_DRY_RUN=false        # Prints out what will happen rather than running the commands

usage() {
  echo -e "A docker container tagging script for ci pipelines \n\n"
  echo "Usage:"
  echo "${0} --image image:tag --tags \"tag1 tag2 ... tagN\" [--official] [--dry-run]"
  echo ""
}

if [[ "$*" == "" ]] || [[ "$*" != *--image* ]] || [[ "$*" != *--tags* ]]; then
  usage
  exit 1
fi

while [[ $# -gt 0 ]]; do
  key="$1"
  case $key in
    -i|--image)
    IMAGE=$2
    shift
    ;;
    -t|--tags)
    TAGS=$2
    shift
    ;;
    -o|--official)
    DOCKER_OFFICIAL=true
    ;;
    --dry-run)
    IS_DRY_RUN=true
    ;;
    *)
    echo "Unknown option: $key"
    return 1
    ;;
  esac
  shift
done

if [[ "${GIT_BRANCH}" == "master" ]] && [[ "${IS_PULL_REQUEST}" == "false" ]]; then

  # ------------------------------
  #  ____  ____  ____  _  _  ____ 
  # / ___)(  __)(_  _)/ )( \(  _ \
  # \___ \ ) _)   )(  ) \/ ( ) __/
  # (____/(____) (__) \____/(__)  
  # ------------------------------

  if [[ ${IS_DRY_RUN} = true ]]; then
    echo "INFO: Dry run executing, nothing will be pushed/run"
  fi

  # split the IMAGE into DOCKER_IMAGE_NAME DOCKER_TAG based on the delimiter, ':'
  IFS=":" read -r -a image_info <<< "$IMAGE"
  DOCKER_IMAGE_NAME=${image_info[0]}
  DOCKER_TAG=${image_info[1]}

  # This uses DOCKER_USER and DOCKER_PASS to login to DOCKER_REGISTRY
  if [[ ! ${IS_DRY_RUN} = true ]]; then
    docker-login
  fi

  # Pull the latest image that was uploaded
  for ARCH in ${SUPPORTED_ARCHITECTURES}; do
    if [[ ${DOCKER_OFFICIAL} = true ]]; then
      DOCKER_REPO=${DOCKER_REGISTRY}/${ARCH}/${DOCKER_IMAGE_NAME}
      DOCKER_PULL_TAG=${DOCKER_TAG}  # pull registry/arch/image:tag
    fi

    if [[ ${DOCKER_OFFICIAL} = false ]]; then
      DOCKER_REPO=${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${DOCKER_IMAGE_NAME}
      DOCKER_PULL_TAG=${ARCH}-${DOCKER_TAG}  # pull registry/namespace/image:arch-tag
    fi

    DOCKER_REPO=$(strip-uri ${DOCKER_REPO})
    
    echo "INFO: Pulling ${DOCKER_REPO}:${DOCKER_PULL_TAG}"
    if [[ ! ${IS_DRY_RUN} = true ]]; then
      docker pull ${DOCKER_REPO}:${DOCKER_PULL_TAG}
    fi
  done

  # --------------------------------------------------------------------------
  #  ____  __    ___     __   __ _  ____    ____  _  _  ____  _  _ 
  # (_  _)/ _\  / __)   / _\ (  ( \(    \  (  _ \/ )( \/ ___)/ )( \
  #   )( /    \( (_ \  /    \/    / ) D (   ) __/) \/ (\___ \) __ (
  #  (__)\_/\_/ \___/  \_/\_/\_)__)(____/  (__)  \____/(____/\_)(_/
  # --------------------------------------------------------------------------

  # Tag each image option for all the supported architectures
  for ARCH in ${SUPPORTED_ARCHITECTURES}; do
    for TAG in ${TAGS}; do
      if [[ ${DOCKER_OFFICIAL} = true ]]; then
        # mimic the official build formats  i.e. registry/arch/image:tag
        DOCKER_REPO=${DOCKER_REGISTRY}/${ARCH}/${DOCKER_IMAGE_NAME}
        DOCKER_PULL_TAG=${DOCKER_TAG}
        original_docker_image=${DOCKER_REPO}:${DOCKER_PULL_TAG} # already pushed (pulled earlier)
        tagged_docker_image=${DOCKER_REPO}:${TAG} # tag and push
      fi

      if [[ ${DOCKER_OFFICIAL} = false ]]; then
        # build for regular user like format  i.e. registry/namespace/image:arch-tag
        DOCKER_REPO=${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${DOCKER_IMAGE_NAME}
        DOCKER_PULL_TAG=${ARCH}-${DOCKER_TAG}
        original_docker_image=${DOCKER_REPO}:${DOCKER_PULL_TAG} # already pushed (pulled earlier)
        tagged_docker_image=${DOCKER_REPO}:${ARCH}-${TAG} # tag and push
      fi

      # strip off all leading '/' characters to account for Registry and Namespaces
      original_docker_image=$(strip-uri ${original_docker_image})
      tagged_docker_image=$(strip-uri ${tagged_docker_image})

      echo "INFO: Tagging ${original_docker_image} as ${tagged_docker_image}"
      if [[ ! ${IS_DRY_RUN} = true ]]; then
        docker tag ${original_docker_image} ${tagged_docker_image}
        docker push ${tagged_docker_image}
      fi
    done
  done

fi
