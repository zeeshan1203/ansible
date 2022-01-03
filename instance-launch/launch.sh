#!/bin/bash

COMPONENT=$1

## -z validates the variable empty , true if it is empty.
if [ -z "${COMPONENT}" ]; then
  echo "Component Input is Needed"
  exit 1
fi

LID=lt-0c749183079899d8c                    ##ur aws launch template id
LVER=3                                      ##ur aws launch template latest version

## Validate If Instance is already there

DNS_UPDATE() {
  PRIVATEIP=$(aws --region us-east-1 ec2 describe-instances --filters "Name=tag:Name,Values=${COMPONENT}" | jq .Reservations[].Instances[].PrivateIpAddress | xargs -n1 | grep -v null)
  sed -e "s/COMPONENT/${COMPONENT}/" -e "s/IPADDRESS/${PRIVATEIP}/" record.json >/tmp/record.json
  aws route53 change-resource-record-sets --hosted-zone-id Z066850733D6NJMSTTFJ4 --change-batch file:///tmp/record.json | jq         ##ur route53 hosted zone id
}

INSTANCE_CREATE() {
  INSTANCE_STATE=$(aws --region us-east-1  ec2 describe-instances --filters "Name=tag:Name,Values=${COMPONENT}" | jq .Reservations[].Instances[].State.Name | xargs -n1 | grep -v terminated)
  if [ "${INSTANCE_STATE}" = "running" ]; then
    echo "${COMPONENT} Instance already exists!!"
    DNS_UPDATE
    return 0
  fi

  if [ "${INSTANCE_STATE}" = "stopped" ]; then
    echo "${COMPONENT} Instance already exists!!"
    return 0
  fi

  echo -n Instance ${COMPONENT} created - IPADDRESS is
  aws --region us-east-1 ec2 run-instances --launch-template LaunchTemplateId=${LID},Version=${LVER} --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=${COMPONENT}}]" | jq | grep PrivateIpAddress | xargs -n1
  sleep 10
  DNS_UPDATE
}

if [ "${1}" == "all" ]; then
  for component in frontend mongodb catalogue redis user cart mysql shipping rabbitmq payment; do
    COMPONENT=$component
    INSTANCE_CREATE
  done
else
  COMPONENT=$1
  INSTANCE_CREATE
fi

## export SSHPASS='DevOps321'
#echo $SSHPASS
#sshpass -e ssh ------
## for component in frontend mongodb catalogue redis user cart mysql shipping rabbitmq payment ; do
#   sshpass -e ssh $component.roboshop.internal "git clone https://github.com/zeeshan1203/shell-scripting.git &>/dev/null ; cd shell-scripting/roboshop ; git pull &>/dev/null ; sudo make $component"
#done
