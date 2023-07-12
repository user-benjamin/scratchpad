#!/bin/bash

#set instanceid as variable to be used below
instanceid=`aws autoscaling describe-auto-scaling-instances --profile #profile# --region #region --query "AutoScalingInstances[?AutoScalingGroupName=='#asgName#'][].{InstanceId:InstanceId}" | awk -F'"' '{print $4}'`
#set availability zone to be used below
az=`aws autoscaling describe-auto-scaling-instances --profile #profile# --region #region --query "AutoScalingInstances[?AutoScalingGroupName=='#asgName#'][].{AvailabilityZone:AvailabilityZone}" | awk -F'"' '{print $4}'`
#instanceid and az are consumed here, please remember to update the path to the key
aws ec2-instance-connect send-ssh-public-key --region us-east-1 --instance-id $instanceid --availability-zone $az --instance-os-user ec2-user --ssh-public-key file://~/.ssh/id_rsa.pub  > /dev/null
#launch ssh
ssh -o StrictHostKeyChecking=no -i ~/.ssh/id_rsa ec2-user@#hostname#
