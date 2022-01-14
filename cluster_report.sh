#!/bin/bash

cluster_name=$(qq cluster_conf|jq -r '.cluster_name')
echo -e "\e[4mCluster Name: \t $cluster_name\e[0m"

echo -e "Version:\t $(qq version |jq -r '.revision_id'|awk '{print $3}')"

restriper_status=$(qq restriper_status | jq -r '.status')
if [ "$restriper_status" == "NOT_RUNNING" ]
then
	echo 'No running rebuild activity'
else
	echo ""
	echo -e '\033[0;33mThere is an ongoing rebuild activity\033[0m'
	echo "Estimated Time: $(date -d @$(qq restriper_status | jq -r '.estimated_seconds_left') -u +%H:%M:%S)"
	echo "$(qq restriper_status | jq -r '.percentage_complete') completed"
fi

disk_health=$(qq cluster_slots|jq -r '.[]|select (.state != "healthy")')
if [ -z "$disk_health" ]
then 
	echo -e 'Cluster Disks Health: \t \033[0;32mOK\033[0m'
else
	echo ""
	echo -e '\033[0;31mDisk Error(s): \t \033[0m'
	qq cluster_slots|jq -r '["Node","|Slot","|Type"], ["----","----","----"], (.[]|select (.state != "healthy")|[.node_id, .slot, .slot_type]) | @tsv'
fi

echo ""
echo -e "\e[4mCapacity Consumptions:\e[0m"
a=$(date +%s);sleep 1; b=$(date +%s); 
echo -en "Total Usable: \t"; qq capacity_history_get --begin-time $a --end-time $b --interval hourly|jq -r '.[]|.total_usable'|numfmt --to=si --suffix=B --padding=7

echo -en "Data Used: \t"; qq capacity_history_get --begin-time $a --end-time $b --interval hourly|jq -r '.[]|.data_used'|numfmt --to=si --suffix=B --padding=7

echo -en "Metadata Used: \t"; qq capacity_history_get --begin-time $a --end-time $b --interval hourly|jq -r '.[]|.metadata_used'|numfmt --to=si --suffix=B --padding=7

echo -en "Snapshot Used: \t"; qq capacity_history_get --begin-time $a --end-time $b --interval hourly|jq -r '.[]|.snapshot_used'|numfmt --to=si --suffix=B --padding=7

echo -en "No. of Files: \t";qq fs_read_dir_aggregates --path "/" --max-depth 0|jq -r '.total_files'

echo -en "No. of Dirs: \t";qq fs_read_dir_aggregates --path "/" --max-depth 0|jq -r '.total_directories'

echo ""
echo -e "\e[4mConnections:\e[0m"
qq network_list_connections |jq -r --arg cluster_name "$cluster_name-" '["Node","|Connections"],["----","-----------"],(.[]|[$cluster_name + (.id|tostring), (.connections|length)])| @tsv'

echo ""
echo -e "\e[4mQuota Utilizations:\e[0m"
qq quota_list_quotas --page-size 1000|jq -r '.quotas|.[]|[.path, ((.capacity_usage|tonumber) / (.limit|tonumber) * 100 |tostring) + "%"]| @tsv'

echo ""
echo -e "\e[4mReplication Relationship Statuses:\e[0m"
qq replication_list_source_relationship_statuses |jq -r '.[]|[(.source_cluster_name + "(" + .source_root_path +")"),">>",(.target_cluster_name + "(" + .target_root_path + ")"), .error_from_last_job]|@tsv'
qq replication_list_target_relationship_statuses |jq -r '.[]|[(.source_cluster_name + "(" + .source_root_path +")"),">>",(.target_cluster_name + "(" + .target_root_path + ")"), .error_from_last_job]|@tsv'

echo ""
echo -e "\e[4mCloud Monitoring:\e[0m"
qq monitoring_status_get | jq -r --arg cluster_name "$cluster_name" '["Node","|File Upload", "|Monitoring", "|VPN Connections"], ["------","------------","-----------","----------------"],(.[]|[$cluster_name + (.node_id|tostring), .file_upload, .monitoring, .vpn_connection])| @tsv'
