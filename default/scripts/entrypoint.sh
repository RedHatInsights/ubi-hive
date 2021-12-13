#!/bin/sh

export HADOOP_HOME=/opt/hadoop-${HADOOP_VERSION}
export HADOOP_CLASSPATH=${HADOOP_HOME}/share/hadoop/tools/lib/aws-java-sdk-bundle-1.11.375.jar:${HADOOP_HOME}/share/hadoop/tools/lib/hadoop-aws-${HADOOP_VERSION}.jar
export METASTORE_OPTS="${METASTORE_OPTS} --hiveconf metastore.root.logger=INFO,console "
export PATH=/opt/apache-hive-metastore-${METASTORE_VERSION}-bin/bin:$PATH

set +e
if schematool -dbType postgres -info -verbose; then
    echo "Hive metastore schema verified."
else
    if schematool -dbType postgres -initSchema -verbose; then
        echo "Hive metastore schema created."
    else
        echo "Error creating hive metastore: $?"
    fi
fi
set -e

start-metastore
