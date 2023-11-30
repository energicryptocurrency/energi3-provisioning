# Build the binary `energi3` in a stock Go builder container
FROM golang:1.15-buster as energi-builder

ARG ENERGI_VERSION

RUN apt-get update \
  && apt-get install --assume-yes --no-install-recommends --quiet musl-dev; \
  git clone --branch ${ENERGI_VERSION} --depth 1 \
    https://github.com/energicryptocurrency/energi.git energi \
  && cd energi \
  && make geth


# `ubuntu:latest` means "The latest Ubuntu LTS release"
# https://hub.docker.com/_/ubuntu
FROM ubuntu:latest

ARG DEBIAN_FRONTEND=noninteractive
ARG ECNM_DATA_DIR=/var/multi-masternode-data/nodebot
ARG ENERGI_BIN
ARG ENERGI_CORE_DIR
ARG LOG_DIR=/var/log
ARG USER_AND_GROUP_ID=1000
ARG USERNAME=nrgstaker
ARG STAKER_HOME
ARG NODEMON_LOG_DIR=${STAKER_HOME}/log
ARG SSH_DIR=${STAKER_HOME}/.ssh

ENV ENERGI_BIN="${ENERGI_BIN:?}"
ENV ENERGI_CORE_DIR="${ENERGI_CORE_DIR:?}"
ENV STAKER_HOME=${STAKER_HOME:?}

RUN apt-get update --quiet \
  && apt-get upgrade --assume-yes --quiet \
  && apt-get install --assume-yes --no-install-recommends --quiet \
    bc \
    ca-certificates \
    curl \
    debsums \
    init \
    jq \
    logrotate \
    ntpdate \
    openssh-client \
    rkhunter \
    sqlite3 \
    sudo \
    tzdata \
    wget; \
  apt-get clean all \
  && rm --recursive --force /var/lib/apt/lists/*; \
  addgroup --gid ${USER_AND_GROUP_ID} ${USERNAME} \
  && adduser \
    --uid ${USER_AND_GROUP_ID} ${USERNAME} \
    --ingroup ${USERNAME} \
    --disabled-password \
    --quiet; \
  usermod --append --groups sudo ${USERNAME}; \
  mkdir --parents ${ECNM_DATA_DIR} \
  && chown --recursive ${USERNAME} ${ECNM_DATA_DIR}; \
  mkdir --parents "${ENERGI_CORE_DIR}" \
  && mkdir --parents ${SSH_DIR}; \
  mkdir --parents ${NODEMON_LOG_DIR} \
  && touch ${NODEMON_LOG_DIR}/nodemon.log; \
  chown --recursive ${USERNAME}:${USERNAME} ${STAKER_HOME}; \
  touch ${LOG_DIR}/auth.log \
  && touch ${LOG_DIR}/kern.log

COPY --from=energi-builder [ "/go/energi/build/bin/energi3", "${ENERGI_BIN}" ]
COPY --chown=${USERNAME}:${USERNAME} [ ".ssh", "${SSH_DIR}/" ]
COPY [ "etc", "/etc" ]

RUN chmod +x ${ENERGI_BIN} && chmod -R 600 ${SSH_DIR}/id_rsa

WORKDIR ${STAKER_HOME}

COPY --chown=${USERNAME}:${USERNAME} [ "scripts", "./" ]

USER ${USERNAME}

ENTRYPOINT [ "bash", "nodemon_cron.sh" ]
