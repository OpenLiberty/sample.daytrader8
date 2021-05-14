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
# SUPPORTED_ARCHITECTURES - Which architectures the docker image supports and manifests will be generated for

source ./.ci/common-functions.sh > /dev/null 2>&1 || source ./ci/common-functions.sh > /dev/null 2>&1

IMAGE_MANIFEST=""        # The variant tag that will be used for the creation of the manifest, mapping all arch images to
LATEST=false            # Flag set if the docker manifest should include the latest image (usually the most verbose default variant/tag)
DOCKER_OFFICIAL=false   # mimic the official docker publish method for images in private registries
DOCKER_PUSH=false       # flag to push a docker manifest to a registry after being created
IS_DRY_RUN=false        # Prints out what will happen rather than running the commands

usage() {
  echo -e "A docker container manifest create script for ci pipelines \n\n"
  echo "Usage:"
  echo "${0} --image example-docker-manifest --manifest 1.0.0-8-jdk-openj9-bionic [--latest] [--push] [--official] [--dry-run]"
  echo ""
}

if [[ "$*" == "" ]] || [[ "$*" != *--image* ]] || [[ "$*" != *--manifest* ]]; then
  usage
  exit 1
fi

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        -i|--image)
        DOCKER_IMAGE=$2
        shift
        ;;
        --manifest)
        IMAGE_MANIFEST=$2
        shift
        ;;
        -l|--latest)
        LATEST=true
        ;;
        -o|--official)
        DOCKER_OFFICIAL=true
        ;;
        --push)
        DOCKER_PUSH=true
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

# Only build on master branch and NOT PR
if [[ "${GIT_BRANCH}" == "master" ]] && [[ "${IS_PULL_REQUEST}" == "false" ]]; then
    
    # ------------------------------
    #  ____  ____  ____  _  _  ____ 
    # / ___)(  __)(_  _)/ )( \(  _ \
    # \___ \ ) _)   )(  ) \/ ( ) __/
    # (____/(____) (__) \____/(__)  
    # ------------------------------

    DOCKER_TAG=""  # A unique tag for our docker image using the {image_version}-{image_variant}

    if [[ -z ${DOCKER_IMAGE} ]] || [[ -z ${IMAGE_MANIFEST} ]]; then
        echo "Both --image and --manifest must be set to use this script!"
        echo "--image='${DOCKER_IMAGE}'"
        echo "--manifest='${IMAGE_MANIFEST}'"
        exit 1
    fi

    DOCKER_TAG=${DOCKER_TAG}-${IMAGE_MANIFEST}
    
    DOCKER_TAG=$(echo ${DOCKER_TAG} | sed 's/^-*//')  # strip off all leading '-' characters

    if [[ ${IS_DRY_RUN} = true ]]; then
        echo "INFO: Dry run executing, nothing will be pushed/run"
    fi

    # This uses DOCKER_USER and DOCKER_PASS to login to DOCKER_REGISTRY
    if [[ ! ${IS_DRY_RUN} = true ]]; then
        docker-login
    fi
    

    # Pull each of our docker images on the supported architectures
    for ARCH in ${SUPPORTED_ARCHITECTURES}; do
        if [[ ${DOCKER_OFFICIAL} = true ]]; then
            DOCKER_REPO=${DOCKER_REGISTRY}/${ARCH}/${DOCKER_IMAGE}
            DOCKER_PULL_TAG=${DOCKER_TAG}  # pull registry/arch/image:tag
            DOCKER_PULL_LATEST=latest
        fi

        if [[ ${DOCKER_OFFICIAL} = false ]]; then
            DOCKER_REPO=${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/${DOCKER_IMAGE}
            DOCKER_PULL_TAG=${ARCH}-${DOCKER_TAG}  # pull registry/namespace/image:arch-tag
            DOCKER_PULL_LATEST=${ARCH}-latest
        fi

        DOCKER_REPO=$(strip-uri ${DOCKER_REPO})

        echo "INFO: Pulling ${DOCKER_REPO}:${DOCKER_PULL_TAG}"
        if [[ ! ${IS_DRY_RUN} = true ]]; then
            docker pull ${DOCKER_REPO}:${DOCKER_PULL_TAG}
        fi
        
        if [[ ${LATEST} = true ]]; then
            # the latest flag has been set, pull the latest image
            echo "INFO: Pulling ${DOCKER_REPO}:${DOCKER_PULL_LATEST}"
            if [[ ! ${IS_DRY_RUN} = true ]]; then
                docker pull ${DOCKER_REPO}:${DOCKER_PULL_LATEST}
            fi
            
        fi
    done

    # -----------------------------------------------------------------------------------
    #  _  _   __   __ _  __  ____  ____  ____  ____     ___  ____  ____   __  ____  ____ 
    # ( \/ ) / _\ (  ( \(  )(  __)(  __)/ ___)(_  _)   / __)(  _ \(  __) / _\(_  _)(  __)
    # / \/ \/    \/    / )(  ) _)  ) _) \___ \  )(    ( (__  )   / ) _) /    \ )(   ) _) 
    # \_)(_/\_/\_/\_)__)(__)(__)  (____)(____/ (__)    \___)(__\_)(____)\_/\_/(__) (____)
    # -----------------------------------------------------------------------------------

    if [[ ${IS_DRY_RUN} = true ]]; then
        echo "INFO: Creating Manifests"
    fi

    # Create the manifest for our DOCKER_TAG
    docker_manifest="$(build-manifest-cmd-for-tag ${DOCKER_TAG})"
    # Run the docker_manifest string
    if [[ ${IS_DRY_RUN} = true ]]; then
        echo "${docker_manifest}"
    else
        eval "${docker_manifest}"
    fi

    if [[ ${LATEST} = true ]]; then
        # create the latest manifest if the LATEST flag is true
        docker_manifest="$(build-manifest-cmd-for-tag latest)"
        # Run the docker_manifest string
        if [[ ${IS_DRY_RUN} = true ]]; then
            echo "${docker_manifest}"
        else
            eval "${docker_manifest}"
        fi
    fi

    # ---------------------------------------------------------------------------------------------
    #  _  _   __   __ _  __  ____  ____  ____  ____     __   __ _  __ _   __  ____  __  ____  ____ 
    # ( \/ ) / _\ (  ( \(  )(  __)(  __)/ ___)(_  _)   / _\ (  ( \(  ( \ /  \(_  _)/ _\(_  _)(  __)
    # / \/ \/    \/    / )(  ) _)  ) _) \___ \  )(    /    \/    //    /(  O ) )( /    \ )(   ) _) 
    # \_)(_/\_/\_/\_)__)(__)(__)  (____)(____/ (__)   \_/\_/\_)__)\_)__) \__/ (__)\_/\_/(__) (____)
    # ---------------------------------------------------------------------------------------------

    if [[ ${IS_DRY_RUN} = true ]]; then
        echo "INFO: Annotating Manifests"
    fi

    # Annotate the manifest for our DOCKER_TAG
    manifest_annotate=$(annotate-manifest-for-tag ${DOCKER_TAG})
    # Run the manifest_annotate string
    if [[ ${IS_DRY_RUN} = true ]]; then
        echo "${manifest_annotate}"
    else
        eval "${manifest_annotate}"
    fi

    if [[ ${LATEST} = true ]]; then
        # create the latest manifest if the LATEST flag is true
        manifest_annotate=$(annotate-manifest-for-tag "latest")
        if [[ ${IS_DRY_RUN} = true ]]; then
            echo "${manifest_annotate}"
        else
            eval "${manifest_annotate}"
        fi
    fi

    # ---------------------------------------------------------------------------------------------
    #  _  _   __   __ _  __  ____  ____  ____  ____    ____  _  _  ____  _  _ 
    # ( \/ ) / _\ (  ( \(  )(  __)(  __)/ ___)(_  _)  (  _ \/ )( \/ ___)/ )( \
    # / \/ \/    \/    / )(  ) _)  ) _) \___ \  )(     ) __/) \/ (\___ \) __ (
    # \_)(_/\_/\_/\_)__)(__)(__)  (____)(____/ (__)   (__)  \____/(____/\_)(_/
    # ---------------------------------------------------------------------------------------------

    # Push the manifest for our DOCKER_TAG
    if [[ ${DOCKER_PUSH} = true ]]; then
        if [[ ${IS_DRY_RUN} = true ]]; then
            echo "INFO: Pushing Manifests"
        fi
        manifest_push=$(push-manifest-for-tag ${DOCKER_TAG})
        # Run the manifest_push string
        if [[ ${IS_DRY_RUN} = true ]]; then
            echo "${manifest_push}"
        else
            eval "${manifest_push}"
        fi

        if [[ ${LATEST} = true ]]; then
            # push latest manifest if the LATEST flag is true
            manifest_push=$(push-manifest-for-tag "latest")
            if [[ ${IS_DRY_RUN} = true ]]; then
                echo "${manifest_push}"
            else
                eval "${manifest_push}"
            fi
        fi
    fi

fi
