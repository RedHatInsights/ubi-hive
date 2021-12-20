
FROM registry.access.redhat.com/ubi8/ubi:latest

LABEL io.k8s.display-name="OpenShift Hive Metastore" \
    io.k8s.description="This is an image used by Cost Management to install and run Hive Metastore." \
    summary="This is an image used by Cost Management to install and run Hive Metastore." \
    io.openshift.tags="openshift" \
    maintainer="<cost-mgmt@redhat.com>"

RUN yum -y update && yum clean all

RUN \
    # symlink the python3.6 installed in the container
    ln -s /usr/libexec/platform-python /usr/bin/python && \
    # add PostgreSQL RPM repository to gain access to the postgres jdbc
    yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm && \
    set -xeu && \
    # Java 1.8 required for Hive/Hadoop
    # postgresql-jdbc needed so Hive can connect to postgres
    # jq is needed for the clowdapp entrypoint script to work properly
    INSTALL_PKGS="java-1.8.0-openjdk postgresql-jdbc openssl jq" && \
    yum install -y $INSTALL_PKGS && \
    yum clean all && \
    rm -rf /var/cache/yum

WORKDIR /opt

ENV HADOOP_VERSION=3.3.1
ENV METASTORE_VERSION=3.1.2
ENV PROMETHEUS_VERSION=0.16.1

ENV HADOOP_HOME=/opt/hadoop
ENV JAVA_HOME=/usr/lib/jvm/jre-1.8.0-openjdk
ENV METASTORE_HOME=/opt/hive-metastore-bin

# Fetch the compiled Hadoop and Standalone Metastore
RUN mkdir -p ${HADOOP_HOME} ${METASTORE_HOME}
RUN \
    curl -L http://apache.mirrors.hoobly.com/hadoop/common/hadoop-${HADOOP_VERSION}/hadoop-${HADOOP_VERSION}.tar.gz | tar -zxf - -C ${HADOOP_HOME} --strip 1 && \
    curl -L https://repo1.maven.org/maven2/org/apache/hive/hive-standalone-metastore/${METASTORE_VERSION}/hive-standalone-metastore-${METASTORE_VERSION}-bin.tar.gz | tar -zxf - -C ${METASTORE_HOME} --strip 1

RUN \
    # Configure Hadoop AWS Jars to be available to hive
    ln -s ${HADOOP_HOME}/share/hadoop/tools/lib/*aws* ${METASTORE_HOME}/lib && \
    # Configure Postgesql connector jar to be available to hive
    ln -s /usr/share/java/postgresql-jdbc.jar ${METASTORE_HOME}/lib/postgresql-jdbc.jar

####### CVE-2021-44228, CVE-2021-45046, CVE-2021-45105 #######
ARG LOG4J_VERSION=2.17.0
ARG LOG4J_LOCATION="https://repo1.maven.org/maven2/org/apache/logging/log4j/"
RUN \
    rm -f ${HADOOP_HOME}/share/hadoop/common/lib/slf4j-log4j12* && \
    rm -f ${METASTORE_HOME}/lib/log4j-* && \
    curl -o ${METASTORE_HOME}/lib/log4j-1.2-api-${LOG4J_VERSION}.jar https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-1.2-api/${LOG4J_VERSION}/log4j-1.2-api-${LOG4J_VERSION}.jar  && \
    curl -o ${METASTORE_HOME}/lib/log4j-api-${LOG4J_VERSION}.jar https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-api/${LOG4J_VERSION}/log4j-api-${LOG4J_VERSION}.jar && \
    curl -o ${METASTORE_HOME}/lib/log4j-core-${LOG4J_VERSION}.jar https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-core/${LOG4J_VERSION}/log4j-core-${LOG4J_VERSION}.jar && \
    curl -o ${METASTORE_HOME}/lib/log4j-slf4j-impl-${LOG4J_VERSION}.jar https://repo1.maven.org/maven2/org/apache/logging/log4j/log4j-slf4j-impl/${LOG4J_VERSION}/log4j-slf4j-impl-${LOG4J_VERSION}.jar && \
    # Fetch the jmx exporter. Needed for metrics server and liveness/readiness probes:
    curl -o ${METASTORE_HOME}/lib/jmx_exporter.jar https://repo1.maven.org/maven2/io/prometheus/jmx/jmx_prometheus_javaagent/${PROMETHEUS_VERSION}/jmx_prometheus_javaagent-${PROMETHEUS_VERSION}.jar
##############################

# Move the default configuration files into the container
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
EXPOSE 8000

ENTRYPOINT ["sh", "-c", "/entrypoint.sh"]
