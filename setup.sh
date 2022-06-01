#!/bin/bash




# Service Running Helper Function
running() {
    local url=${1:-http://localhost:80}
    local code=${2:-200}
    local status=$(curl --head --location --connect-timeout 5 --write-out %{http_code} --silent --output /dev/null ${url})
    [[ $status == ${code} ]]
}





# Docker Dependency Check
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


TL_SECRETKEY_MATCH='^(\w|\d|\/|\+){27}\=$'
TL_ACCESSKEY_MATCH='^(\d|\w){8}\-(\d|\w){4}\-(\d|\w){4}\-(\d|\w){4}\-(\d|\w){12}$'
TL_CONSOLE_MATCH='^https\:\/\/(\w|\d|\.|\-|\_|\:|\/)+$'


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




ENV_FILE_PATH="./collector/secrets.env"

printf '%s\n' "enter your prisma access key id:"
read -r  TL_ACCESSKEY
printf '%s\n' "enter your prisma secret key id:"
read -r -s  TL_SECRETKEY
printf '%s\n' "enter your prisma cloud api url, like https://us-east1.cloud.twistlock.com/us-1-1111111"
read -r TL_CONSOLE

tl-var-check


TL_DOMAIN=$(printf '%s' "$TL_CONSOLE" | awk -F '\/' '{print $3}')
TL_REGION=$(printf '%s' "$TL_CONSOLE" | awk -F '\/' '{print $4}')



printf '%s\n' "Configuring prometheus.yml file"

sed -i "s|prisma_cloud_compute_domain|$TL_DOMAIN|g" "./prometheus/prometheus.yml"
sed -i "s|prisma_cloud_compute_region|$TL_REGION\/api\/v1\/metrics|g" "./prometheus/prometheus.yml"
sed -i "s|PC_ACCESS_KEY|$TL_ACCESSKEY|g" "./prometheus/prometheus.yml"
sed -i "s|PC_SECRET_KEY|$TL_SECRETKEY|g" "./prometheus/prometheus.yml"

printf '%s\n' "-----------------------------------------"


printf '%s\n' "Configuring env file"
printf '%s\n%s\n%s\n%s\n' "#!/bin/sh" \
       "TL_CONSOLE=\"$TL_CONSOLE\"" \
       "TL_ACCESSKEY=\"$TL_ACCESSKEY\"" \
       "TL_SECRETKEY=\"$TL_SECRETKEY\"" > $ENV_FILE_PATH

printf '%s\n%s\n' "-----------------------------------------" \
                  "Building collector container"

docker build -t collector:dev ./collector/.

printf '%s\n%s\n' "-----------------------------------------" \
       "Running Docker-Compose..."
docker-compose -f docker-compose.yml up -d
printf '%s\n' "-----------------------------------------"


# Set up Influx
printf '%s\n' "Waiting for InfluxDB to start..."
until running http://localhost:8086/ping 204 2>/dev/null; do
    printf '.'
    sleep 5
done
printf '%s\n' " up!"
sleep 2



printf '%s\n' "Setup InfluxDB Data for Prisma Cloud Compute Image Vulnerability"
docker exec -it influxdb influx -import -path=/var/lib/influxdb/influxdb.sql

sleep 2

printf '%s\n%s\n%s\n%s\n%s\n\n\n%s' "all done!" \
                                    "prometheus should be available on localhost:9090" \
                                    "grafana on localhost:3000" \
                                    "default username for grafana is: admin" \
                                    "default password for grafana is: admin" \
                                    "prisma api collector data can be viewed in grafana by hitting the explore icon. Select Influxdb FROM raw prismacompute. Ideas, use the imagerepo as the filter, select the sum of any of the metrics collected." 
