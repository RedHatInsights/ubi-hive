FROM quay.io/centos/centos:centos7 as build

ARG HIVE_VERSION=2.3.3
ENV HIVE_RELEASE_TAG=rel/release-${HIVE_VERSION}
ENV HIVE_RELEASE_TAG_RE=".*refs/tags/${HIVE_RELEASE_TAG}\$"

RUN yum -y update && yum clean all

RUN yum -y install --setopt=skip_missing_names_on_install=False centos-release-scl

RUN yum -y install \
        java-1.8.0-openjdk \
        java-1.8.0-openjdk-devel \
        rh-maven33 \
        git \
    && yum clean all \
    && rm -rf /var/cache/yum

# Originally, this was a *lot* of COPY layers
RUN git clone -q \
        -b $(git ls-remote --tags https://github.com/apache/hive | grep -E "${HIVE_RELEASE_TAG_RE}" | sed -E 's/.*refs.tags.(rel.*)/\1/g') \
        --single-branch \
        https://github.com/apache/hive.git \
        /build

WORKDIR /build

RUN scl enable rh-maven33 'cd /build && mvn -B -e -T 1C -DskipTests=true -DfailIfNoTests=false -Dtest=false clean package -Pdist'

FROM quay.io/cloudservices/ubi-hadoop:3.1.1-001

# Keep this in sync with ARG HIVE_VERSION above
ENV HIVE_VERSION=2.3.3
ENV HIVE_HOME=/opt/hive
ENV PATH=$HIVE_HOME/bin:$PATH

RUN mkdir -p /opt
WORKDIR /opt

USER root

# PostgreSQL Repo
RUN yum install -y https://download.postgresql.org/pub/repos/yum/reporpms/EL-8-x86_64/pgdg-redhat-repo-latest.noarch.rpm

RUN yum -y update && \
    yum install --setopt=skip_missing_names_on_install=False -y \
        postgresql-jdbc \
        openssl \
    && yum clean all \
    && rm -rf /var/cache/yum

COPY --from=build /build/packaging/target/apache-hive-$HIVE_VERSION-bin/apache-hive-$HIVE_VERSION-bin $HIVE_HOME
WORKDIR $HIVE_HOME

ENV HADOOP_CLASSPATH $HIVE_HOME/hcatalog/share/hcatalog/*:${HADOOP_CLASSPATH}
ENV JAVA_HOME=/etc/alternatives/jre

# Configure Hadoop AWS Jars to be available to hive
RUN ln -s ${HADOOP_HOME}/share/hadoop/tools/lib/*aws* $HIVE_HOME/lib
# Configure Postgesql connector jar to be available to hive
RUN ln -s /usr/share/java/postgresql-jdbc.jar "$HIVE_HOME/lib/postgresql-jdbc.jar"

# https://docs.oracle.com/javase/7/docs/technotes/guides/net/properties.html
# Java caches dns results forever, don't cache dns results forever:
RUN sed -i '/networkaddress.cache.ttl/d' $JAVA_HOME/lib/security/java.security
RUN sed -i '/networkaddress.cache.negative.ttl/d' $JAVA_HOME/lib/security/java.security
RUN echo 'networkaddress.cache.ttl=0' >> $JAVA_HOME/lib/security/java.security
RUN echo 'networkaddress.cache.negative.ttl=0' >> $JAVA_HOME/lib/security/java.security

# imagebuilder expects the directory to be created before VOLUME
RUN mkdir -p /var/lib/hive /.beeline $HOME/.beeline
# to allow running as non-root
RUN chown -R 1002:0 $HIVE_HOME $HADOOP_HOME /var/lib/hive /.beeline $HOME/.beeline /etc/passwd $JAVA_HOME/lib/security/cacerts && \
    chmod -R 774 $HIVE_HOME $HADOOP_HOME /var/lib/hive /.beeline $HOME/.beeline /etc/passwd $JAVA_HOME/lib/security/cacerts

VOLUME /var/lib/hive

USER 1002

LABEL io.k8s.display-name="OpenShift Hive" \
      io.k8s.description="This is an image used by Cost Management to install and run Hive." \
      summary="This is an image used by Cost Management to install and run Hive." \
      io.openshift.tags="openshift" \
      maintainer="<cost-mgmt@redhat.com>"

