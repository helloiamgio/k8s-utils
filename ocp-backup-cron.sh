#!/bin/bash
/bin/echo [$(date +"%F %T")] Starting OCP1-par Backup... &>> /var/log/ocp1-backup.log
/bin/ssh -i /root/.ssh/ocp-parallelo core@10.215.87.187 '/bin/sudo /usr/local/bin/cluster-backup.sh /home/core/backup && /bin/sudo /bin/find /home/core/backup -mtime +5 -delete && /bin/sudo /bin/chown -vR core:core /home/core/backup'
/bin/rsync -av --delete -e "/bin/ssh -i /root/.ssh/ocp-parallelo" core@10.215.87.187:/home/core/backup /root/backup-etcd/ocp1-par &>> /var/log/ocp1-backup.log
/bin/echo [$(date +"%F %T")] Terminated OCP Backup. &>> /var/log/ocp1-backup.log
