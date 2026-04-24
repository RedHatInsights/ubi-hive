
FROM registry.access.redhat.com/ubi9/ubi:latest

LABEL io.k8s.display-name="UrbanOS Hive Metastore" \
    io.k8s.description="This is an image used by UrbanOS to install and run Hive Metastore." \
    summary="This is an image used by UrbanOS to install and run Hive Metastore." \
    io.openshift.tags="openshift"

RUN \
    yum updateinfo list --security --nogpgcheck && \
    yum -y update && yum clean all && \
    # symlink the python3.6 installed in the container
    ln -s /usr/libexec/platform-python /usr/bin/python && \
    # add PostgreSQL RPM repository to gain access to the postgres jdbc
    yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-9-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
    set -xeu && \
    # Java 1.8 required for Hive/Hadoop
    # postgresql-jdbc needed so Hive can connect to postgres
    # jq is needed for the clowdapp entrypoint script to work properly
    INSTALL_PKGS="java-1.8.0-openjdk postgresql-jdbc openssl jq unzip" && \
    yum install -y $INSTALL_PKGS --setopt=install_weak_deps=False --setopt=tsflags=nodocs --nogpgcheck && \
    yum clean all && \
    rm -rf /var/cache/yum

WORKDIR /opt

ENV HADOOP_VERSION=3.3.6
ENV METASTORE_VERSION=3.1.3
ENV PROMETHEUS_VERSION=0.20.0

ENV HADOOP_HOME=/opt/hadoop
ENV JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk
ENV METASTORE_HOME=/opt/hive-metastore-bin

# Fetch the compiled Hadoop and Standalone Metastore
RUN mkdir -p ${HADOOP_HOME} ${METASTORE_HOME}
RUN \
    --mount=type=secret,id=ACCESS_TOKEN \
    ACCESS_TOKEN=$(cat /run/secrets/ACCESS_TOKEN) && \
    HADOOP_ARTIFACT_PATH=$(curl -fL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/UrbanOS-Public/urbanos-hadoop/actions/artifacts \
        | jq -r '[.artifacts[] | select(.expired == false)] | .[0].archive_download_url' \
    ) && \
    HIVE_ARTIFACT_PATH=$(curl -fL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        https://api.github.com/repos/UrbanOS-Public/urbanos-hive/actions/artifacts \
        | jq -r '[.artifacts[] | select(.expired == false)] | .[0].archive_download_url' \
    ) && \
    echo "Hadoop artifact: $HADOOP_ARTIFACT_PATH" && \
    echo "Hive artifact: $HIVE_ARTIFACT_PATH" && \
    [ -n "$HADOOP_ARTIFACT_PATH" ] && [ "$HADOOP_ARTIFACT_PATH" != "null" ] || (echo "ERROR: failed to resolve Hadoop artifact URL" && exit 1) && \
    [ -n "$HIVE_ARTIFACT_PATH" ] && [ "$HIVE_ARTIFACT_PATH" != "null" ] || (echo "ERROR: failed to resolve Hive artifact URL" && exit 1) && \
    curl -fL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${HADOOP_ARTIFACT_PATH}" -o hadoop_artifact.zip && \
    unzip hadoop_artifact.zip -d ${HADOOP_HOME} && \
    tar -xvf ${HADOOP_HOME}/hadoop-3.3.tar -C ${HADOOP_HOME} --strip-components=1 && \
    rm hadoop_artifact.zip && \
    rm ${HADOOP_HOME}/hadoop-3.3.tar && \
    curl -fL \
        -H "Accept: application/vnd.github+json" \
        -H "Authorization: Bearer $ACCESS_TOKEN" \
        -H "X-GitHub-Api-Version: 2022-11-28" \
        "${HIVE_ARTIFACT_PATH}" -o hive_artifact.zip && \
    unzip hive_artifact.zip -d ${METASTORE_HOME} && \
    tar -xvf ${METASTORE_HOME}/hive-3.1.tar -C ${METASTORE_HOME} --strip-components=2 && \
    rm hive_artifact.zip && \
    rm ${METASTORE_HOME}/hive-3.1.tar

RUN \
    # Configure Hadoop AWS Jars to be available to hive
    ln -s ${HADOOP_HOME}/share/hadoop/tools/lib/*aws* ${METASTORE_HOME}/lib && \
    # Configure Postgesql connector jar to be available to hive
    ln -s /usr/share/java/postgresql-jdbc.jar ${METASTORE_HOME}/lib/postgresql-jdbc.jar

RUN \
    # Remove htrace jar
    rm -rf ${HADOOP_HOME}/share/hadoop/yarn/timelineservice

RUN \
    # Remove netty3 jar
    rm ${HADOOP_HOME}/share/hadoop/hdfs/lib/netty-3.10.6.Final.jar

RUN \
    # Remove yarn-applications-catalog-webapp that contains netty3
    rm ${HADOOP_HOME}/share/hadoop/yarn/hadoop-yarn-applications-catalog-webapp-3.3.9-SNAPSHOT.war

RUN \
    # Fetch the jmx exporter. Needed for metrics server and liveness/readiness probes:
    curl -o ${METASTORE_HOME}/lib/jmx_exporter.jar https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${PROMETHEUS_VERSION}/jmx_prometheus_javaagent-${PROMETHEUS_VERSION}.jar
##############################################################################

# Move the default configuration files into the container
COPY default/conf/jmx-config.yaml ${METASTORE_HOME}/conf
COPY default/conf/metastore-site.xml ${METASTORE_HOME}/conf
COPY default/conf/metastore-log4j2.properties ${METASTORE_HOME}/conf
COPY default/scripts/entrypoint.sh /entrypoint.sh

RUN groupadd -r metastore --gid=1000 && \
    useradd -r -g metastore --uid=1000 -d ${METASTORE_HOME} metastore && \
    chown metastore:metastore -R ${METASTORE_HOME} && \
    chown metastore:metastore /entrypoint.sh && chmod +x /entrypoint.sh

# https://docs.oracle.com/javase/7/docs/technotes/guides/net/properties.html
# Java caches dns results forever, don't cache dns results forever:
RUN touch $JAVA_HOME/lib/security/java.security && \
    chown 1000:0 $JAVA_HOME/lib/security/java.security && \
    chmod g+rw $JAVA_HOME/lib/security/java.security && \
    sed -i '/networkaddress.cache.ttl/d' $JAVA_HOME/lib/security/java.security && \
    sed -i '/networkaddress.cache.negative.ttl/d' $JAVA_HOME/lib/security/java.security && \
    echo 'networkaddress.cache.ttl=0' >> $JAVA_HOME/lib/security/java.security && \
    echo 'networkaddress.cache.negative.ttl=0' >> $JAVA_HOME/lib/security/java.security

RUN chown -R 1000:0 ${HOME} /etc/passwd $(readlink -f ${JAVA_HOME}/lib/security/cacerts) && \
    chmod -R 774 /etc/passwd $(readlink -f ${JAVA_HOME}/lib/security/cacerts) && \
    chmod -R 775 ${HOME}

USER metastore
EXPOSE 1000

ENTRYPOINT ["sh", "-c", "/entrypoint.sh"]

