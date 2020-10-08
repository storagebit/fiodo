#!/usr/bin/env bash
#Copyright (c) 2020 StorageBIT.ch
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
    echo -e "[$(date "+%H:%M:%S")] This script needs to be run as root or using sudo."
    echo -e "[$(date "+%H:%M:%S")] Goodbye."
  exit 1
fi

FIO_WORK_DIR=

#Define IO engine - run "fio --enghelp" to list available ioengines on the client
#the default is set to "libaio"
FIO_IOENGINE=libaio

#Define Fio transfer/IO block file sizes
#Baseline default is 16m for throughput and 4k for IOPS testing
BW_IO_SIZE=16M
IOPS_IO_SIZE=4K

#Define Fio test files size and files per prcoess/job
#Baseline default is 10g for throughput and 4g for IOPS testing
BW_FILE_SIZE=10g
BW_FILE_COUNT=1
IOPS_FILE_SIZE=4g
IOPS_FILE_COUNT=1

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

function usage
{
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo -e "fiodo.sh usage: $0 --fio-workdir <path> [--fio-path <path>] [--runtime <runtime>] [--ramptime]";
    echo -e "                  [--bw-io-size <size>] [--bw-file-size <size>] [--bw-jobs <job count>]";
    echo -e "                  [--bw-io-depth <io depth>] [--iops-io-size <size>] [--iops-file-size <size>]";
    echo -e "                  [--iops-jobs <job count>] [--iops-io-depth <io depth>]";
    echo -e "                  [--result-output <path>] [--cleanup yes|1|true] [--help]";
    echo -e "\nRequired arguments:";
    echo -e "  --fio-workdir       : Path to the folder fio will use to run the tests in."
    echo -e "\nOptional arguents:"
    echo -e "  --fio-ioengine      : Fio io-engine to be used. Run 'fio -enghelp' to see available options. Default is libaio."
    echo -e "  --runtime           : Runtime in seconds. Default is 60.";
    echo -e "  --ramptime          : Ramp up time in seconds. Default 0.";
    echo -e "  --bw-file-size      : File size for throughput testing. Default is 10g."
    echo -e "  --bw-file-count     : # files used per throughput testing process. Default is 1."
    echo -e "  --bw-io-size        : IO/transfer size for throughput testing. Default is 16m.";
    echo -e "  --bw-job-count      : # of throughput test processes per client running in parallel. Default is 16.";
    echo -e "  --bw-io-depth       : IO depth used for the throughput tests. Default is 16.";
    echo -e "  --iops-file-size    : File size for IOPS testing. Default is 4g."
    echo -e "  --iops-file-count   : # files used per IOPS testing process. Default is 1."
    echo -e "  --iops-io-size      : IO/transfer size for IOPS testing. Default is 4k.";
    echo -e "  --iops-job-count    : # of IOPS test processes per client running in parallel. Default is 128.";
    echo -e "  --iops-io-depth     : IO depth used for the IOPS tests. Default is 256.";
    echo -e "  --result-output     : Path where the tests results are stored. Default is the uers home directory.";
    echo -e "  --cleanup           : Cleanup and delete all Fio test file sets after test run";
    echo -e "  --help              : This output.";
}

function parse_arguments
{
  # Parsing the arguments
  while [ "$1" != "" ]; do
      case "$1" in
          --cleanup )         CLEAN_UP="true";          shift;;
          --fio-workdir )     FIO_WORK_DIR="$2";        shift;;
          --fio-ioengine )    FIO_IOENGINE="$2";        shift;;
          --runtime )         RUNTIME="$2";             shift;;
          --ramptime )        RAMPTIME="$2";            shift;;
          --bw-file-size )    BW_FILE_SIZE="$2";        shift;;
          --bw-file-count )   BW_FILE_COUNT="$2";       shift;;
          --bw-job-count )    BW_JOB_COUNT="$2";        shift;;
          --bw-io-depth )     BW_IO_DEPTH="$2";         shift;;
          --bw-io-size )      BW_IO_SIZE="$2";          shift;;
          --iops-file-size )  IOPS_FILE_SIZE="$2";      shift;;
          --iops-file-count ) IOPS_FILE_COUNT="$2";     shift;;
          --iops-job-count )  IOPS_JOB_COUNT="$2";      shift;;
          --iops-io-depth )   IOPS_IO_DEPTH="$2";       shift;;
          --iops-io-size )    IOPS_IO_SIZE="$2";        shift;;
          --result-output )   OUT_BASE="$2";            shift;;
          -h | --help )       usage;                    exit 0;; # exit and show usage
          -* | --*)           echo -e "[$(date "+%H:%M:%S")]  Unsupported option/argument $1" >&2; usage; exit 1;; # exit and show usage
      esac
      shift # move to next argument to parse
  done

  if [[ -z "$FIO_WORK_DIR" ]]; then
      echo -e "[$(date "+%H:%M:%S")] Cannot run as --fio-workdir is not specified!"
      echo -e "[$(date "+%H:%M:%S")] Goodbye."
      exit 1
  fi
}

function run
{
    parse_arguments "$@"

    BENCHMARK_TIME=$(date "+%Y.%m.%d-%H.%M.%S")

    OUT_BASE=$HOME/fiodo_results/$BENCHMARK_TIME/$HOSTNAME
    FIO_WORK_DIR=$FIO_WORK_DIR/$HOSTNAME

    mkdir -p $FIO_WORK_DIR
    mkdir -p $OUT_BASE

    FIO_PATH=`which fio`

    #Output log files locations - DO NOT CHANGE!
    OUT_BW_LAYOUT=$OUT_BASE/bw_layout_$BENCHMARK_TIME.txt
    OUT_IOPS_LAYOUT=$OUT_BASE/iops_layout_$BENCHMARK_TIME.txt
    OUT_BW_READ=$OUT_BASE/bw_read_result_$BENCHMARK_TIME.txt
    OUT_BW_WRITE=$OUT_BASE/bw_write_result_$BENCHMARK_TIME.txt
    OUT_IOPS=$OUT_BASE/iops_result_$BENCHMARK_TIME.txt

    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    #Print the testing parameters
    echo -e "[$(date "+%H:%M:%S")] Started benchmark run with PID $BASHPID."
    echo -e "[$(date "+%H:%M:%S")] Benchmark runtime environment:"
    echo -e "   Hostname:                               $HOSTNAME"
    echo -e "   Fio executable:                         $FIO_PATH"
    echo -e "   Fio version:                            $($FIO_PATH --version)"
    echo -e "   Runtime:                                $RUNTIME seconds"
    echo -e "   Ramptime:                               $RAMPTIME seconds"
    echo -e "   Working directory:                      $FIO_WORK_DIR"
    echo -e "   Results output directory:               $OUT_BASE"
    echo -e "   Throughput test IO/transfer size:       $BW_IO_SIZE"
    echo -e "   Throughput test file size:              $BW_FILE_SIZE"
    echo -e "   Throughput test file count per process: $BW_FILE_COUNT"
    echo -e "   Throughput test process count:          $BW_JOB_COUNT"
    echo -e "   Throughput test IO depth:               $BW_IO_DEPTH"
    echo -e "   Throughput test data set composition:   $((BW_FILE_COUNT * BW_JOB_COUNT))x $BW_FILE_SIZE files"
    echo -e "   IOPS test IO/transfer size:             $IOPS_IO_SIZE"
    echo -e "   IOPS test file size:                    $IOPS_FILE_SIZE"
    echo -e "   IOPS test file count per process:       $IOPS_FILE_COUNT"
    echo -e "   IOPS test process count:                $IOPS_JOB_COUNT"
    echo -e "   IOPS test IO depth:                     $IOPS_IO_DEPTH"
    echo -e "   IOPS test data set composition:         $((IOPS_FILE_COUNT * IOPS_JOB_COUNT))x $IOPS_FILE_SIZE files"

    if [[ $CLEAN_UP ]]; then
	  echo -e "   Cleanup/deleting test file sets:        Yes"
    else
	  echo -e "   Cleanup/deleting test file sets:        No"
    fi

    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -

    #Create the Fio working directory
    mkdir -p $FIO_WORK_DIR

    #Create/Layout the file set used by fio for bandwidth test
    echo -e "[$(date "+%H:%M:%S")] Verifying/laying out the throughput test file set. This might take a while. Please wait..."
    $FIO_PATH --create_only=1 --fallocate=none --ioengine=$FIO_IOENGINE --iodepth=$BW_IO_DEPTH --create_serialize=0 --direct=1 --bs=16m --size=$BW_FILE_SIZE --nr_files=$BW_FILE_COUNT --rw=read --numjobs=$BW_JOB_COUNT --name=bw_test --directory=$FIO_WORK_DIR --kb_base=1000 > $OUT_BW_LAYOUT 2>&1

    #Clean/drop client caches and buffers
    echo -e "[$(date "+%H:%M:%S")] Cleaning/dropping client cache and buffers..."
    echo -e 3 > /proc/sys/vm/drop_caches

    #Fio Test Read Bandwidth
    echo -e "[$(date "+%H:%M:%S")] Started read throughput test. Runtime will be $RUNTIME seconds. Please wait..."
    $FIO_PATH --ramp_time=$RAMPTIME --exitall --time_based --group_reporting=1 --ioengine=$FIO_IOENGINE --iodepth=$BW_IO_DEPTH --direct=1 --bs=$BW_IO_SIZE --size=$BW_FILE_SIZE --nr_files=$BW_FILE_COUNT --rw=read --numjobs=$BW_JOB_COUNT --name=bw_test --directory=$FIO_WORK_DIR --runtime=$RUNTIME --kb_base=1000 > $OUT_BW_READ 2>&1
    READ_BW=$(grep -oP "BW=[0-9]*[\S]*" $OUT_BW_READ | cut -d '=' -f 2)
    echo -e "[$(date "+%H:%M:%S")] Test finished. Read Throughput:" $READ_BW
    echo -e "[$(date "+%H:%M:%S")] Please refer to $OUT_BW_READ for detailed read test statistics."

    #Clean/drop client caches and buffers
    echo -e "[$(date "+%H:%M:%S")] Cleaning/dropping client cache and buffers..."
    echo -e 3 > /proc/sys/vm/drop_caches

    #Fio Test Write Bandwidth
    echo -e "[$(date "+%H:%M:%S")] Started write throughput test. Runtime will be $RUNTIME seconds. Please wait..."
    $FIO_PATH --ramp_time=$RAMPTIME --exitall --time_based --group_reporting=1 --ioengine=$FIO_IOENGINE --iodepth=$BW_IO_DEPTH --direct=1 --bs=$BW_IO_SIZE --size=$BW_FILE_SIZE --nr_files=$BW_FILE_COUNT --rw=write --numjobs=$BW_JOB_COUNT --name=bw_test --directory=$FIO_WORK_DIR --runtime=$RUNTIME --kb_base=1000 > $OUT_BW_WRITE 2>&1
    WRITE_BW=$(grep -oP "BW=[0-9]*[\S]*" $OUT_BW_WRITE | cut -d '=' -f 2)
    echo -e "[$(date "+%H:%M:%S")] Test finished. Write Throughput:" $WRITE_BW
    echo -e "[$(date "+%H:%M:%S")] Please refer to $OUT_BW_WRITE for detailed write test statistics."

    if [[ $CLEAN_UP ]]; then
        echo -e "[$(date "+%H:%M:%S")] Cleaning up and deleting the test file set."
        rm -f $FIO_WORK_DIR/bw_test*
        echo -e "[$(date "+%H:%M:%S")] Cleanup finished."
    fi

    #Create/Layout the files used by fio for IOPS test
    echo -e "[$(date "+%H:%M:%S")] Verifying/laying out the IOPS test file set. This might take a while. Please wait..."
    $FIO_PATH --create_only=1 --fallocate=none --ioengine=$FIO_IOENGINE --iodepth=16 --create_serialize=0 --direct=1 --bs=16m --size=$IOPS_FILE_SIZE --nr_files=$IOPS_FILE_COUNT --rw=read --numjobs=$IOPS_JOB_COUNT --name=iops_test --directory=$FIO_WORK_DIR --kb_base=1000 > $OUT_IOPS_LAYOUT 2>&1

    #Clean/drop client caches and buffers
    echo -e "[$(date "+%H:%M:%S")] Cleaning/dropping client cache and buffers..."
    echo -e 3 > /proc/sys/vm/drop_caches

    #Fio Test IOPS
    echo -e "[$(date "+%H:%M:%S")] Started IOPS test. Runtime will be $RUNTIME seconds. Please wait..."
    $FIO_PATH --ramp_time=$RAMPTIME --exitall --time_based --ioengine=$FIO_IOENGINE --rw=randread --iodepth=$IOPS_IO_DEPTH --blocksize=$IOPS_IO_SIZE --direct=1 --size=$IOPS_FILE_SIZE --nr_files=$IOPS_FILE_COUNT --runtime=$RUNTIME --name=iops_test --numjobs=$IOPS_JOB_COUNT --group_reporting=1 --directory=$FIO_WORK_DIR --create_serialize=0 --disable_lat=1 --disable_clat=1 --disable_slat=1 --disable_bw=1 --kb_base=1000 > $OUT_IOPS 2>&1
    IOPS=$(grep -oP "IOPS=[A-Za-z0-9.]*" $OUT_IOPS | cut -d '=' -f 2)
    echo -e "[$(date "+%H:%M:%S")] Test finished. IOPS:" $IOPS

    if [[ $CLEAN_UP ]]; then
        echo -e "[$(date "+%H:%M:%S")] Cleaning up and deleting the test file set."
        rm -f $FIO_WORK_DIR/iops_test*
        echo -e "[$(date "+%H:%M:%S")] Cleanup finished."
    fi

    #Print the result summary
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
    echo -e "[$(date "+%H:%M:%S")] Result Summary for test run with the time stamp: $BENCHMARK_TIME"
    echo -e "   Read Throughput: " $READ_BW
    echo -e "   Write Throughput:" $WRITE_BW
    echo -e "   IOPS:            " $IOPS
    printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
}
run "$@";
