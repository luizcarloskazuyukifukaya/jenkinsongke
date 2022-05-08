#!/bin/bash
echo "This script will setup environmnet for your CI/CD environment with Jenkins"

# Set GCP Project and region
PROJECT_ID=luiz-devops-jenkins
REGION=us-central1
ZONE=us-central1-f
ZONE1=us-central1-f
ZONE2=us-central1-b
JENKINS_VPC=jenkinsvpc
JENKINS_FW=jenkinsfw
JENKINS_CLUSTER=jenkinscluster

gcloud auth login --no-browser

echo "Set default projet:$PROJECT_ID and zone:$ZONE."

gcloud config set project  $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

#Create Virtual Private Cloud for Jenkins cluster
gcloud compute networks create $JENKINS_VPC --subnet-mode auto
gcloud compute firewall-rules create $JENKINS_FW --network $JENKINS_VPC --allow tcp:22,tcp:80,tcp:8080,tcp:50000,tcp:443,icmp --source-ranges 0.0.0.0/0

echo "Enabling Kubernets API"
gcloud services enable container.googleapis.com

echo "K8S Cluster:$JENKINS_CLUSTER"
gcloud container clusters create $JENKINS_CLUSTER \
--network $JENKINS_VPC \
--zone $ZONE \
--scopes "https://www.googleapis.com/auth/projecthosting,storage-rw"

# Create Kubenets cluster
echo "Creating namespace for Kubernets..."
kubectl get namespace

kubectl create -f ./jenkinsnamespace.yaml
echo "Kubernets namespace created."
kubectl get namespace

#NOTE: The first time, if Kubernetes API not configured, the creation fails!!
# https://console.cloud.google.com/apis/api/container
# gcloud services enable container.googleapis.com ADDED on 5/6/2022

# Get credential of the cluster (to use kubectl)
gcloud container clusters get-credentials $JENKINS_CLUSTER

# Display cluster information
kubectl get nodes
kubectl get services

# Jenkins setup
PASSWD=`openssl rand -base64 15`
echo "Generated password for kubernets:$PASSWD"

echo "--argumentsRealm.passwd.jenkins=$PASSWD --argumentsRealm.roles.jenkins=admin" > options
echo "option file generated with the password..."
echo "Jenkins login credential:"
echo "    username:jenkins"
echo "    password:$PASSWD"

kubectl create secret generic jenkins --from-file=options --namespace=jenkinsgcp
echo "secret in Kubernets created."

# Add administrative roles to manage the Kubernets cluster
echo "Adding administrative role to Kubernets cluster..."
kubectl create clusterrolebinding cluster-admin-bining \
 --clusterrole=cluster-admin \
 --user=$(gcloud config get-value account)

# Create volume for jenkins
echo "!!!!!!!!! ERROR HERE AS THE TAR.GZ FILE NO LONGER EXIST !!!!!!"
echo "Creating disk image for Jenkins cluster"
gcloud compute images create jenkins-home-image \
 --source-uri https://storage.googleapis.com/solutions-public-assets/jenkins-cd/jenkins-home-v3.tar.gz

echo "!!!!!!!!! ERROR HERE AS THE TAR.GZ FILE NO LONGER EXIST !!!!!!"
# Create disk from image (jenkins-home-image)
echo "Creating disk volume based on the disk image just created..."
gcloud beta compute disks create jenkins-home \
--project=$PROJECT_ID \
--type=pd-standard \
--size=500GB \
--zone=$ZONE \
--image=jenkins-home-image \
--image-project=$PROJECT_ID \
--physical-block-size=4096
echo "disk volume created."

# Deploy Kubernets deployment and the service
echo "Start Kubernets deployment and services ..."
kubectl apply -f k8s/

# Check pods and services
echo "Checking the status ..."
kubectl get pods --namespace jenkinsgcp
kubectl get services --namespace jenkinsgcp

# TLS Certificate (self-signed)
echo "Generating Certificate..."
openssl req -x509 -nodes -days 365 -newkey rsa:2048 -keyout tls.key -out tls.crt -subj "/CN=jenkins/O=jenkins"
echo "OpenSSL Certificate generated."
cat tls.key
cat tls.crt

kubectl create secret generic tls --from-file=tls.crt --from-file=tls.key --namespace jenkinsgcp

# Exposing the service
echo "Exposing the service..."
kubectl apply -f ingress/

# Check ingress
echo "Checking the status ..."
kubectl get ingress --namespace jenkinsgcp
#kubectl describe ingress jenkins --namespace jenkinsgcp
echo "(NOTE) To access the Jenkins server portal, open the browser and put the ADDRESS (ip address of the server)."
echo "(NOTE) Jenkins server administrator credential is as the following:"
echo -e "\e[31musername: jenkins\e[0m"
echo -e "\e[31mpassword: $PASSWD\e[0m (You can find the information on the option file as well...)"
cat options

echo "You may need to wait a while and check the completion of the ingression creation."
echo "You can check by executing <kubectl get ingress --namespace jenkinsgcp>."

# Completion message here
echo "completed!!"
