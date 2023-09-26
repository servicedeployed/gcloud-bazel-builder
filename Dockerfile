FROM gcr.io/gcp-runtimes/ubuntu_20_0_4 as gcp-base

ADD bazel.sh /builder/bazel.sh

ARG DOCKER_VERSION=5:19.03.9~3-0~ubuntu-focal

RUN \
    # This makes add-apt-repository available.
    apt-get update && \
    apt-get -y install \
        python \
        python3 \
        python-pkg-resources \
        python3-pkg-resources \
        software-properties-common \
        unzip && \

    # Install Git >2.0.1
    add-apt-repository ppa:git-core/ppa && \
    apt-get -y update && \
    apt-get -y install git && \

    # Install bazel (https://docs.bazel.build/versions/master/install-ubuntu.html)
    apt-get -y install openjdk-8-jdk && \
    echo "deb [arch=amd64] http://storage.googleapis.com/bazel-apt stable jdk1.8" | tee /etc/apt/sources.list.d/bazel.list && \
    curl https://bazel.build/bazel-release.pub.gpg | apt-key add - && \
    apt-get update && \

    apt-get -y install bazel && \
    apt-get -y upgrade bazel && \

    # Install Docker (https://docs.docker.com/engine/installation/linux/docker-ce/ubuntu/#uninstall-old-versions)
    apt-get -y install \
        linux-image-extra-virtual \
        apt-transport-https \
        curl \
        ca-certificates && \
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add - && \
    add-apt-repository \
      "deb [arch=amd64] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) \
      stable edge" && \
    apt-get -y update && \
    apt-get install -y docker-ce=${DOCKER_VERSION} docker-ce-cli=${DOCKER_VERSION} unzip && \

    mv /usr/bin/bazel /builder/bazel           && \
    mv /usr/bin/bazel-real /builder/bazel-real && \
    mv /builder/bazel.sh /usr/bin/bazel        && \

    # Unpack bazel for future use.
    bazel version

# Store the Bazel outputs under /workspace so that the symlinks under bazel-bin (et al) are accessible
# to downstream build steps.
RUN mkdir -p /workspace
RUN echo 'startup --output_base=/workspace/.bazel' > ~/.bazelrc

ENTRYPOINT ["bazel"]

FROM gcp-base

# MongoCrypt
ARG UBUNTU_VERSION=focal
ARG LIBMONGOCRYPT_VERSION=1.5
ARG MONGODB_ENTERPRISE_VERSION=6.0

RUN sh -c 'curl -s --location https://www.mongodb.org/static/pgp/libmongocrypt.asc | gpg --dearmor >/etc/apt/trusted.gpg.d/libmongocrypt.gpg'
RUN echo "deb https://libmongocrypt.s3.amazonaws.com/apt/ubuntu ${UBUNTU_VERSION}/libmongocrypt/${LIBMONGOCRYPT_VERSION} universe" | tee /etc/apt/sources.list.d/libmongocrypt.list
RUN apt-get update -y
RUN apt-get install -y libmongocrypt-dev wget libbson-dev
RUN ldconfig
RUN wget -qO - https://www.mongodb.org/static/pgp/server-${MONGODB_ENTERPRISE_VERSION}.asc | apt-key add -
RUN echo "deb http://repo.mongodb.com/apt/ubuntu ${UBUNTU_VERSION}/mongodb-enterprise/${MONGODB_ENTERPRISE_VERSION} multiverse" | tee /etc/apt/sources.list.d/mongodb-enterprise.list
RUN apt-get update -y
RUN apt-get install -y mongodb-enterprise-cryptd pkg-config

# Kubectl
RUN curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
RUN install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
RUN kubectl version --client

# Golang
ARG GO_VERSION="1.21.1"
ARG ARCH="amd64"

RUN wget -c "https://golang.org/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" -O - | tar -xz -C /usr/local
ENV PATH=$PATH:/usr/local/go/bin
RUN go version

# Google Cloud
RUN echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" | tee -a /etc/apt/sources.list.d/google-cloud-sdk.list
RUN apt-get install apt-transport-https ca-certificates gnupg curl -y
RUN curl https://packages.cloud.google.com/apt/doc/apt-key.gpg | apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
RUN apt-get update && apt-get install google-cloud-sdk google-cloud-sdk-gke-gcloud-auth-plugin -y
ENV USE_GKE_GCLOUD_AUTH_PLUGIN=True

# Make
RUN apt-get install -y apt-utils make

# Git
RUN apt-get install git

# Keep Original ENTRYPOINT
WORKDIR /workspace
ENTRYPOINT ["bazel"]