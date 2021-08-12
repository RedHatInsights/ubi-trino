ARG PROMETHEUS_VERSION=0.16.1
ARG TRINO_VERSION=360

FROM registry.access.redhat.com/ubi8/ubi:latest as downloader

ARG PROMETHEUS_VERSION
ARG TRINO_VERSION
ARG SERVER_LOCATION="https://repo1.maven.org/maven2/io/trino/trino-server/${TRINO_VERSION}/trino-server-${TRINO_VERSION}.tar.gz"
ARG CLIENT_LOCATION="https://repo1.maven.org/maven2/io/trino/trino-cli/${TRINO_VERSION}/trino-cli-${TRINO_VERSION}-executable.jar"
ARG PROMETHEUS_JMX_EXPORTER_LOCATION="https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${PROMETHEUS_VERSION}/jmx_prometheus_javaagent-${PROMETHEUS_VERSION}.jar"
ARG WORK_DIR="/tmp"

RUN \
curl -o ${WORK_DIR}/trino-server-${TRINO_VERSION}.tar.gz ${SERVER_LOCATION} && \
tar -C ${WORK_DIR} -xzf ${WORK_DIR}/trino-server-${TRINO_VERSION}.tar.gz && \
rm ${WORK_DIR}/trino-server-${TRINO_VERSION}.tar.gz
RUN \
curl -o ${WORK_DIR}/trino-cli-${TRINO_VERSION}-executable.jar ${CLIENT_LOCATION} && \
chmod +x ${WORK_DIR}/trino-cli-${TRINO_VERSION}-executable.jar
RUN \
curl -o ${WORK_DIR}/jmx_prometheus_javaagent-${PROMETHEUS_VERSION}.jar ${PROMETHEUS_JMX_EXPORTER_LOCATION} && \
chmod +x ${WORK_DIR}/jmx_prometheus_javaagent-${PROMETHEUS_VERSION}.jar

COPY bin ${WORK_DIR}/trino-server-${TRINO_VERSION}
COPY default ${WORK_DIR}/

FROM registry.access.redhat.com/ubi8/ubi:latest

LABEL io.k8s.display-name="OpenShift Trino" \
      io.k8s.description="This is an image used by Cost Management to install and run Trino." \
      summary="This is an image used by Cost Management to install and run Trino." \
      io.openshift.tags="openshift" \
      maintainer="<cost-mgmt@redhat.com>"

RUN yum -y update && yum clean all

RUN \
    # install python3.6
    dnf -y --disableplugin=subscription-manager module enable python36 && \
    dnf -y --disableplugin=subscription-manager --setopt=tsflags=nodocs install python36 && \
    dnf --disableplugin=subscription-manager clean all && \
    ln -s $(which python3) /usr/bin/python && \
    # add the Azul RPM repository
    yum install -y https://cdn.azul.com/zulu/bin/zulu-repo-1.0.0-1.noarch.rpm && \
    set -xeu && \
    INSTALL_PKGS="zulu11-jdk less jq" && \
    yum install -y $INSTALL_PKGS && \
    yum clean all && \
    rm -rf /var/cache/yum

# add user and directories
RUN \
    groupadd trino --gid 1000 && \
    useradd trino --uid 1000 --gid 1000 && \
    mkdir -p /usr/lib/trino /data/trino/logs && \
    chown -R "trino:trino" /usr/lib/trino /data/trino

ENV JAVA_HOME=/usr/lib/jvm/zulu11 \
    TRINO_HOME=/etc/trino

ARG PROMETHEUS_VERSION
ARG TRINO_VERSION
COPY --from=downloader /tmp/jmx_prometheus_javaagent-${PROMETHEUS_VERSION}.jar /usr/lib/trino/jmx_exporter.jar
COPY --from=downloader /tmp/trino-cli-${TRINO_VERSION}-executable.jar /usr/bin/trino
COPY --from=downloader --chown=trino:trino /tmp/trino-server-${TRINO_VERSION} /usr/lib/trino
COPY --chown=trino:trino default/etc $TRINO_HOME

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
RUN echo 'trino soft nofile 131072' >> /etc/security/limits.conf
RUN echo 'trino hard nofile 131072' >> /etc/security/limits.conf

RUN echo 'trino soft nproc 131072' >> /etc/security/limits.d/90-nproc.conf
RUN echo 'trino hard nproc 131072' >> /etc/security/limits.d/90-nproc.conf

EXPOSE 8080
USER trino:trino
ENV LANG en_US.UTF-8
CMD ["/usr/lib/trino/run-trino"]
