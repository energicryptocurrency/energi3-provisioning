ARG ENERGI_VERSION

FROM energicryptocurrency/energi:${ENERGI_VERSION}

ARG ENERGI_BIN
ARG ENERGI_CORE_DIR
ARG USER_AND_GROUP_ID=1000
ARG USERNAME=nrgstaker
ARG STAKER_HOME

ENV ENERGI_BIN="${ENERGI_BIN:?}"
ENV ENERGI_CORE_DIR="${ENERGI_CORE_DIR:?}"
ENV STAKER_HOME="${STAKER_HOME:?}"
ENV SSHD_DIR="${STAKER_HOME}/.sshd"

WORKDIR "${STAKER_HOME}/energi"

RUN addgroup --gid ${USER_AND_GROUP_ID} ${USERNAME} \
  && adduser \
  --uid ${USER_AND_GROUP_ID} ${USERNAME} \
  --ingroup ${USERNAME} \
  --disabled-password; \
  apk --no-cache add curl openssh-server-pam procps; \
  cd "$( dirname "${ENERGI_BIN}" )" \
  && ln -s energi3 "$( basename "${ENERGI_BIN}" )"; \
  mkdir -p ${SSHD_DIR} \
  && ssh-keygen -f ${SSHD_DIR}/host_rsa_key -N '' -t rsa \
  && ssh-keygen -f ${SSHD_DIR}/host_dsa_key -N '' -t dsa; \
  mkdir ${ENERGI_CORE_DIR}; \
  chown -R ${USERNAME}:${USERNAME} ${STAKER_HOME}

COPY --chown=${USERNAME}:${USERNAME} [ ".sshd", "${SSHD_DIR}/" ]
RUN chmod 755 ${SSHD_DIR} && chmod 600 "${SSHD_DIR}/authorized_keys"

COPY --chown=${USERNAME}:${USERNAME} [ "scripts", "./" ]

USER ${USERNAME}

ENTRYPOINT ["/bin/sh", "energi-core-run.sh"]
