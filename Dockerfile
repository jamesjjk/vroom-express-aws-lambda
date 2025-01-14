# Define custom function directory
ARG FUNCTION_DIR="/function"

FROM node:14-buster as builder
LABEL maintainer=james@peddler.com

# Include global arg in this stage of the build
ARG FUNCTION_DIR

WORKDIR /

RUN echo "Updating apt-get and installing dependencies..." && \
  apt-get -y update > /dev/null && apt-get -y install > /dev/null \
  git-core \
  build-essential \
  g++ \
  make \
  cmake \
  unzip \
  libcurl4-openssl-dev \
  libssl-dev \
	libasio-dev \
  libglpk-dev \
	pkg-config

ARG VROOM_RELEASE=v1.13.0

RUN echo "Cloning and installing vroom release ${VROOM_RELEASE}..." && \
    git clone --branch $VROOM_RELEASE --recurse-submodules https://github.com/VROOM-Project/vroom.git && \
    cd vroom && \
    make -C /vroom/src -j$(nproc) && \
    cd /

ARG VROOM_EXPRESS_AWS_LAMBDA_RELEASE=master

# RUN echo "Cloning and installing vroom-express-aws-lambda release ${VROOM_EXPRESS_AWS_LAMBDA_RELEASE}..." && \
#     git clone https://github.com/jamesjjk/vroom-express-aws-lambda.git && \
#     cd vroom-express-aws-lambda && \
#     git fetch --tags && \
#     git checkout $VROOM_EXPRESS_AWS_LAMBDA_RELEASE

RUN mkdir -p /vroom-express-aws-lambda
COPY . /vroom-express-aws-lambda
WORKDIR /vroom-express-aws-lambda

# Install the runtime interface client
RUN npm install aws-lambda-ric

# Install vroom-express
RUN npm config set loglevel error && \
  npm install

FROM node:14-buster-slim as runstage

# Include global arg in this stage of the build
ARG FUNCTION_DIR

# Set working directory to function root directory
WORKDIR ${FUNCTION_DIR}

COPY --from=builder /vroom-express-aws-lambda/. ${FUNCTION_DIR}
COPY --from=builder /vroom/bin/vroom /usr/local/bin

ENV NPM_CONFIG_CACHE=/tmp/.npm

# WORKDIR /vroom-express-aws-lambda

RUN apt-get update > /dev/null && \
    apt-get install -y --no-install-recommends \
      libssl1.1 \
      curl \
      libglpk40 \
      > /dev/null && \
    rm -rf /var/lib/apt/lists/* && \
    # To share the config.yml & access.log file with the host
    mkdir /conf


# COPY ./docker-entrypoint.sh /docker-entrypoint.sh
ENV VROOM_DOCKER=osrm \
    VROOM_LOG=/conf

ENTRYPOINT ["/usr/local/bin/npx", "aws-lambda-ric"]
CMD ["index.handler"]
