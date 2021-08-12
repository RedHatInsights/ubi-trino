FROM quay.io/centos/centos:centos7 as build

ARG TRINO_VERSION=348
ENV TRINO_RELEASE_TAG=${TRINO_VERSION}
ENV TRINO_RELEASE_TAG_RE=".*refs/tags/${TRINO_RELEASE_TAG}\$"

RUN yum -y update && yum clean all

RUN set -x && \
    INSTALL_PKGS="java-11-openjdk java-11-openjdk-devel openssl less maven rsync diffutils git python3" \
    && yum clean all && rm -rf /var/cache/yum/* \
    && yum install -y \
        $INSTALL_PKGS  \
    && yum clean all \
    && rm -rf /var/cache/yum

# Originally, this was a *lot* of COPY layers
RUN git clone -q \
        -b $(git ls-remote --tags https://github.com/trinodb/trino | grep -E "${TRINO_RELEASE_TAG_RE}" | sed -E 's/.*refs.tags.(.*)/\1/g') \
        --single-branch \
        https://github.com/trinodb/trino.git \
        /build

# ======================================
# ======================================
# AS OF RELEASE 351, Presto has been rebranded to Trino.
# The project changed a bit. To build trino, use this build command instead.
#RUN cd /build \
#    && JAVA_HOME=/etc/alternatives/jre_11_openjdk ./mvnw clean package -DskipTests -pl '!docs'
# ======================================
# ======================================
# build presto
RUN cd /build \
    && JAVA_HOME=/etc/alternatives/jre_11_openjdk ./mvnw clean package -DskipTests -pl '!presto-docs'
# ======================================
# ======================================

# Install prometheus-jmx agent
RUN cd / \
    && mvn org.apache.maven.plugins:maven-dependency-plugin:2.10:get \
           -DremoteRepositories=https://mvnrepository.com/artifact/io.prometheus.jmx/jmx_prometheus_javaagent \
           -Dartifact=io.prometheus.jmx:jmx_prometheus_javaagent:0.3.1:jar \
           -Ddest=/build/jmx_prometheus_javaagent.jar

FROM registry.access.redhat.com/ubi8/ubi

RUN set -x; \
    yum clean all \
    && rm -rf /var/cache/yum/* \
    && yum install --setopt=skip_missing_names_on_install=False -y \
                   java-11-openjdk \
                   java-11-openjdk-devel \
                   openssl \
                   less \
                   rsync \
                   curl \
                   diffutils \
                   jq \
    && yum install -y python3 \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && ln -s /usr/bin/python3.6 /usr/bin/python

ENV TINI_VERSION v0.18.0
ADD https://github.com/krallin/tini/releases/download/${TINI_VERSION}/tini /usr/bin/tini
RUN chmod +x /usr/bin/tini

# ======================================
# ======================================
# AS OF RELEASE 351, Presto has been rebranded to Trino.
# The project changed a bit. To use trino, use these vars instead
#ENV _APP_NAME=presto
## Keep this in sync with ARG TRINO_VERSION above
#ENV TRINO_VERSION=348
#ENV TRINO_HOME=/opt/trino/trino-server
#ENV TRINO_CLI=/opt/trino/trino-cli
#ENV _APP_HOME=${TRINO_HOME}
#ENV _APP_CLI=${TRINO_CLI}
# ======================================
# ======================================
ENV _APP_NAME=presto
# Keep this in sync with ARG TRINO_VERSION above
ENV PRESTO_VERSION=348
ENV PRESTO_HOME=/opt/presto/presto-server
ENV PRESTO_CLI=/opt/presto/presto-cli
ENV _APP_HOME=${PRESTO_HOME}
ENV _APP_CLI=${PRESTO_CLI}
# ======================================
# ======================================

# Note: podman was having difficulties evaluating the TRINO_VERSION
# environment variables: https://github.com/containers/libpod/issues/4878
ENV PROMETHEUS_JMX_EXPORTER=/opt/jmx_exporter/jmx_exporter.jar
ENV TERM=linux
ENV HOME=/opt/${_APP_NAME}
ENV JAVA_HOME=/etc/alternatives/jre_11_openjdk

RUN mkdir -p ${_APP_HOME}

# ======================================
# ======================================
# AS OF RELEASE 351, Presto has been rebranded to Trino.
# The project changed a bit. To use trino, use these copy commands instead
#COPY --from=build /build/core/trino-server/target/trino-server-${TRINO_VERSION} ${TRINO_HOME}
#COPY --from=build /build/client/trino-cli/target/trino-cli-${TRINO_VERSION}-executable.jar ${TRINO_CLI}
#COPY --from=build /build/jmx_prometheus_javaagent.jar ${PROMETHEUS_JMX_EXPORTER}
# ======================================
# ======================================
COPY --from=build /build/presto-server/target/presto-server-${PRESTO_VERSION} ${PRESTO_HOME}
COPY --from=build /build/presto-cli/target/presto-cli-${PRESTO_VERSION}-executable.jar ${PRESTO_CLI}
COPY --from=build /build/jmx_prometheus_javaagent.jar ${PROMETHEUS_JMX_EXPORTER}
# ======================================
# ======================================

# https://docs.oracle.com/javase/7/docs/technotes/guides/net/properties.html
# Java caches dns results forever, don't cache dns results forever:
RUN touch $JAVA_HOME/lib/security/java.security \
    && chown 1003:0 $JAVA_HOME/lib/security/java.security \
    && chmod g+rw $JAVA_HOME/lib/security/java.security
RUN sed -i '/networkaddress.cache.ttl/d' $JAVA_HOME/lib/security/java.security
RUN sed -i '/networkaddress.cache.negative.ttl/d' $JAVA_HOME/lib/security/java.security
RUN echo 'networkaddress.cache.ttl=0' >> $JAVA_HOME/lib/security/java.security
RUN echo 'networkaddress.cache.negative.ttl=0' >> $JAVA_HOME/lib/security/java.security

# Update ulimits per https://trino.io/docs/current/installation/deployment.html
RUN echo 'presto soft nofile 131072' >> /etc/security/limits.conf
RUN echo 'presto hard nofile 131072' >> /etc/security/limits.conf

RUN echo 'presto soft nproc 131072' >> /etc/security/limits.d/90-nproc.conf
RUN echo 'presto hard nproc 131072' >> /etc/security/limits.d/90-nproc.conf

RUN ln ${_APP_CLI} /usr/local/bin/${_APP_NAME}-cli && \
    chmod 755 /usr/local/bin/${_APP_NAME}-cli

# ======================================
# ======================================
# AS OF RELEASE 351, Presto has been rebranded to Trino.
# The project changed a bit. To use trino, use these commands instead
#RUN chown -R 1003:0 ${HOME} $(readlink -f ${JAVA_HOME}/lib/security/cacerts) && \
#    chmod -R 774 $(readlink -f ${JAVA_HOME}/lib/security/cacerts) && \
#    chmod -R 775 ${HOME} && \
#    ln -s ${HOME} /opt/presto && \
#    ln -s ${TRINO_HOME} /opt/trino/presto-server
# ======================================
# ======================================
RUN chown -R 1003:0 ${HOME} /etc/passwd $(readlink -f ${JAVA_HOME}/lib/security/cacerts) && \
    chmod -R 774 /etc/passwd $(readlink -f ${JAVA_HOME}/lib/security/cacerts) && \
    chmod -R 775 ${HOME}
# ======================================
# ======================================

USER 1003
EXPOSE 8080
WORKDIR ${_APP_HOME}

CMD ["tini", "--", "bin/launcher", "run"]

LABEL io.k8s.display-name="OpenShift Presto" \
      io.k8s.description="This is an image used by Cost Management to install and run Presto." \
      summary="This is an image used by Cost Management to install and run Presto." \
      io.openshift.tags="openshift" \
      maintainer="<cost-mgmt@redhat.com>"

