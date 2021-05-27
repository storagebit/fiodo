# fiodo
Shell/Bash wrapper around the FIO (Flexible IO Tester) Tool

## What does it do?
This tool is a wrapper around the FIO (Flexible IO Tester) running:
* Sequential write tests
* Sequential read tests
* Random 4k reads

The tool comes with preconfigured fio job and run settings which can be customized.
At the end of each run it will print a summary of each run and keeps the fio detailed output  
in a sub-folder of the users home directory by default.

## How to run it
Requires root or sudo at least.

Quite easy. `chmod +x fiodo.sh` and then: `$ sudo ./fiodo.sh --fio-workdir <path to fio work directory to be tested>`

Details as below:
```
fiodo.sh usage: ./fiodo.sh --fio-workdir <path> [--fio-path <path>] [--runtime <runtime>] [--ramptime]
                  [--bw-io-size <size>] [--bw-file-size <size>] [--bw-jobs <job count>]
                  [--bw-io-depth <io depth>] [--iops-io-size <size>] [--iops-file-size <size>]
                  [--iops-jobs <job count>] [--iops-io-depth <io depth>]
                  [--result-output <path>] [--cleanup yes|1|true] [--help]

Required arguments:
  --fio-workdir       : Path to the folder fio will use to run the tests in.

Optional arguents:
  --fio-ioengine      : Fio io-engine to be used. Run 'fio -enghelp' to see available options. Default is libaio.
  --runtime           : Runtime in seconds. Default is 60.
  --ramptime          : Ramp up time in seconds. Default 0.
  --bw-file-size      : File size for throughput testing. Default is 10g.
  --bw-file-count     : # files used per throughput testing process. Default is 1.
  --bw-io-size        : IO/transfer size for throughput testing. Default is 16m.
  --bw-job-count      : # of throughput test processes per client running in parallel. Default is 16.
  --bw-io-depth       : IO depth used for the throughput tests. Default is 16.
  --iops-file-size    : File size for IOPS testing. Default is 4g.
  --iops-file-count   : # files used per IOPS testing process. Default is 1.
  --iops-io-size      : IO/transfer size for IOPS testing. Default is 4k.
  --iops-job-count    : # of IOPS test processes per client running in parallel. Default is 128.
  --iops-io-depth     : IO depth used for the IOPS tests. Default is 256.
  --result-output     : Path where the tests results are stored. Default is the uers home directory.
  --cleanup           : Cleanup and delete all Fio test file sets after test run
  --help              : This output.
```
