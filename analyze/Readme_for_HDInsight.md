## Overview

SparkCruise is an automatic computation reuse system developed for Spark. In this document, we describe how SparkCruise can apply computation reuse across multiple Spark SQL queries in HDInsight environment.

Our analysis from production workloads reveal that users often end up having overlapping queries, i.e., parts of the computation are duplicated. As a result, redundant computation costs are incurred. The goal of workload optimization is to identify such global optimization opportunities and reduce the overall cost of operation.

## Setup 

The SparkCruise library files are installed in the `/opt/peregrine/` directory on HDInsight clusters. To enable computation reuse, we have set the following Spark configurations:

* `spark.sql.queryExecutionListeners=com.microsoft.peregrine.spark.listeners.PlanLogListener` to enable logging of query plans 
* `spark.sql.extensions=com.microsoft.peregrine.spark.extensions.SparkExtensionsHdi` to enable the optimizer rules for online materialization and reuse

## Computation Reuse in Spark SQL

First, execute a sample query workload in `spark-shell` or Spark notebook - 
```
spark.sql("select count(*) from hivesampletable").collect
spark.sql("select count(*) from hivesampletable").collect
spark.sql("select distinct market from hivesampletable where querytime like '11%'").show
spark.sql("select distinct state, country from hivesampletable where querytime like '11%'").show
:quit
```
In notebook, you can close the session by selecting `Kernel->Restart`.
Now login to cluster and run a one-time analysis of existing Spark application logs - 
```
$ sudo /opt/peregrine/analyze/peregrine.sh analyze views
```

The `analyze` command parses the query plans and creates a tabular representation of the workload. This workload table can be queried using the WorkloadInsights notebook included on HDInsight clusters. Then, the `views` command identifies common subplan expressions and selects interesting subplan expressions for future materialization and reuse. The output is a feedback file containing annotations for future Spark SQL queries. The contents of the feedback file can be listed using the following command - 
```
$ /opt/peregrine/analyze/peregrine.sh show
```

The feedback file contains records in the following format - 
```
subplan-identifier [Materialize|Reuse] input/path/to/action
e.g., 18446744072264439276 Materialize /peregrine/views/18446744072264439276
```

For our sample workload, the feedback file will contain two unique signatures representing the first two repeated queries and the filter predicate in last two queries. With this feedback file, the following queries when submitted again will now automatically materialize and reuse common subplans - 
```
spark.sql("select count(*) from hivesampletable").collect
spark.sql("select count(*) from hivesampletable").collect
spark.sql("select distinct state, country from hivesampletable where querytime like '12%'").show
spark.sql("select distinct market from hivesampletable where querytime like '12%'").show
```

An astute reader might have noticed that we have changed the literal values in the second round of workload. Though computation reuse in SparkCruise relies on past workload being a strong indicator of future reuse opportunities, it can still handle the time-varying changes in workload like evolution of literal values and dataset versions. In case of major changes in the workload, no materialization or reuse will be performed as no subplan match will be detected in the query plans. In this case, we can re-run the analysis to find new reuse opportunities.

Behind the scenes, SparkCruise triggers a subquery for materializing the selected subplan from the first query that contains it. Then, the subsequent queries can directly read the materialized subplans instead of recomputing them. In this workload, the subplans will be materialized in an online fashion by the first and third queries. We can see the plan change of queries after the common subplans are materialized - 
```
spark.sql("select count(*) from hivesampletable").explain(true)
spark.sql("select distinct market from hivesampletable where querytime like '12%'").explain(true)
```

The feedback files, materialized subplans, and query logs are persisted across Spark sessions. To remove these files, run - 
```
$ sudo /opt/peregrine/analyze/peregrine.sh clean
```

## Resources
1. SparkCruise at Spark+AI Summit 2020. [Link](https://databricks.com/session_na20/sparkcruise-automatic-computation-reuse-in-apache-spark).
2. SparkCruise: Handsfree Computation Reuse in Spark at VLDB 2019. [Link](http://www.vldb.org/pvldb/vol12/p1850-roy.pdf).
