#!/usr/bin/env bash

# Print an error message and exit
function die() {
  echo -e "\nError: $@\n" 1>&2
  print_usage
  exit 1
}

function print_usage() {
  echo "gobblin-cluster-worker.sh <start | stop>"
  echo "Where OPTION can be:"
  echo "  --cluster <unique name for the cluster>        Unique name for the cluster"
  echo "  --workerid <unique id of workers>              Worker id for each worker if running multiple workers"
  echo "  --jvmflags <string of jvm flags>               String containing any additional JVM flags to include"
  echo "  --jars <column-separated list of extra jars>   Column-separated list of extra jars to put on the CLASSPATH"
  echo "  --help                                         Display this help and exit"
}

function start() {
  for jarFile in `ls ${FWDIR_LIB}/*`
  do
    GOBBLIN_JARS=${GOBBLIN_JARS}:${jarFile}
  done

  export HADOOP_USER_CLASSPATH_FIRST=true

  CLASSPATH=${FWDIR_CONF}:${GOBBLIN_JARS}:${CLUSTER_CONF_DIR}:${HADOOP_HOME}/lib
  if [ -n "$EXTRA_JARS" ]; then
    CLASSPATH=$CLASSPATH:"$EXTRA_JARS"
  fi

  LOG_ARGS="1>${FWDIR_LOGS}/GobblinCluster.worker.$WORKER_ID.stdout 2>${FWDIR_LOGS}/GobblinCluster.worker.$WORKER_ID.stderr"

  COMMAND="$JAVA_HOME/bin/java -cp $CLASSPATH $JVM_FLAGS gobblin.cluster.GobblinTaskRunner --app_name $CLUSTER_NAME --helix_instance_name worker.$WORKER_ID $LOG_ARGS"

  echo "Running command:"
  echo "$COMMAND"
  nohup $COMMAND >worker.$WORKER_ID.out 2>&1 & echo $! > $PID
}

function stop() {
  if [ -f "$PID" ]; then
    if kill -0 $PID_VALUE > /dev/null 2>&1; then
      echo 'Stopping the Gobblin Standalone cluster'
      kill $PID_VALUE
    else
      echo "Process $PID_VALUE is not running"
    fi
  else
    echo "No pid file found"
  fi
}

FWDIR="$(cd `dirname $0`/..; pwd)"
FWDIR_LIB=${FWDIR}/lib
FWDIR_CONF=${FWDIR}/conf/standalone
FWDIR_BIN=${FWDIR}/bin
FWDIR_LOGS=${FWDIR}/logs
CLUSTER_NAME="standalone_cluster"
WORKER_ID="single"

. ${FWDIR_BIN}/gobblin-env.sh

for i in "$@"
do
  case "$1" in
    start|stop)
      ACTION="$1"
      ;;
    --jvmflags)
      JVM_FLAGS="$2"
      shift
      ;;
    --jars)
      EXTRA_JARS="$2"
      shift
      ;;
    --cluster)
      CLUSTER_NAME="$2"
      shift
      ;;
    --workerid)
      WORKER_ID="$2"
      shift
      ;;
    --help)
      print_usage
      exit 0
      ;;
    *)
      ;;
  esac
  shift
done

if [ -z "$JAVA_HOME" ]; then
  die "Environment variable JAVA_HOME not set!"
fi

# User defined JVM flags overrides $GOBBLIN_JVM_FLAGS (if any)
if [ -n "$JVM_FLAGS" ]; then
  JVM_FLAGS="-Xmx1g -Xms512m"
fi

PID="$FWDIR/.gobblin-cluster-worker-app-pid.$WORKER_ID"

if [ -f "$PID" ]; then
  PID_VALUE=`cat $PID` > /dev/null 2>&1
else
  PID_VALUE=""
fi

case "$ACTION" in
  "start")
    start
    ;;
  "stop")
    stop
    ;;
  *)
    print_usage
    exit 1
    ;;
esac
