## set environment variables from .env file
set -a
source ../.env 
set +a

## set the environment variables in the statefulset.yaml file and apply it to the cluster
envsubst < statefulset_no_gpu.yaml | kubectl delete -f -