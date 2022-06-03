#!/bin/bash




# Service Running Helper Function
running () {
    local url=${1:-http://localhost:80}
    local code=${2:-200}
    local status=$(curl --head --location --connect-timeout 5 --write-out %{http_code} --silent --output /dev/null ${url})
    [[ $status == ${code} ]]
}


# dependencies checks

if ! command -v jq > /dev/null 2>&1; then
    printf '\n%s\n%s\n' "ERROR: Jq is not available." \
                        "These scripts require jq, please install and try again."
    exit 1
fi

if ! command -v curl -V > /dev/null 2>&1; then
      printf '\n%s\n%s\n' "ERROR: curl is not available." \
                          "These scripts require curl, please install and try again."
      exit 1
fi

if ! docker info > /dev/null 2>&1
  then
    printf '%s\n%s\n' "ERROR: docker is not available or not runnning." \
                      "This script requires docker, please install and try again."
    exit 1
fi
if ! docker-compose version > /dev/null 2>&1
  then
    printf '%s\n%s\n' "ERROR: docker-compose is not available or not runnning." \
                      "This script requires docker-compose, please install and try again."
    exit 1
fi

# regex pattern validation for user input
TL_SECRETKEY_MATCH='^(\w|\d|\/|\+){27}\=$'
TL_ACCESSKEY_MATCH='^(\d|\w){8}\-(\d|\w){4}\-(\d|\w){4}\-(\d|\w){4}\-(\d|\w){12}$'
TL_CONSOLE_MATCH='^https\:\/\/(\w|\d|\.|\-|\_|\:|\/)+$'

# used to validate user input
tl-var-check () {
if [[ ! $TL_CONSOLE =~ $TL_CONSOLE_MATCH ]]
  then
    printf '%s\n' "$TL_CONSOLE is not a valid value for TL_CONSOLE. Please recopy, verify, and run again"
    exit 1
fi

if [[ ! $TL_SECRETKEY =~ $TL_SECRETKEY_MATCH ]]
  then
     printf '%s\n' "The Secret key is not valid. Please recopy, verify, and run again"
     exit 1
fi

if [[ ! $TL_ACCESSKEY =~ $TL_ACCESSKEY_MATCH ]]
  then
     printf '%s\n' "The Access Key is not valid. Please recopy, verify, and run again"
     exit 1
fi
}



# path to secrets.env file used for collector
ENV_FILE_PATH="./collector/secrets.env"

# collect user input; assign to vars
printf '%s\n' "enter your prisma access key id:"
read -r  TL_ACCESSKEY
printf '%s\n' "enter your prisma secret key id:"
read -r -s  TL_SECRETKEY
printf '%s\n' "enter your prisma cloud api url, like https://us-east1.cloud.twistlock.com/us-1-1111111"
read -r TL_CONSOLE

# check user input
tl-var-check


# validate the credentials are active and ready to go. 
AUTH_PAYLOAD=$(cat <<EOF
{"username": "$TL_ACCESSKEY", "password": "$TL_SECRETKEY"}
EOF
)



# add -k to curl if using self-hosted version with a self-signed cert
TL_JWT_RESPONSE=$(curl -s -k --request POST \
                       --url "$TL_CONSOLE/api/v1/authenticate" \
                       --header 'Content-Type: application/json' \
                       --data "$AUTH_PAYLOAD")


TL_JWT=$(printf %s "$TL_JWT_RESPONSE" | jq -r '.token' )

if [ -z "$TL_JWT" ]
    then
        printf '\n%s\n' "Prisma compute api token not retrieved, have you verified the expiration date of the access key and secret key? Have you verified connectivity to the url provided: $TL_CONSOLE? Troubleshoot and then you'll need to run this script again"
        exit 1
    else
       printf '\n%s\n%s\n' "Token retrieved" \
                           "parameters provided are valid"
fi


# parse the $TL_CONSOLE VAR to get the pieces needed for the prometheus yaml file
TL_DOMAIN=$(printf '%s' "$TL_CONSOLE" | awk -F '\/' '{print $3}')
TL_REGION=$(printf '%s' "$TL_CONSOLE" | awk -F '\/' '{print $4}')



printf '%s\n' "Configuring prometheus.yml file"

# replace values in prometheus yaml config file
sed -i "s|prisma_cloud_compute_domain|$TL_DOMAIN|g" "./prometheus/prometheus.yml"
sed -i "s|prisma_cloud_compute_region|$TL_REGION\/api\/v1\/metrics|g" "./prometheus/prometheus.yml"
sed -i "s|PC_ACCESS_KEY|$TL_ACCESSKEY|g" "./prometheus/prometheus.yml"
sed -i "s|PC_SECRET_KEY|$TL_SECRETKEY|g" "./prometheus/prometheus.yml"

printf '%s\n' "-----------------------------------------"


# create the secret file for the collector
printf '%s\n' "Configuring env file"
printf '%s\n%s\n%s\n%s\n' "#!/bin/sh" \
                          "TL_CONSOLE=\"$TL_CONSOLE\"" \
                          "TL_ACCESSKEY=\"$TL_ACCESSKEY\"" \
                          "TL_SECRETKEY=\"$TL_SECRETKEY\"" > $ENV_FILE_PATH

# build collector container
printf '%s\n%s\n' "-----------------------------------------" \
                  "Building collector container"

docker build -t collector:dev ./collector/.


# orchestrate the containers using docker-compose
printf '%s\n%s\n' "-----------------------------------------" \
       "Running Docker-Compose..."
docker-compose -f docker-compose.yml up -d
printf '%s\n' "-----------------------------------------"


# verify influx is up and running
printf '%s\n' "Waiting for InfluxDB to start..."
until running http://localhost:8086/ping 204 2>/dev/null; do
    printf '.'
    sleep 5
done
printf '%s\n' " up!"
sleep 2


# import the schema for influxdb
printf '%s\n' "Setup InfluxDB Data for Prisma Cloud Compute Image Vulnerability"
docker exec -it influxdb influx -import -path=/var/lib/influxdb/influxdb.sql

sleep 2

# wrap up
printf '\n\n\n\n%s\n%s\n%s\n%s\n%s\n\n\n%s' "all done!" \
                                    "prometheus should be available on localhost:9090" \
                                    "grafana on localhost:3000" \
                                    "default username for grafana is: admin" \
                                    "default password for grafana is: admin" \
                                    "prisma api collector data can be viewed in grafana by hitting the explore icon. Select Influxdb FROM raw prismacompute. Ideas, use the imagerepo as the filter, select the sum of any of the metrics collected." 
