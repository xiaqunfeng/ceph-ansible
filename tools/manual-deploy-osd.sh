#!/bin/bash

# osd 和 dev 数组
array_osd=(0 1 2 3 4 5 6 7 8 9)
array_dev=('sdb1' 'sdc1' 'sdd1' 'sde1' 'sdg1' 'sdh1' 'sdi1' 'sdj1' 'sdk1' 'sdl1')

# 存储类型：filestore or bluestore
storage_type=bluestore

# journal devices数组
array_journal=('sdf1' 'sdf2' 'sdf3' 'sdf4' 'sdf5' 'sdm1' 'sdm2' 'sdm3' 'sdm4' 'sdm5')	# for filestore only

# osd weight size, 参考值: 1T = 1.0
osd_weight=1.0

###################################################################################################
###################################### 以下部分无需修改 ###########################################
###################################################################################################

# 得到数组中元素的数量
arrayNum=${#array_osd[@]}

# 创建osd目录
for dir_no in ${array_osd[@]}
do
    mkdir -p /var/lib/ceph/osd/ceph-$dir_no
# journal磁盘不需要创建一个目录来挂载它，避免文件夹写入，破坏journal
#    if [ $storage_type == 'filestore' ]
#    then
#        mkdir -p /mnt/journal/ceph-$dir_no	# if filestore, need journal
#    fi
done

# 格式化磁盘, 并修改磁盘权限
for dev_name in ${array_dev[@]}
do
    mkfs -t xfs -d name=/dev/$dev_name -f
    chown -R ceph:ceph /dev/$dev_name
done

# 格式化日志盘，并修改日志盘权限
if [ $storage_type == 'filestore' ]
then
    for journal_name in ${array_journal[@]}
    do
        mkfs -t xfs -d name=/dev/$journal_name -f
        chown -R ceph:ceph /dev/$journal_name
    done
fi

# 挂载磁盘
for ((i=0; i<arrayNum; i++))
do
    mount -noatime /dev/${array_dev[$i]} /var/lib/ceph/osd/ceph-${array_osd[$i]}
#    if [ $storage_type == 'filestore' ]
#    then
#        mount -noatime /dev/${array_journal[$i]} /mnt/journal/ceph-${array_osd[$i]}
#    fi
done

# 开始部署osd
host_name=`hostname`
ceph osd crush add-bucket $host_name host	# 把此节点加入CRUSH图
ceph osd crush move $host_name root=default	# 把此ceph节点放入 default 根下

for osd_num in ${array_osd[@]}
do
    ceph osd create
    ceph-osd -i $osd_num --mkfs --mkkey		# 初始化osd数据目录。此目录必须是空的，默认集群名称是ceph，若不是，需要 --cluster指定
    ceph auth add osd.$osd_num osd 'allow *' mon 'allow rwx' -i /var/lib/ceph/osd/ceph-$osd_num/keyring		# 注册此OSD的密钥
    ceph osd crush add osd.$osd_num $osd_weight host=$host_name		# weight set: 1T = 1.0
    ceph osd in $osd_num			# 将osd加入集群
#    if [ $storage_type == 'filestore' ]
#    then
#        chown -R ceph:ceph /mnt/journal/ceph-$osd_num
#    fi
    if [ $storage_type == 'bluestore' ]
    then
        chown -R ceph:ceph /var/lib/ceph/osd/ceph-$osd_num
        chown -R ceph:ceph /var/log/ceph/
        if test -f /etc/redhat-release ; then
            systemctl start ceph-osd@$osd_num
        else
            start ceph-osd id=$osd_num			# start osd for ubuntu
        if
    fi
done

# 将osd的 journal 软链到journal磁盘上 
if [ $storage_type == 'filestore' ]
then
    for ((j=0; j<arrayNum; j++))
    do
        ln -s -f /dev/${array_journal[$j]} /var/lib/ceph/osd/ceph-${array_osd[$j]}/journal
        ceph-osd -i ${array_osd[$j]} --mkjournal
        chown -R ceph:ceph /dev/${array_journal[$j]}
        chown -R ceph:ceph /var/lib/ceph/osd/ceph-${array_osd[$j]}
        chown -R ceph:ceph /var/log/ceph/
        if test -f /etc/redhat-release ; then
            systemctl start ceph-osd@${array_osd[$j]}
        else
            start ceph-osd id=${array_osd[$j]}
        fi
    done
fi
