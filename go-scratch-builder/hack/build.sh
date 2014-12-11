#!/bin/bash -ex
#
# This is an example of the Origin custom builder that builds a minimal Docker
# image with static Go binary.
# This requires the project you are going to build has 'main.go' in the root
# repository folder and it is hosted on Github.

# Convert SOURCE_URI which is a full GIT url into a Go package name format
PACKAGE_NAME=$(echo -n $SOURCE_URI | sed -e 's/^git:\/\///' | sed -e 's/\.git$//')

# FIXME: This will work only for github.com/name/project and it assume you have
#        'main.go' in the repository root. You can overide this by setting
#        BINARY_NAME in buildConfig.
BINARY_NAME=${BINARY_NAME:-$(echo -n $PACKAGE_NAME | cut -d '/' -f 3)}

# The OUTPUT_IMAGE and OUTPUT_REGISTRY are sent from the Origin and they are
# part of the 'Build' (you can also query them from $BUILD variable)
DOCKER_REGISTRY="${OUTPUT_REGISTRY}/${OUTPUT_IMAGE}"

# The 'EXPOSE_PORT' can be defined as an environment variable for the custom
# build (see: Build.parameters.strategy.customStrategy.env[])
EXPOSE_PORT=${EXPOSE_PORT:-"8080"}

# This will download the Go package, compile it and build a static binary.
CGO_ENABLED=0 go get -a -ldflags '-s' ${PACKAGE_NAME}

# Convert the static Go binary into minimal Docker image
(cd /gopath/bin && tar cv ${BINARY_NAME}) | docker import - ${OUTPUT_IMAGE}-base

# The 'docker build' need a special empty directory, otherwise you will get
# permission denied errors 
mkdir -p /build

# Augument the minimal Docker image with EXPOSE and with CMD
cat > /build/Dockerfile <<- EOF
FROM ${OUTPUT_IMAGE}-scratch
ENV EXPOSE_PORT ${EXPOSE_PORT}
EXPOSE ${EXPOSE_PORT}
CMD ["${BINARY_NAME}"]
EOF

pushd /build >/dev/null
# Build the final minimal Docker image with Go static binary
docker build --no-cache --rm -t ${OUTPUT_IMAGE} .

# Remove the temporary Docker image
docker rmi ${OUTPUT_IMAGE}-base

# Push the image to Docker registry
docker tag ${OUTPUT_IMAGE} ${DOCKER_REGISTRY}
docker push ${DOCKER_REGISTRY}
popd >/dev/null
