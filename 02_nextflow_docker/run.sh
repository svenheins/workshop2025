## set environment variables from .env file
set -a
source ../.env 
set +a

## run nextflow with docker
nextflow run main.nf -with-docker