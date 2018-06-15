#!/bin/bash

wget https://raw.githubusercontent.com/hortonworks/data-tutorials/master/tutorials/hdp/how-to-process-data-with-apache-hive/assets/driver_data.zip
unzip driver_data.zip

export HADOOP_USER_NAME=hdfs
unzip driver_data.zip -d /tmp
hadoop fs -put /tmp/driver_data/*.csv /tmp

beeline -u jdbc:hive2://$(hostname -f):10000 -n hive -p hive -e "CREATE DATABASE IF NOT EXISTS logistics; CREATE TABLE IF NOT EXISTS temp_drivers (col_value STRING); LOAD DATA INPATH '/tmp/drivers.csv' OVERWRITE INTO TABLE temp_drivers; CREATE TABLE IF NOT EXISTS logistics.drivers (driverId INT, name STRING, ssn BIGINT, location STRING, certified STRING, wageplan STRING); INSERT OVERWRITE TABLE logistics.drivers SELECT regexp_extract(col_value, '^(?:([^,]*),?){1}', 1) driverId, regexp_extract(col_value, '^(?:([^,]*),?){2}', 1) name, regexp_extract(col_value, '^(?:([^,]*),?){3}', 1) ssn, regexp_extract(col_value, '^(?:([^,]*),?){4}', 1) location, regexp_extract(col_value, '^(?:([^,]*),?){5}', 1) certified, regexp_extract(col_value, '^(?:([^,]*),?){6}', 1) wageplan FROM temp_drivers;"
beeline -u jdbc:hive2://$(hostname -f):10000 -n hive -p hive -e "CREATE TABLE temp_timesheet (col_value string); LOAD DATA INPATH '/tmp/timesheet.csv' OVERWRITE INTO TABLE temp_timesheet; CREATE TABLE logistics.timesheet (driverId INT, week INT, hours_logged INT , miles_logged INT); insert overwrite table logistics.timesheet SELECT regexp_extract(col_value, '^(?:([^,]*),?){1}', 1) driverId, regexp_extract(col_value, '^(?:([^,]*),?){2}', 1) week, regexp_extract(col_value, '^(?:([^,]*),?){3}', 1) hours_logged, regexp_extract(col_value, '^(?:([^,]*),?){4}', 1) miles_logged from temp_timesheet;"