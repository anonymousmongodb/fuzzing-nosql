#!/usr/bin/env bash

EXP=$1
TB=$2

## where to save raw jvm coverage report
DIR=jvm_results/TB_$TB
CS_DIR=$EMB_DIR

## rm -fr $DIR

mkdir -p $DIR

## jvm
for f in $EXP/exec/*.exec
do
  echo Analyzing jvm coverage file $f

  file=$(sed -n '3p' <<<  $(echo $f | tr "/" "\n"))  # very brittle... assume EXP be single folder with no /
  name=$(sed -n '1p' <<<   $(echo $file | tr "." "\n"))
  tokens=$(echo $file | tr "__" "\n")
  sut=$(sed -n '1p' <<<  $tokens)
  tool=$(sed -n '3p' <<<  $tokens)  # weird it needs 3 and not 2...

  # above code does not work on Mac M.x, then replace them as below
#  file=$(echo $f | tr "/" "\n" | tail -1)
#  name=$(echo $file | tr "." "\n" | head -1)
#  sut=$(echo $file | tr "__" "\n" | head -1)

  if [ "$sut" = "rest-scs" ]; then
    target="$CS_DIR/../jdk_8_maven/cs/rest/artificial/scs/target/classes"
  elif [ "$sut" = "rest-ncs" ]; then
    target="$CS_DIR/../jdk_8_maven/cs/rest/artificial/ncs/target/classes"
  elif [ "$sut" = "rest-news" ]; then
    target="$CS_DIR/../jdk_8_maven/cs/rest/artificial/news/target/classes"
  elif [ "$sut" = "proxyprint" ]; then
    target="$CS_DIR/../jdk_8_maven/cs/rest/original/proxyprint/target/classes"
  elif [ "$sut" = "catwatch" ]; then
    target="$CS_DIR/../jdk_8_maven/cs/rest/original/catwatch/catwatch-backend/target/classes"
  elif [ "$sut" = "features-service" ]; then
    target="$CS_DIR/../jdk_8_maven/cs/rest/original/features-service/target/classes"
  elif [ "$sut" = "restcountries" ]; then
    target="$CS_DIR/../jdk_8_maven/cs/rest/original/restcountries/target/classes"
  elif [ "$sut" = "cwa-verification" ]; then
    target="$CS_DIR/../jdk_11_maven/cs/rest/cwa-verification-server/target/classes"
  elif [ "$sut" = "gestaohospital-rest" ]; then
      target="$CS_DIR/../jdk_8_maven/cs/rest-gui/gestaohospital/target/classes"
  elif [ "$sut" = "rest-faults" ]; then
      target="$REST_FAULTS_SUT/classes"
  elif [ "$sut" = "rest-faults-local" ]; then
      target="$REST_FAULTS_SUT/classes"
  # ind0
  elif [ "$sut" = "ind0" ]; then
        target="$SUT_CLASSES_LOCATION_IND0"
  ### WARNING: multi-module projects are a pain to handle in JaCoCo... :(
  elif [ "$sut" = "scout-api" ]; then
    target="classes/scout-api.zip"
  elif [ "$sut" = "ocvn-rest" ]; then
    target="classes/ocvn.zip"
  elif [ "$sut" = "languagetool" ]; then
    target="classes/languagetool.zip"
  elif [ "$sut" = "bibliothek" ]; then
      target="$CS_DIR/../jdk_17_gradle/cs/rest/bibliothek/build/classes"
  elif [ "$sut" = "genome-nexus" ]; then
      target="classes/genome.zip"
  elif [ "$sut" = "reservations-api" ]; then
        target="$CS_DIR/../jdk_11_gradle/cs/rest/reservations-api/build/classes"
  elif [ "$sut" = "session-service" ]; then
      target="$CS_DIR/../jdk_8_maven/cs/rest/original/session-service/target/classes"
  else
    echo "Unrecognized SUT: " $name
    exit 1
  fi

  java -jar tools/jacococli.jar report $f  --classfiles "$target"  --csv $DIR/$name.csv

done

