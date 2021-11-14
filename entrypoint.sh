#!/bin/bash -x

CLUSTER=$(curl -sS "${ECS_CONTAINER_METADATA_URI_V4}"/task | jq -r '.Cluster')
TASK_ARN=$(curl -sS "${ECS_CONTAINER_METADATA_URI_V4}"/task | jq -r '.TaskARN')
TASK_DETAILS=$(aws ecs describe-tasks --cluster "${CLUSTER}" --task "${TASK_ARN}" --query 'tasks[0].attachments[0].details')
ENI=$(echo $TASK_DETAILS | jq -r '.[] | select(.name=="networkInterfaceId").value')
PUBLIC_IP=$(aws ec2 describe-network-interfaces --network-interface-ids "${ENI}" --query 'NetworkInterfaces[0].Association.PublicIp' --output text)
PRIVATE_IP=$(aws ec2 describe-network-interfaces --network-interface-ids "${ENI}" --query 'NetworkInterfaces[0].PrivateIpAddress' --output text)

if [ "${USE_PRIVATE_IP}" == "true" ]
then
  IP="${PRIVATE_IP}"
else
  IP="${PUBLIC_IP}"
fi

if [ -z $IP ]
then
  echo "IP address could not be detected."
  exit 1
fi

if [ -z $DNS_NAME ]
then
  echo "DNS_NAME variable is unset."
  exit 1
fi

if [ -z $HOSTED_ZONE_ID ]
then
  echo "HOSTED_ZONE_ID variable is unset."
  exit 1
fi

TTL="${TTL:=300}"

cat change-resource-record-sets-skeleton.json | jq \
--arg DNS_NAME "$DNS_NAME" \
--arg IP "$IP" \
--arg TTL "$TTL" \
'.Changes[0].ResourceRecordSet.Name = $DNS_NAME |
 .Changes[0].ResourceRecordSet.TTL = $TTL |
 .Changes[0].ResourceRecordSet.ResourceRecords[0].Value = $IP' \
> change-resource-record-sets.json

aws route53 change-resource-record-sets \
--hosted-zone-id $HOSTED_ZONE_ID \
--change-batch file://change-resource-record-sets.json
