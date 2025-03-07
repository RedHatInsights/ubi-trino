ARG JDK_VERSION=jdk-23.0.2+7  # https://api.adoptium.net/v3/info/release_names?image_type=jdk&page=0&page_size=100&project=jdk&release_type=ga&semver=false&sort_method=DEFAULT&sort_order=DESC&vendor=eclipse
ARG PROMETHEUS_VERSION=1.0.1
ARG TRINO_VERSION=471
ARG WORK_DIR="/tmp"

FROM registry.access.redhat.com/ubi9/ubi-minimal:latest as downloader

ARG TARGETARCH
ARG PROMETHEUS_VERSION
ARG TRINO_VERSION
ARG SERVER_LOCATION="https://repo1.maven.org/maven2/io/trino/trino-server/${TRINO_VERSION}/trino-server-${TRINO_VERSION}.tar.gz"
ARG CLIENT_LOCATION="https://repo1.maven.org/maven2/io/trino/trino-cli/${TRINO_VERSION}/trino-cli-${TRINO_VERSION}-executable.jar"
ARG PROMETHEUS_JMX_EXPORTER_LOCATION="https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${PROMETHEUS_VERSION}/jmx_prometheus_javaagent-${PROMETHEUS_VERSION}.jar"
ARG WORK_DIR
ARG JDK_VERSION

ENV JAVA_HOME=/usr/lib/jvm/${JDK_VERSION}

RUN microdnf -y install tar gzip \
    && microdnf clean all

RUN mkdir -p "${JAVA_HOME}" \
    && case $TARGETARCH in arm64) PACKAGE_ARCH=aarch64;; amd64) PACKAGE_ARCH=x64; esac \
    && JDK_DOWNLOAD_LINK="https://api.adoptium.net/v3/binary/version/${JDK_VERSION}/linux/${PACKAGE_ARCH}/jdk/hotspot/normal/eclipse?project=jdk" \
    && curl --progress-bar --location --fail --show-error "${JDK_DOWNLOAD_LINK}" | tar -xz --strip 1 -C "${JAVA_HOME}"

RUN curl --progress-bar --location --fail --show-error ${SERVER_LOCATION} | tar -zxf - -C ${WORK_DIR} \
    && curl --progress-bar --location --fail --show-error --output ${WORK_DIR}/trino-cli-${TRINO_VERSION}-executable.jar ${CLIENT_LOCATION} \
    && chmod +x ${WORK_DIR}/trino-cli-${TRINO_VERSION}-executable.jar \
    && curl --progress-bar --location --fail --show-error --output ${WORK_DIR}/jmx_prometheus_javaagent-${PROMETHEUS_VERSION}.jar ${PROMETHEUS_JMX_EXPORTER_LOCATION} \
    && chmod +x ${WORK_DIR}/jmx_prometheus_javaagent-${PROMETHEUS_VERSION}.jar

###########################
# Remove all unused plugins
# Only hive, jmx, memory, postgresql, and geospatial are configured plugins (geospatial is required for postgresql).
ARG to_delete="/TO_DELETE"
RUN mkdir ${to_delete} \
    && mv ${WORK_DIR}/trino-server-${TRINO_VERSION}/plugin/* ${to_delete} \
    && mv ${to_delete}/{hive,jmx,memory,postgresql,geospatial} ${WORK_DIR}/trino-server-${TRINO_VERSION}/plugin/. \
    && rm -rf ${to_delete}
###########################


# Final container image:
FROM registry.access.redhat.com/ubi9/ubi-minimal:latest as final

ARG JDK_VERSION
ARG PROMETHEUS_VERSION
ARG TRINO_VERSION
ARG VERSION
ARG WORK_DIR

ENV JAVA_HOME=/usr/lib/jvm/${JDK_VERSION}
ENV TRINO_HOME=/etc/trino
ENV TRINO_HISTORY_FILE=/data/trino/.trino_history
ENV PATH=${PATH}:${JAVA_HOME}/bin

LABEL io.k8s.display-name="OpenShift Trino"
LABEL io.k8s.description="This is an image used by Cost Management to install and run Trino."
LABEL summary="This is an image used by Cost Management to install and run Trino."
LABEL io.openshift.tags="openshift"
LABEL maintainer="<cost-mgmt@redhat.com>"
LABEL version=${VERSION}

COPY --from=downloader "${JAVA_HOME}" "${JAVA_HOME}"

RUN set -eux \
    && microdnf -y upgrade \
    && microdnf install -y --nodocs --setopt install_weak_deps=0 \
        jq \
        less \
        shadow-utils \
    && microdnf clean all

# Add user and directories
RUN groupadd trino --gid 1000 \
    && useradd trino --uid 1000 --gid 1000 \
    && mkdir -p /usr/lib/trino /data/trino/{data,logs,spill} \
    && chown -R "trino:trino" /usr/lib/trino /data/trino


# https://docs.oracle.com/javase/7/docs/technotes/guides/net/properties.html
# Java caches DNS results forever. Don't cache DNS results forever.
RUN touch $JAVA_HOME/lib/security/java.security \
    && chown 1000:0 $JAVA_HOME/lib/security/java.security \
    && chmod g+rw $JAVA_HOME/lib/security/java.security \
    && sed -i '/networkaddress.cache.ttl/d' $JAVA_HOME/lib/security/java.security \
    && sed -i '/networkaddress.cache.negative.ttl/d' $JAVA_HOME/lib/security/java.security \
    && echo 'networkaddress.cache.ttl=0' >> $JAVA_HOME/lib/security/java.security \
    && echo 'networkaddress.cache.negative.ttl=0' >> $JAVA_HOME/lib/security/java.security

RUN chown -R 1000:0 ${HOME} /etc/passwd $(readlink -f ${JAVA_HOME}/lib/security/cacerts) \
    && chmod -R 774 /etc/passwd $(readlink -f ${JAVA_HOME}/lib/security/cacerts) \
    && chmod -R 775 ${HOME}

COPY --from=downloader ${WORK_DIR}/jmx_prometheus_javaagent-${PROMETHEUS_VERSION}.jar /usr/lib/trino/jmx_exporter.jar
COPY --from=downloader ${WORK_DIR}/trino-cli-${TRINO_VERSION}-executable.jar /usr/bin/trino
COPY --from=downloader --chown=trino:trino ${WORK_DIR}/trino-server-${TRINO_VERSION} /usr/lib/trino
COPY --chown=trino:trino bin/ /usr/lib/trino/
COPY --chown=trino:trino default/etc $TRINO_HOME
COPY LICENSE /licenses/AGPL-1.0-or-later.txt

EXPOSE 10000
USER trino:trino
ENV LANG en_US.UTF-8
CMD ["/usr/lib/trino/run-trino"]
