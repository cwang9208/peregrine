#!/usr/bin/env bash

export SPARK_CONF_DIR=${SPARK_CONF_DIR:-/usr/hdp/current/spark2-thriftserver/conf}
export SPARK_LOG_DIR=/var/log/spark2
export SPARK_PID_DIR=/var/run/spark2
export SPARK_MAJOR_VERSION=2
SPARK_IDENT_STRING=$USER
SPARK_NICENESS=0
export HADOOP_HOME=${HADOOP_HOME:-/usr/hdp/4.1.8.19/hadoop}
export HADOOP_CONF_DIR=${HADOOP_CONF_DIR:-/usr/hdp/4.1.8.19/hadoop/conf}
export SPARK_DIST_CLASSPATH=$SPARK_DIST_CLASSPATH:/usr/hdp/current/spark2-client/jars/*:/usr/lib/hdinsight-datalake/*:/usr/hdp/current/spark_llap/*:/usr/hdp/current/spark2-client/conf:
export JAVA_HOME=/usr/lib/jvm/zulu-8-azure-amd64
if [ -d "/etc/tez/conf/" ]; then
  export TEZ_CONF_DIR=/etc/tez/conf
else
  export TEZ_CONF_DIR=
fi

# Tell pyspark (the shell) to use Anaconda Python.
export PYSPARK_PYTHON=${PYSPARK_PYTHON:-/usr/bin/anaconda/bin/python}

# Give values for log4j variables for Spark History Server
export SPARK_HISTORY_OPTS="$SPARK_HISTORY_OPTS -Detwlogger.component=sparkhistoryserver -DlogFilter.filename=SparkLogFilters.xml -DpatternGroup.filename=SparkPatternGroups.xml -Dlog4jspark.root.logger=INFO,RFA,Anonymizer -Dlog4jspark.log.dir=/var/log/spark -Dlog4jspark.log.file=sparkhistoryserver.log -Dlog4j.configuration=file:/usr/hdp/current/spark2-client/conf/log4j.properties"