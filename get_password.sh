POD_NAME=$(kubectl get pods -n jenkinsgcp --no-headers -o custom-columns=":metadata.name")
echo "POD name is "$POD_NAME

# Check Pod log
#kubectl logs $POD_NAME -n jenkinsgcp

# Extract directly from the file prepared by Jenkins
PASSWD=$(kubectl exec $POD_NAME -n jenkinsgcp -- cat /var/jenkins_home/secrets/initialAdminPassword)
echo "Jenkins Admin Password:"$PASSWD
