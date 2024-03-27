#!/bin/bash
# A wrapper for running corb with minimum configuration
#
main() {
  initialize
  local start=$(date +%s)
  local type="validate"
  local job=$1
  local dataReport=corb-report-latest.txt
  local javaReport=corb-output-latest.log
  echo "" >$dataReport
  echo "" >$javaReport

  if [ -z "$job" ]; then
    echo "No job provided. Exiting."
    exit 1
  fi

  II "Storing corb log for job [$job] in [$javaReport]"
  II "Storing corb report for job [$job] in [$dataReport]"

  #set -o xtrace
  corbOpts=(
    -server -cp .:$CORB_JAR:$XCC_JAR
    -DXCC-CONNECTION-URI="xcc://${ML_USER}:${ML_PASS}@${ML_HOST}:${ML_CORB_PORT}"
    -DOPTIONS-FILE="${job}.corb"
    -DEXPORT-FILE-NAME="$dataReport"
  )

  # set -o xtrace
  java "${corbOpts[@]}" com.marklogic.developer.corb.Manager >$javaReport 2>&1
  # set +o xtrace

  echo " ----------------- " >>$javaReport
  II "-> Corb job [$job] took [$(($(date +%s) - $start))] seconds"
  II "-> Report [$dataReport]"
}

II() { echo "$(date +%Y-%m-%dT%H:%M:%S%z): $@"; }

initialize() {
  if [ ! -f "$CORB_JAR" ]; then
    echo "Please set CORB_JAR in your ~/.mlshrc file."
    return
  fi
  if [ ! -f "$XCC_JAR" ]; then
    echo "Please set XCC_JAR in your ~/.mlshrc file."
    return
  fi
  if [ -z "$ML_HOST" ]; then
    echo "ERROR: Expected environment variable [ML_HOST] not defined! Please source your environment."
    exit 1
  fi
  if [ -z "$ML_CORB_PORT" ]; then
    echo "ERROR: Expected environment variable [ML_CORB_PORT] not defined! Please source your environment."
    exit 1
  fi
}

while [ "$#" -gt "0" ]; do
  case $1 in
  --task)
    shift
    task=$1
    shift
    ;;

  --job)
    shift
    job=$1
    shift
    ;;

  --threads)
    shift
    threads=$1
    shift
    ;;

  --batchSize)
    shift
    batchSize=$1
    shift
    ;;

  *)
    echo "Unknown option [$1]"
    shift
    exit
    ;;
  esac
done

startedAt="$(date +%s)"
timestamp="$(date +%Y-%m-%dT%H:%M:%S%z)"
log=./results/run-${startedAt}/log

if [ -n "$job" ]; then
  main $job
else
  runDir=./results/run-${startedAt}
  mkdir -p $runDir
  source $(dirname $0)/interactive.sh
  interactive
fi
