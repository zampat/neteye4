#!/usr/bin/env bash

backup_date="$(date +%Y%m%d-%H%M%S)"
datadir=/neteye/shared/mysql/data
backup_base=/data/backup/mariabackup_tmp
target_dir=${backup_base}/mariabackup_${backup_date}
tmpdir=${backup_base}/tmp
dumpdir=${backup_base}/mariadump_${backup_date}


if [ -d "${backup_base}" ]; then
    mkdir -p "${tmpdir}" "${target_dir}" "${dumpdir}" || {
        echo "ERROR: Failed to create backup directories."
        exit 1
    }
else
    echo "ERROR: backup base directory not set or not exists"
    exit 1
fi


#for DB in $(mysql -sN -e "show databases;"); do
#    echo "Dumping database ${DB}"
#    mysqldump --single-transaction "$DB" > "${dumpdir}/${DB}.sql"
#    if [ $? -ne 0 ]; then
#        echo -e "\nERROR: Failed to dump database ${DB}\n" ;sleep 5
#        # exit 1
#    else
#        echo "Dumping database ${DB} is done"
#    fi
#done

soft_fd=$(ulimit -Sn)
if (( $soft_fd < 4096 )); then
    ulimit -Sn 4096
fi

mariabackup --backup --datadir="${datadir}" \
            --target-dir="${target_dir}" \
            --tmpdir="${tmpdir}"
if [ $? -ne 0 ]; then
    echo "ERROR: MariaBackup backup failed."
    ulimit -Sn $soft_fd
    exit 1
fi

mariabackup --prepare --export --target-dir="${target_dir}"
if [ $? -ne 0 ]; then
    echo "ERROR: MariaBackup prepare/export failed."
    ulimit -Sn $soft_fd
    exit 1
fi

ulimit -Sn $soft_fd

exit 0
