#!/bin/bash


FILE_SERV_DIRECTORY="/srv"
source /etc/caddy/secrets.env

quick_check () {
  res=$?
  if [ $res -eq 0 ]; then
    echo "$1 request succeeded"
  else
    echo "$1 request failed error code: $res" >&2
    exit 1
  fi
}




AUTH_PAYLOAD=$(cat <<EOF
{"username": "$TL_ACCESSKEY", "password": "$TL_SECRETKEY"}
EOF
)



AUTH_RESPONSE=$(curl -H "content-type: application/json" \
                     -d "$AUTH_PAYLOAD" \
                     -X POST \
                     --url "$TL_CONSOLE/api/v1/authenticate")

quick_check "/api/v1/authenticate"


PRISMA_JWT=$(printf %s "$AUTH_RESPONSE" | jq -r '.token')


IMAGE_COUNT=$(curl -X GET \
                   -H "Authorization: Bearer $PRISMA_JWT" \
                   -H 'Content-Type: application/json' \
                   --url "$TL_CONSOLE/api/v1/containers/count")

quick_check "/api/v1/containers/containers"

IMAGE_API_LIMIT=50

IMAGE_VULNERABILITY_RESPONSE=$(for API_OFFSET in $(seq 0 ${IMAGE_API_LIMIT} ${IMAGE_COUNT}); do \
                               curl -H "Authorization: Bearer $PRISMA_JWT" \
                                    -H 'Content-Type: application/json' \
                                    -X GET \
                                    --url "$TL_CONSOLE/api/v1/images?limit=$IMAGE_API_LIMIT&offset=$API_OFFSET";
                               done)


quick_check "/api/v1/images"

printf %s "$IMAGE_VULNERABILITY_RESPONSE" | jq '[.[] | {image_repo: .tags[].repo, image_info: {imageTag: (.tags[0].repo + ":" + .tags[].tag), accountID: .cloudMetadata.accountID, labels: .cloudMetadata.labels?, complianceIssuesCritical: .complianceDistribution.critical, complianceIssuesHigh: .complianceDistribution.high, complianceIssuesMedium: .complianceDistribution.medium,  complianceIssuesLow: .complianceDistribution.low, clusters: .clusters?, scanTime: .scanTime, type: .type, vulnerabilitiesCount: .vulnerabilitiesCount, vulnerabilityRiskScore: .vulnerabilityRiskScore, vulnerablilitiesCritical: .vulnerabilityDistribution.critical, vulnerablilitiesHigh: .vulnerabilityDistribution.high, vulnerablilitiesMedium: .vulnerabilityDistribution.medium, vulnerablilitiesLow: .vulnerabilityDistribution.low}} | with_entries(select( .value != null))] | {data: .}' > "$FILE_SERV_DIRECTORY"/temp_vulnerability.json

cat "$FILE_SERV_DIRECTORY"/temp_vulnerability.json | jq -n '{data: [inputs.data] |add }' > "$FILE_SERV_DIRECTORY"/vulnerability.json
