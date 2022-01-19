#!/bin/bash

# Peregrine helper script
usage()
{
  echo "usage: peregrine.sh [[analyze] | [views] | [show] | [clean] | [help]]"
}

# log level
#set -o xtrace

VERSION="0.4-SNAPSHOT"
WORK_DIR="/opt/peregrine/analyze"
IR_NAME=`(grep "IR_filename" ${WORK_DIR}/peregrine-spark.properties | cut -f2 -d'=')`
MAT_DIR=`(grep "ComputeReuse_materializePath" ${WORK_DIR}/peregrine-spark.properties | cut -f2 -d'=')`
STATUS=0

run_command()
{
  $@ 1>>${WORK_DIR}/out.txt 2>>${WORK_DIR}/err.txt
  if [ $? -ne 0 ]; then
    echo -e "Failed to execute: $@"
    exit $?
  fi
}

# clear state
clean()
{
  rm -rf ${WORK_DIR}/applog
  rm ${WORK_DIR}/*.stp
  rm ${WORK_DIR}/*.txt
  rm ${WORK_DIR}/*.csv
  hadoop fs -rmr ${MAT_DIR}/*
  #hadoop fs -rmr /hdp/spark2-events/*
}

# list peregrine outputs
show()
{
  echo -e "\nFeedback file -->\n"
  hadoop fs -cat ${MAT_DIR}/views.stp
  echo -e "\nMaterialized subexpressions -->\n"
  hadoop fs -ls ${MAT_DIR}
}

# copy application log files
copy_logs()
{
  mkdir -p ${WORK_DIR}/applog
  [ $? -eq 0 ] || STATUS=1
  hadoop fs -copyToLocal /hdp/spark2-events/* ${WORK_DIR}/applog
  # rm ${WORK_DIR}/applog/*.inprogress
}

# parse workload
parse()
{
  parse_logical
  parse_physical
  hadoop fs -ls ${MAT_DIR}
}

parse_logical()
{
  command="java \
  -Xmx8g \
  -jar ${WORK_DIR}/peregrine-spark-${VERSION}.jar \
    SparkLogicalWorkloadParserTask \
    ${WORK_DIR}/peregrine-spark.properties
  "
  run_command $command
  mv ${IR_NAME} ${WORK_DIR}/logical_ir.csv
  copy_command="hadoop fs -copyFromLocal -f ${WORK_DIR}/logical_ir.csv ${MAT_DIR}/"
  run_command $copy_command
}

parse_physical()
{
  command="java \
  -Xmx8g \
  -jar ${WORK_DIR}/peregrine-spark-${VERSION}.jar \
    SparkWorkloadParserTask \
    ${WORK_DIR}/peregrine-spark.properties
  "
  run_command $command
  mv ${IR_NAME} ${WORK_DIR}/physical_ir.csv
  copy_command="hadoop fs -copyFromLocal -f ${WORK_DIR}/physical_ir.csv ${MAT_DIR}/"
  run_command $copy_command
}

# select views
views()
{
  command="java \
  -Xmx8g \
  -jar ${WORK_DIR}/peregrine-spark-${VERSION}.jar \
    ViewSelectionTask \
    ${WORK_DIR}/peregrine-spark.properties \
    ${WORK_DIR}/physical_ir.csv
  "
  run_command $command
  VIEW_FROM=`(grep "ComputeReuse_feedbackPath" ${WORK_DIR}/peregrine-spark.properties | cut -f2 -d'=')`
  VIEW_TO=`(grep "FeedbackParams" ${WORK_DIR}/peregrine-spark.properties | cut -f2 -d'=')`
  copy_command="hadoop fs -copyFromLocal -f ${VIEW_FROM} ${VIEW_TO}"
  run_command $copy_command
  VIEW_IR=`(grep "View_Selection_IR" ${WORK_DIR}/peregrine-spark.properties | cut -f2 -d'=')`
  copy_command="hadoop fs -copyFromLocal -f ${VIEW_IR} ${MAT_DIR}/"
  run_command $copy_command
  rm -rf spark-warehouse
  hadoop fs -ls ${MAT_DIR}
}

# create directory for materialized subexpressions
create_dist_dir()
{
  hadoop fs -mkdir -p ${MAT_DIR}
  hadoop fs -chmod -R 775 ${MAT_DIR}
}

# main
[ ! -z "$1" ] || usage
while [ "$1" != "" ]; do
    case $1 in
    analyze)
        copy_logs
        create_dist_dir
        parse
        ;;
    views)
        views
        ;;
    show)
        show
        ;;
    clean)
        clean
        ;;
    help)
        usage
        exit $STATUS
        ;;
    *)
        echo "*"
        usage
        STATUS=1
        exit $STATUS
    esac
    shift
done

exit $STATUS
