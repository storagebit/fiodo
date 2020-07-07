#!/usr/bin/env bash
#Copyright (c) 2020 Storagebit.CH
#
#Permission is hereby granted, free of charge, to any person obtaining a copy
#of this software and associated documentation files (the "Software"), to deal
#in the Software without restriction, including without limitation the rights
#to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
#copies of the Software, and to permit persons to whom the Software is
#furnished to do so, subject to the following conditions:
#
#The above copyright notice and this permission notice shall be included in all
#copies or substantial portions of the Software.
#
#THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
#IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
#FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
#AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
#LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
#OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
#SOFTWARE.

set -e

if [ "$EUID" -ne 0 ]
  then
    echo -e "[$(date "+%H:%M:%S:%3N")] This script needs to be run as root or using sudo."
    echo -e "[$(date "+%H:%M:%S:%3N")] Goodbye."
  exit
fi

echo -e "[$(date "+%H:%M:%S:%3N")] Started benchmark run with PID $BASHPID."

BENCHMARK_TIME=$(date "+%Y.%m.%d-%H.%M.%S")

#Define the Fio working directory
FIO_PATH=/data/iotest/$HOSTNAME

#Define IO engine - run "fio --enghelp" to list available ioengines on the client
#the default is set to "libaio"
FIO_IOENGINE=libaio

#Define the results output files - default location is the fio working directory
#Output base path
OUT_BASE=$FIO_PATH/$HOSTNAME

#Output log files locations - DO NOT CHANGE!
OUT_LAYOUT=$OUT_BASE.bw_read_results-$BENCHMARK_TIME.txt
OUT_BW_READ=$OUT_BASE.bw_read_results-$BENCHMARK_TIME.txt
OUT_BW_WRITE=$OUT_BASE.bw_write_results-$BENCHMARK_TIME.txt
OUT_IOPS=$OUT_BASE.iops_results-$BENCHMARK_TIME.txt

#Define Fio transfer/IO block file sizes
#Baseline default is 16m for throughput and 4k for IOPS testing
BW_IO_SIZE=16M
IOPS_IO_SIZE=4K

#Define Fio test files size
#Baseline default is 10g for throughput and 4g for IOPS testing
BW_FILE_SIZE=10g
IOPS_FILE_SIZE=4g

#Define Fio number of paralell jobs/tasks
#Baseline default is 16 for throughput and 128 for IOPS testing
BW_JOB_COUNT=16
IOPS_JOB_COUNT=128

#Define Fio queue depth
#Baseline default is 16 for throughput and 256 for IOPS testing
BW_IO_DEPTH=16
IOPS_IO_DEPTH=256

#Set the Fio job runtime in seconds
#Baseline default is 60 seconds
RUNTIME=60

#Set the Fio ramp-up time in seconds
#Baseline default is 0 seconds
RAMPTIME=0

#Create the Fio working directory
mkdir -p $FIO_PATH

#Print the throughput test parameters
echo -e "[$(date "+%H:%M:%S:%3N")] Throughput test parameters: $BW_JOB_COUNT job/s in parallel; IO depth of $BW_IO_DEPTH; test file set with $BW_JOB_COUNT x $BW_FILE_SIZE sized file/s."

#Create/Layout the file set used by fio for bandwidth test
echo -e "[$(date "+%H:%M:%S:%3N")] Verifying/laying out the throughput test file set. This might take a while. Please wait..."
fio --create_only=1 --fallocate=none --ioengine=$FIO_IOENGINE --iodepth=$BW_IO_DEPTH --create_serialize=0 --direct=1 --bs=16m --size=$BW_FILE_SIZE --rw=read --numjobs=$BW_JOB_COUNT --name=bw_test --directory=$FIO_PATH --kb_base=1000 > $OUT_LAYOUT

#Clean/drop client caches and buffers
echo -e "[$(date "+%H:%M:%S:%3N")] Cleaning/dropping client cache and buffers..."
echo 3 > /proc/sys/vm/drop_caches

#Fio Test Read Bandwidth
echo -e "[$(date "+%H:%M:%S:%3N")] Started read throughput test. Runtime will be $RUNTIME seconds. Please wait..."
taskset -c 0-9,10-19 fio --ramp_time=$RAMPTIME --exitall --time_based --group_reporting=1 --ioengine=$FIO_IOENGINE --iodepth=$BW_IO_DEPTH --direct=1 --bs=$BW_IO_SIZE --size=$BW_FILE_SIZE --rw=read --numjobs=$BW_JOB_COUNT --name=bw_test --directory=$FIO_PATH --runtime=$RUNTIME --kb_base=1000 > $OUT_BW_READ
READ_BW=$(grep -oP "BW=[0-9]*[\S]*" $OUT_BW_READ | cut -d '=' -f 2)
echo -e "[$(date "+%H:%M:%S:%3N")] Test finished. Read Throughput:" $READ_BW
echo -e "[$(date "+%H:%M:%S:%3N")] Please refer to $OUT_BW_READ for detailed read test statistics."

#Clean/drop client caches and buffers
echo -e "[$(date "+%H:%M:%S:%3N")] Cleaning/dropping client cache and buffers..."
echo 3 > /proc/sys/vm/drop_caches

#Fio Test Write Bandwidth
echo -e "[$(date "+%H:%M:%S:%3N")] Started write throughput test. Runtime will be $RUNTIME seconds. Please wait..."
taskset -c 0-9,10-19 fio --ramp_time=$RAMPTIME --exitall --time_based --group_reporting=1 --ioengine=$FIO_IOENGINE --iodepth=$BW_IO_DEPTH --direct=1 --bs=$BW_IO_SIZE --size=$BW_FILE_SIZE --rw=write --numjobs=$BW_JOB_COUNT --name=bw_test --directory=$FIO_PATH --runtime=$RUNTIME --kb_base=1000 > $OUT_BW_WRITE
WRITE_BW=$(grep -oP "BW=[0-9]*[\S]*" $OUT_BW_WRITE | cut -d '=' -f 2)
echo -e "[$(date "+%H:%M:%S:%3N")] Test finished. Write Throughput:" $WRITE_BW
echo -e "[$(date "+%H:%M:%S:%3N")] Please refer to $OUT_BW_WRITE for detailed write test statistics."
echo -e "[$(date "+%H:%M:%S:%3N")] Throughput tests finished. Cleaning up and deleting the test file set."
rm -f $FIO_PATH/bw_test*
echo -e "[$(date "+%H:%M:%S:%3N")] Cleanup finished."

#Print the throughput test parameters
echo -e "[$(date "+%H:%M:%S:%3N")] IOPS test parameters: $IOPS_JOB_COUNT job/s in parallel; IO depth of $IOPS_IO_DEPTH; test file set with $IOPS_JOB_COUNT x $IOPS_FILE_SIZE sized file/s."

#Create/Layout the files used by fio for IOPS test
echo -e "[$(date "+%H:%M:%S:%3N")] Verifying/laying out the IOPS test file set. This might take a while. Please wait..."
fio --create_only=1 --fallocate=none --ioengine=$FIO_IOENGINE --iodepth=$IOPS_IO_DEPTH --create_serialize=0 --direct=1 --bs=$BW_IO_SIZE --size=$IOPS_FILE_SIZE --rw=read --numjobs=$IOPS_JOB_COUNT --name=iops_test --directory=$FIO_PATH --kb_base=1000 >> $OUT_LAYOUT

#Clean/drop client caches and buffers
echo -e "[$(date "+%H:%M:%S:%3N")] Cleaning/dropping client cache and buffers..."
echo 3 > /proc/sys/vm/drop_caches

#Fio Test IOPS
echo -e "[$(date "+%H:%M:%S:%3N")] Started IOPS test. Runtime will be $RUNTIME seconds. Please wait..."
fio --ramp_time=$RAMPTIME --exitall --time_based --ioengine=$FIO_IOENGINE --rw=randread --iodepth=$IOPS_IO_DEPTH --blocksize=$IOPS_IO_SIZE --direct=1 --size=$IOPS_FILE_SIZE --runtime=$RUNTIME --name=iops_test --numjobs=$IOPS_JOB_COUNT --group_reporting=1 --directory=$FIO_PATH --create_serialize=0 --disable_lat=1 --disable_clat=1 --disable_slat=1 --disable_bw=1 --kb_base=1000 > $OUT_IOPS
IOPS=$(grep -oP "IOPS=[0-9]*[\S*][^,]" $OUT_IOPS | cut -d '=' -f 2)
echo -e "[$(date "+%H:%M:%S:%3N")] Test finished. IOPS:" $IOPS
echo -e "[$(date "+%H:%M:%S:%3N")] IOPS test finished. Cleaning up and deleting the test file set."
rm -f $FIO_PATH/iops_test*
echo -e "[$(date "+%H:%M:%S:%3N")] Cleanup finished."

#Print the result summary
printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
echo -e "Result Summary"
echo -e "Read Throughput: " $READ_BW
echo -e "Write Throughput:" $WRITE_BW
echo -e "IOPS:            " $IOPS
