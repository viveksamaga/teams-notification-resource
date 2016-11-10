#!/bin/bash

set -e

on_exit() {
  exitcode=$?
  if [ $exitcode != 0 ] ; then
    echo -e '\e[41;33;1m'"Failure encountered"'\e[0m'
  fi
}

trap on_exit EXIT

test() {
  set -e
  base_dir="$(cd "$(dirname $0)" ; pwd )"
  if [ -f "${base_dir}/../out" ] ; then
    cmd="../out"
  elif [ -f /opt/resource/out ] ; then
    cmd="/opt/resource/out"
  fi

  cat <<EOM >&2
------------------------------------------------------------------------------
TESTING: $1

Input:
$(cat ${base_dir}/${1}.out)

Output:
EOM

  result="$(cd $base_dir && cat ${1}.out | $cmd . 2>&1 | tee /dev/stderr)"
  echo >&2 "" 
  echo >&2 "Result:" 
  echo "$result" # to be passed into jq -e
}

export BUILD_PIPELINE_NAME='my-pipeline'
export BUILD_JOB_NAME='my-job'
export BUILD_NAME='my-build'

webhook_url='https://some.url'
base_text=":some_emoji:<https://my-ci.my-org.com/pipelines/my-pipeline/jobs/my-job/builds/my-build|Alert!>"
sample_text="This text came from sample.txt. It could have been generated by a previous Concourse task.\n\nMultiple lines are allowed.\n"
missing_text="_(no notification provided)_"

test text | jq -e "
  .webhook_url == $(echo $webhook_url | jq -R .) and
  .body.text == \"Inline static text\n\" and 
  ( .body | keys | length ==  2 )"

test text_file | jq -e "
  .webhook_url == $(echo $webhook_url | jq -R .) and
  .body.text == \"${sample_text}\" and 
  ( .body | keys | length ==  5 )"

test text_file_empty | jq -e "
  .webhook_url == $(echo $webhook_url | jq -R .) and
  .body.text == \"${missing_text}\n\" and 
  ( .body | keys | length ==  5 )"

# test text_file_empty_suppress | jq -e "
#   ( . | keys | length == 1 ) and
#   ( . | keys | contains([\"version\"]) ) and
#   ( .version | keys == [\"timestamp\"] )"
#
# test metadata | jq -e "
#   ( .version | keys == [\"timestamp\"] )        and
#   ( .metadata[0].name == \"url\" )              and ( .metadata[0].value == \"https://hooks.teams.com/services/TH…IS/DO…ES/WO…RK\" ) and
#   ( .metadata[1].name == \"text\" )             and ( .metadata[1].value == \"Inline static text\n\" ) and
#   ( .metadata | length == 2 )"
#
test metadata_with_payload | jq -e "
  ( .version | keys == [\"timestamp\"] )        and
  ( .metadata[0].name == \"url\" )              and ( .metadata[0].value == \"https://hooks.teams.com/services/TH…IS/DO…ES/WO…RK\" ) and
  ( .metadata[1].name == \"text\" )             and ( .metadata[1].value == \"Inline static text\n\" ) and
  ( .metadata[2].name == \"payload\" )          and ( .metadata[2].value | fromjson.source.url == \"***REDACTED***\" ) and
  ( .metadata | length == 3 )"

echo -e '\e[32;1m'"All tests passed!"'\e[0m'
