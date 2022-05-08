#!/bin/bash

echo "Shuting down the CICD environment, which has been created by setup.sh"

PROJECT_ID=luiz-devops-jenkins
REGION=us-central1
ZONE=us-central1-f
JENKINS_VPC=jenkinsvpc
JENKINS_FW=jenkinsfw
JENKINS_CLUSTER=jenkinscluster

# authenticate
gcloud auth login
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Delete the cluster
gcloud container clusters delete --quiet $JENKINS_CLUSTER

# Delete firewall rules
echo "All firewall rules related to $JENKINS_VPC"
gcloud compute firewall-rules list \
  --format="table(Name)" \
  --filter=$JENKINS_VPC | \
  awk '{if ($1 != "NAME") print $1}'

#gcloud compute firewall-rules delete --quiet $JENKINS_FW
gcloud compute firewall-rules list \
  --format="table(Name)" \
  --filter=$JENKINS_VPC | \
  awk \
  '{if ($1 != "NAME") system("gcloud compute firewall-rules delete --quiet "$1)}'

# Delete network
# NOTE: Firewall rules must be delete first, before deleting the VPC.
gcloud compute networks delete --quiet $JENKINS_VPC

echo "Completed!!!"
