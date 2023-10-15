FROM debian:bullseye-slim as builder
LABEL maintainer=james@peddler.com

WORKDIR /

RUN echo "Updating apt-get and installing dependencies..." && \
  apt-get -y update > /dev/null && apt-get -y install > /dev/null \
  git-core \
  build-essential \
	g++ \
  libssl-dev \
	libasio-dev \
  libglpk-dev \
	pkg-config

ARG VROOM_RELEASE=v1.13.0

RUN echo "Cloning and installing vroom release ${VROOM_RELEASE}..." && \
    git clone  --recurse-submodules https://github.com/VROOM-Project/vroom.git && \
    cd vroom && \
    git fetch --tags && \
    git checkout -q $VROOM_RELEASE && \
    make -C /vroom/src -j$(nproc) && \
    cd /

ARG VROOM_EXPRESS_AWS_LAMBDA_RELEASE=v0.0.1

RUN echo "Cloning and installing vroom-express-aws-lambda release ${VROOM_EXPRESS_AWS_LAMBDA_RELEASE}..." && \
    git clone https://github.com/jamesjjk/vroom-express-aws-lambda.git && \
    cd vroom-express-aws-lambda && \
    git fetch --tags && \
    git checkout $VROOM_EXPRESS_AWS_LAMBDA_RELEASE

FROM node:14.21.3-bullseye-slim as runstage
COPY --from=builder /vroom-express-aws-lambda/. /vroom-express-aws-lambda
COPY --from=builder /vroom/bin/vroom /usr/local/bin

WORKDIR /vroom-express-aws-lambda

RUN apt-get update > /dev/null && \
    apt-get install -y --no-install-recommends \
      libssl1.1 \
      curl \
      libglpk40 \
      > /dev/null && \
    rm -rf /var/lib/apt/lists/* && \
    # Install vroom-express
    npm config set loglevel error && \
    npm install && \
    npm install aws-lambda-ric && \
    # To share the config.yml & access.log file with the host
    mkdir /conf


COPY ./docker-entrypoint.sh /docker-entrypoint.sh
ENV VROOM_DOCKER=osrm \
    VROOM_LOG=/conf

HEALTHCHECK --start-period=10s CMD curl --fail -s http://localhost:3000/health || exit 1

EXPOSE 3000
ENTRYPOINT ["/bin/bash", "aws-lambda-ric"]
# CMD ["/docker-entrypoint.sh"]
CMD ["index.handler"]
