FROM quay.io/cloudservices/ubi-hadoop:3.3.0

USER root

# Container app versions
ARG HIVE_VERSION=3.1.2
ARG MYSQL_CONNECTOR_VER=8.0.22-1
ARG POSTGRESQL_JDBC_VER=42.2.18

# Container environment
ENV PREFIX=/opt
ENV HIVE_HOME=${PREFIX}/hive-${HIVE_VERSION}
ENV HADOOP_CLASSPATH $HIVE_HOME/hcatalog/share/hcatalog/*:${HADOOP_CLASSPATH}
ENV PATH=${HIVE_HOME}/bin:${PATH}
ENV TERM=linux
ENV JAVA_HOME=/etc/alternatives/jre_11_openjdk

# Get connectors
RUN set -x; \
    MYSQL_JAVA_URL="https://dev.mysql.com/get/Downloads/Connector-J/mysql-connector-java-${MYSQL_CONNECTOR_VER}.el8.noarch.rpm" \
    PG_JAVA_URL="https://jdbc.postgresql.org/download/postgresql-${POSTGRESQL_JDBC_VER}.jar" \
    && yum clean all \
    && rm -rf /var/cache/yum/* \
    && yum install -y ${MYSQL_JAVA_URL} \
    && yum clean all \
    && rm -rf /var/cache/yum \
    && curl -sLo /usr/share/java/postgresql-java.jar ${PG_JAVA_URL}

# Download and install Hive
RUN curl -sLo ${PREFIX}/hive-${HIVE_VERSION}.tar.gz \
         "https://downloads.apache.org/hive/hive-${HIVE_VERSION}/apache-hive-${HIVE_VERSION}-bin.tar.gz" \
    && tar -C ${PREFIX} -zxf  ${PREFIX}/hive-${HIVE_VERSION}.tar.gz \
    && mv ${PREFIX}/apache-hive-${HIVE_VERSION}-bin ${HIVE_HOME} \
    && rm -f ${PREFIX}/hive-${HIVE_VERSION}.tar.gz \
    && ln -s ${HIVE_HOME} ${PREFIX}/hive \
    && ln -s ${HADOOP_HOME}/share/hadoop/tools/lib/*aws* ${HIVE_HOME}/lib \
    && mkdir -p /var/lib/hive \
    && mkdir -p /user/hive/warehouse \
    && mkdir -p /.beeline \
    && mkdir -p $HOME/.beeline \
    && chown -R 1002:0 ${PREFIX} /var/lib/hive /user/hive/warehouse /.beeline $HOME/.beeline \
    && chmod -R 774 ${PREFIX} /var/lib/hive /user/hive/warehouse /.beeline $HOME/.beeline /etc/passwd \
    && chmod -R g+rwx $(readlink -f ${JAVA_HOME}) $(readlink -f ${JAVA_HOME}/lib/security)

# Link connectors
RUN ln -s /usr/share/java/mysql-connector-java.jar ${HIVE_HOME}/lib/mysql-connector-java.jar \
    && ln -s /usr/share/java/postgresql-jdbc.jar ${HIVE_HOME}/lib/postgresql-jdbc.jar

# update hive guava lib
RUN for _JARFILE in $(ls ${HIVE_HOME}/lib/guava*.jar); do     mv ${_JARFILE} ${_JARFILE}xNOPE; done \
    && ln -s ${HADOOP_HOME}/share/hadoop/common/lib/guava*.jar ${HIVE_HOME}/lib

# Java security config
RUN touch $JAVA_HOME/lib/security/java.security && \
    sed -i -e '/networkaddress.cache.ttl/d' \
        -e '/networkaddress.cache.negative.ttl/d' \
        $JAVA_HOME/lib/security/java.security && \
    printf 'networkaddress.cache.ttl=0\nnetworkaddress.cache.negative.ttl=0\n' >> $JAVA_HOME/lib/security/java.security

USER 1002
VOLUME /user/hive/warehouse /var/lib/hive

LABEL io.k8s.display-name="OpenShift Hive" \
      io.k8s.description="This is an image used by Cost Management to install and run Hive." \
      summary="This is an image used by Cost Management to install and run Hive." \
      io.openshift.tags="openshift" \
      maintainer="<cost-mgmt@redhat.com>"
