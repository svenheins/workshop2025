## set environment variables from .env file
set -a
source ../.env 
set +a

## run nextflow with docker
envsubst < statefulset.yaml | kubectl apply -f -