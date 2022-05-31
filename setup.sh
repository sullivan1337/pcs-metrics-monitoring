#!/bin/bash




# Service Running Helper Function
running() {
    local url=${1:-http://localhost:80}
    local code=${2:-200}
    local status=$(curl --head --location --connect-timeout 5 --write-out %{http_code} --silent --output /dev/null ${url})
    [[ $status == ${code} ]]
}





# Docker Dependency Check
if ! docker info > /dev/null 2>&1; then
    echo "ERROR: docker is not available or not runnning."
    echo "This script requires docker, please install and try again."
    exit 1
fi
if ! docker-compose version > /dev/null 2>&1; then
    echo "ERROR: docker-compose is not available or not runnning."
    echo "This script requires docker-compose, please install and try again."
    exit 1
fi


TL_SECRETKEY_MATCH='^(\w|\d|\/|\+){27}\=$'
TL_ACCESSKEY_MATCH='^(\d|\w){8}\-(\d|\w){4}\-(\d|\w){4}\-(\d|\w){4}\-(\d|\w){12}$'
TL_CONSOLE_MATCH='^https\:\/\/(\w|\d|\.|\-|\_|\:|\/)+$'


tl-var-check () {
if [[ ! $TL_CONSOLE =~ $TL_CONSOLE_MATCH ]]
  then
    echo "$TL_CONSOLE is not a valid value for TL_CONSOLE. Please recopy, verify, and run again"
    exit 1
fi

if [[ ! $TL_SECRETKEY =~ $TL_SECRETKEY_MATCH ]]
  then
     echo "The Secret key is not valid. Please recopy, verify, and run again"
     exit 1
fi

if [[ ! $TL_ACCESSKEY =~ $TL_ACCESSKEY_MATCH ]]
  then
     echo "The Access Key is not valid. Please recopy, verify, and run again"
     exit 1
fi
}




ENV_FILE_PATH="./collector/secrets.env"

echo "enter your prisma access key id:"
read -r -s  TL_ACCESSKEY
echo "enter your prisma secret key id:"
read -r -s  TL_SECRETKEY
echo "enter your prisma cloud api url, like https://us-east1.cloud.twistlock.com/us-1-1111111"
read -r TL_CONSOLE

tl-var-check

printf '%s\n' "#!/bin/sh" > $ENV_FILE_PATH
printf '%s\n' "TL_CONSOLE=\"$TL_CONSOLE\"" >> $ENV_FILE_PATH
printf '%s\n' "TL_ACCESSKEY=\"$TL_ACCESSKEY\"" >> $ENV_FILE_PATH
printf '%s\n' "TL_SECRETKEY=\"$TL_SECRETKEY\"" >> $ENV_FILE_PATH

docker build -t collector:dev ./collector/.



# Build Docker
echo "Running Docker-Compose..."
docker-compose -f docker-compose.yml up -d
echo "-----------------------------------------"


# Set up Influx
echo "Waiting for InfluxDB to start..."
until running http://localhost:8086/ping 204 2>/dev/null; do
    printf '.'
    sleep 5
done
echo " up!"
sleep 2



echo "Setup InfluxDB Data for Prisma Cloud Compute Image Vulnerability"
docker exec -it influxdb influx -import -path=/var/lib/influxdb/influxdb.sql

sleep 2

echo "all done!"
