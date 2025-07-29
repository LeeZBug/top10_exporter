#!/bin/bash
function check_execution_result(){
if [[ ! -z $RETVAL ]]; then
unset RETVAL
fi
RETVAL=$?
if [[ $RETVAL -ne 0 ]]; then
echo execution failed!
exit $RETVAL
else
echo execution successfully!
fi
unset RETVAL
}

echo "- - -" >/sys/class/scsi_host/host0/scan
echo "- - -" >/sys/class/scsi_host/host1/scan
echo "- - -" >/sys/class/scsi_host/host2/scan
#检测新磁盘
function check_new_disk(){
DISK_NUM=$(lsblk --all |grep disk|grep -v sda|wc -l)
FORMAT_DISK=$(blkid |grep /dev/sd|grep -v sda|wc -l)
if [ $DISK_NUM == $FORMAT_DISK ];then
echo "no new disk,exit"
exit 0
else
ONLINE_SCSI_DISK_NEWADD=$(lsblk --all | grep disk | grep -v fd | awk '{print $1}'|tr ' ' '\n'|sort -rh|sed -n '1p')
echo New Added SCSI Disk: $ONLINE_SCSI_DISK_NEWADD
ONLINE_SCSI_DISK_NEWADD_FILENAME="/dev/"$ONLINE_SCSI_DISK_NEWADD
NEW_LVM_OPERATION_DISK_FILENAME=$ONLINE_SCSI_DISK_NEWADD_FILENAME
pvcreate $NEW_LVM_OPERATION_DISK_FILENAME >/dev/null 2>&1
creat_extend_lvm
fi
}
#判断操作系统版本
function judge_os_version(){
os_version=`cat /etc/redhat-release|sed -r 's/.* ([0-9]+)\..*/\1/'`
if [ $os_version == 5 ];then
	mkfs.ext3 /dev/$VG_Name/$LV_Name >/dev/null 2>&1
	echo "$LV_Name has formated ext3"
	echo "/dev/$VG_Name/$LV_Name $mountPoint ext3 defaults 0 0" >> /etc/fstab
elif [ $os_version == 6 ];then
	mkfs.ext4 /dev/$VG_Name/$LV_Name >/dev/null 2>&1
	echo "$LV_Name has formated xfs"
	echo "/dev/$VG_Name/$LV_Name $mountPoint ext4 defaults 0 0" >> /etc/fstab
else
	mkfs.xfs /dev/$VG_Name/$LV_Name >/dev/null 2>&1
    echo "$LV_Name has formated xfs"
    echo "/dev/$VG_Name/$LV_Name $mountPoint xfs defaults 0 0" >> /etc/fstab
fi
}
#判断文件系统类型
function judge_lv_type(){
old_lv_name=$(cat /etc/fstab |grep  -w $mountPoint |grep -v fd |awk '{print $1}')
lv_type=$(df -Th|grep -w $mountPoint|awk '{print $2}' | grep -Ev 'overlay')
echo "disk type: $lv_type"
if [ "$lv_type" == 'xfs' ];then
    echo "xfs type disk extend..."
	xfs_growfs $old_lv_name >/dev/null 2>&1
else
    echo "ext type disk extend..."
	resize2fs $old_lv_name >/dev/null 2>&1
fi
}

#如果挂载点为新，则新建VG，LV;如果挂载点存在，则扩容LV
function creat_extend_lvm(){
if [ ! -d $mountPoint ];then
echo "the mountPoint is not been,so created new vg lvm"
mkdir -p $mountPoint
check_execution_result
VG_Name=VG${mountPoint#*/}$RANDOM
LV_Name=LV${mountPoint#*/}$RANDOM
vgcreate $VG_Name $NEW_LVM_OPERATION_DISK_FILENAME >/dev/null 2>&1
lvcreate $VG_Name  -l 100%FREE --name /dev/$VG_Name/$LV_Name >/dev/null 2>&1
echo "new $VG_Name and $LV_Name has created"
judge_os_version
check_execution_result
else
echo "the mountPoint been ,so we extend vg lvm"
old_vg_name=$(cat /etc/fstab |grep -w $mountPoint  |grep -v fd |awk '{print $1}'|awk -F / '{print $3}')
if [ ! $old_vg_name ];then
echo "old_vg_name is null, delete mountPoint"
check_execution_result
VG_Name=VG${mountPoint#*/}$RANDOM
LV_Name=LV${mountPoint#*/}$RANDOM
vgcreate $VG_Name $NEW_LVM_OPERATION_DISK_FILENAME >/dev/null 2>&1
lvcreate $VG_Name  -l 100%FREE --name /dev/$VG_Name/$LV_Name >/dev/null 2>&1
echo "new $VG_Name and $LV_Name has created"
judge_os_version
check_execution_result
else
echo "old_vg_name is not null, so we extend it"
lv_path=$(cat /etc/fstab |grep -w $mountPoint |awk '{print $1}')
old_Lv_name=$(echo ${lv_path##*-})
if [ "$old_vg_name" == "mapper" ];then
   old_vg_name=$(lvs |grep -w $old_Lv_name |awk '{print $2}')
fi
vgextend $old_vg_name $NEW_LVM_OPERATION_DISK_FILENAME >/dev/null 2>&1
old_lv_name=$(cat /etc/fstab |grep  -w $mountPoint  |grep -v fd |awk '{print $1}')
lvextend -l +100%FREE $old_lv_name >/dev/null 2>&1
judge_lv_type
fi
fi
mount -a
}
#挂载点名称
mountPoint=${{mountPoint}}
check_new_disk