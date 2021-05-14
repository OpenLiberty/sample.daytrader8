# Docker CI/CD Build scripts

These build scripts were created to enable commit based docker container publishing using CI/CD pipelines like TravisCI or Jenkins.

## Setup
### ENV Vars
- `GIT_BRANCH` - The name of the branch for current build
  - travis has `TRAVIS_BRANCH` containing the current value
  - Jenkins sets the `GIT_BRANCH` when using the git plugin
- `IS_PULL_REQUEST` - images are only processed when set to `false` and `GIT_BRANCH=master`
  - travis has `TRAVIS_PULL_REQUEST` with the current value as true or false
  - Jenkins has [GitHub Pull Request Builder Plugin](https://github.com/jenkinsci/ghprb-plugin) that can be configured to monitor pull requests and regular commits
- `DOCKER_REGISTRY` - the docker registry to use (leave blank if using DockerHub)
- `DOCKER_NAMESPACE` - the namespace in the docker registry to use (DockerHub username if using DockerHub, any if using private registry)
- `SUPPORTED_ARCHITECTURES` - Space separated list of architectures that this docker image will build for i.e. `"amd64 s390x ppc64le"`
- `DOCKER_USER` - the username credential for the ci pipeline to publish as
- `DOCKER_PASS` - the password credential for the ci pipeline to publish as


## Usage

### `build.sh`
The `build` script is used to build an image to a docker repo on DockerHub or a private registry. This script supports the ability for you to push to your private registry as an official image, if desired.

An official image is an image on DockerHub that has been published to the library namespace (`library/ubuntu:latest`). The official images have their multi-architecture tags published to the namespace matching the arch that is supported by the image (`amd64/ubuntu:latest`).

Using the `--official` and `--push` flags will publish your images to the namespaces included in the `SUPPORTED_ARCHITECTURES` variable (i.e `"amd64 s390x ..."`). This will prepare the image for a manifest under the `library` namespace like an official image.

To test an image prior to publishing, simply omit the `--push` flag from your `build.sh` command. This will build the image on the local system enabling the execution of container verification testing. If your testing has met the publishing requirements use the [push.sh](#pushsh) script to complete publication of the new image.

The following usage examples showcase the `build` command, pushing official and non official images.

###### official image
```
./.ci/build.sh --file 8/jdk/Dockerfile.openj9 --image ycsb --tag 0.17.0-8-jdk-openj9-bionic --build-args "YCSB_VERSION=${VERSION}" --push --official
```
This will build an image as `${DOCKER_REGISTRY}/${ARCH}/ycsb:0.17.0-8-jdk-openj9-bionic`. This image will be uploaded to the specified docker registry under the architecture namespace to mimic the official DockerHub images.

###### unofficial image/custom private registry
```
./.ci/build.sh --file 8/jdk/Dockerfile.openj9 --image ycsb --tag 0.17.0-8-jdk-openj9-bionic --build-args "YCSB_VERSION=${VERSION}" --push
```
This will build an image as `${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/ycsb:${ARCH}-0.17.0-8-jdk-openj9-bionic`. This image will be uploaded to the specified docker registry and namespace with the architecture appended to the front of the build tag

### `push.sh`
The `push` script is used to push a specified image, that has been built, to a docker repo on DockerHub or a private registry. This script supports the ability for you to push to your private registry as an official image, if desired. This is only needed if not using the `--push` flag in the [build.sh](#buildsh) script.

The following usage examples showcase the `push` command, pushing official and non official images.

###### official image
```
./.ci/push.sh --image ycsb:0.17.0-8-jdk-openj9-bionic --official
```
This will push the image as `${DOCKER_REGISTRY}/${ARCH}/ycsb:0.17.0-8-jdk-openj9-bionic`. This image will be uploaded to the specified docker registry under the architecture namespace to mimic the official DockerHub images.

###### unofficial image/custom private registry
```
./.ci/push.sh --image ycsb:0.17.0-8-jdk-openj9-bionic
```
This will push the image as `${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/ycsb:${ARCH}-0.17.0-8-jdk-openj9-bionic`. This image will be uploaded to the specified docker registry and namespace with the architecture appended to the front of the build tag

### `tag-image.sh`
The `tag-image` script is used to give a built variant image, that was pushed to either DockerHub or a private registry, new tags for referencing the image at a higher level.

This script additionally supports re-tagging images that have been published to your private registry as official images. For what an official image means, [reference the `build.sh` section](#buildsh)

The following usage examples showcase the `tag-image` command, pushing official and non official tags.

###### official image
```
./.ci/tag-image.sh --image ycsb:0.17.0-8-jdk-openj9-bionic --tags "0.17.0-8-jdk-bionic latest" --official
```
This will tag the image `${DOCKER_REGISTRY}/${ARCH}/ycsb:0.17.0-8-jdk-openj9-bionic` as `${DOCKER_REGISTRY}/${ARCH}/ycsb:0.17.0-8-jdk-bionic` and `${DOCKER_REGISTRY}/${ARCH}/ycsb:latest`. This will enable the creation of a docker manifest, letting users pull the image from any supported architecture without specifying what architecture is desired at the time of pulling.

###### unofficial image/custom private registry
```
./.ci/tag-image.sh --image ycsb:0.17.0-8-jdk-openj9-bionic --tags "0.17.0-8-jdk-bionic latest"
```
This will tag the image `${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/ycsb:${ARCH}-0.17.0-8-jdk-openj9-bionic` as `${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/ycsb:${ARCH}-0.17.0-8-jdk-bionic` and `${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/ycsb:${ARCH}-latest`. This will enable the creation of a docker manifest, letting users pull the image from any supported architecture without specifying what architecture is desired at the time of pulling. The `DOCKER_NAMESPACE` variable will be used to determine where this tag is pushed.

### `enable-experimental.sh`
This script will enable experimental mode on the docker host. As of right now docker manifest is still an experimental feature and requires the host to be in experimental mode. This script will configure that and restart the docker service so that we can build a manifest of our multi-arch images.
```
./.ci/enable-experimental.sh
```

### `manifest.sh`
The `manifest` script is used to create docker manifests to enable multi-architecture images.

This script additionally supports publishing manifests for images that have been published to your private registry as official using the `--official` flag. For what an official image means, [reference the `build.sh` section](#buildsh).

Using the `--push` flag will run a `push --prune` of the docker manifest to the docker registry. Without this flag the manifest will reside on the local machine and will not be pushed to the registry.

The following usage examples showcase the `manifest` command, publishing manifests for official and non official images.

###### official image
```
./.ci/manifest.sh --image ycsb --manifest 0.17.0-8-jdk-openj9-bionic --push --official
```
This will create a docker manifest which will enable pulling from `${DOCKER_REGISTRY}/library/ycsb:0.17.0-8-jdk-openj9-bionic` and include all images under the `SUPPORTED_ARCHITECTURES` env variable. For example if `SUPPORTED_ARCHITECTURES="amd64 s390x ppc64le"` the manifest that is generated will be like so.
- `${DOCKER_REGISTRY}/library/ycsb:0.17.0-8-jdk-openj9-bionic`
  - `${DOCKER_REGISTRY}/amd64/ycsb:0.17.0-8-jdk-openj9-bionic`
  - `${DOCKER_REGISTRY}/s390x/ycsb:0.17.0-8-jdk-openj9-bionic`
  - `${DOCKER_REGISTRY}/ppc64le/ycsb:0.17.0-8-jdk-openj9-bionic`

###### unofficial image/custom private registry
```
./.ci/manifest.sh --image ycsb --manifest 0.17.0-8-jdk-openj9-bionic --push
```
This will create a docker manifest which will enable pulling from `${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/ycsb:0.17.0-8-jdk-openj9-bionic` and include all images under the `SUPPORTED_ARCHITECTURES` env variable. For example  if `SUPPORTED_ARCHITECTURES="amd64 s390x ppc64le"` the manifest that is generated will be like so.
- `${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/ycsb:0.17.0-8-jdk-openj9-bionic`
  - `${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/ycsb:amd64-0.17.0-8-jdk-openj9-bionic`
  - `${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/ycsb:s390x-0.17.0-8-jdk-openj9-bionic`
  - `${DOCKER_REGISTRY}/${DOCKER_NAMESPACE}/ycsb:ppc64le-0.17.0-8-jdk-openj9-bionic`
