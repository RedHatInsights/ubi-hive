#!/bin/sh

export JMX_OPTIONS="-javaagent:${METASTORE_HOME}/lib/jmx_exporter.jar=9000:${METASTORE_HOME}/conf/jmx-config.yaml"
export HADOOP_CLASSPATH=${HADOOP_HOME}/share/hadoop/tools/lib/aws-java-sdk-bundle-1.11.375.jar:${HADOOP_HOME}/share/hadoop/tools/lib/hadoop-aws-${HADOOP_VERSION}.jar
export HADOOP_OPTS="${HADOOP_OPTS} ${VM_OPTIONS} ${GC_SETTINGS} ${JMX_OPTIONS}"
export HIVE_OPTS="${HIVE_OPTS} --hiveconf metastore.root.logger=${HIVE_LOGLEVEL},console "
export PATH=${METASTORE_HOME}/bin:${HADOOP_HOME}/bin:$PATH

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
