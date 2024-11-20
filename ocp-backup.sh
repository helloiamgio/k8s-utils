#!/bin/sh
# This scripts backups following Openshift entities:
# - etcd data --> https://docs.openshift.com/container-platform/3.11/day_two_guide/environment_backup.html#backing-up-etcd_environment-backup
# - all active projects --> https://docs.openshift.com/container-platform/3.11/day_two_guide/environment_backup.html#backing-up-project_environment-backup
# Then it creates a zipped file, moves file into remote share folder and deletes oldest backup files while keeping defined retention.

# Define vars
ENV=prod
BCK_RETENTION=3
HOME_BCKDIR=/root/ocp-backup
REMOTE_BCKDIR=/ocp/backup/$ENV
DATE=$(date +%Y%m%d.%H)
BCKDIR=$HOME_BCKDIR/$DATE

echo -e "\nSTART OCP backup: $(date)"
# Create temporary backup dir
mkdir -p $BCKDIR
echo "Temporary OCP backup dir: $BCKDIR"

echo "ETCD data backup"
# Make a snapshot of the etcd node
source /etc/profile.d/etcdctl.sh
mkdir -p /var/lib/etcd/backup/etcd-$DATE
etcdctl3 snapshot save /var/lib/etcd/backup/etcd-$DATE/db
mkdir -p $BCKDIR/etcd/
mv /var/lib/etcd/backup/etcd-$DATE/db $BCKDIR/etcd/
rm -rf /var/lib/etcd/backup/etcd-$DATE

echo "Backup of all active projects on OCP"
mkdir -p $BCKDIR/projects
cd $BCKDIR/projects
oc login -u system:admin
for prj in $(oc get projects --no-headers | grep Active | awk '{print $1}')
#for prj in default openshift-logging
do
  echo "Backup objects for project: $prj"
  mkdir $prj
  cd $prj
  oc get -n $prj -o yaml --export all > $prj.yaml
  for object in rolebindings serviceaccounts secrets imagestreamtags cm egressnetworkpolicies rolebindingrestrictions limitranges resourcequotas pvc templates cronjobs statefulsets hpa deployments replicasets poddisruptionbudget endpoints
  do
    oc get -n $prj -o yaml --export $object > $object.yaml
  done
  cd ..
done

# Create tar.gz zipped file and delete source dir
echo "Create zipped file ocp-backup-$DATE.tar.gz in $REMOTE_BCKDIR"
cd $HOME_BCKDIR
tar -pcvzf $ENV-ocp-backup-$DATE.tar.gz $DATE
mv $ENV-ocp-backup-$DATE.tar.gz $REMOTE_BCKDIR
echo "Delete temporary backup dir $BCKDIR"
rm -r $BCKDIR

# Delete oldest backup files while keeping defined retention
BCK_FILE_COUNT=$(ls $REMOTE_BCKDIR/*.tar.gz | wc -l)
if [ $BCK_FILE_COUNT -gt $BCK_RETENTION ]; then
        FILES_TO_DELETE=$(ls -t $REMOTE_BCKDIR/*.tar.gz | awk "NR>$BCK_RETENTION")
        rm $FILES_TO_DELETE
        echo -e "Oldest backup file deleted:\n$FILES_TO_DELETE"
fi
echo "END OCP backup: $(date)"
