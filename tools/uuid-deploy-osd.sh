#!/bin/bash

# osd 和 dev 数组
array_osd=(0 1)
array_dev=('sdf6' 'sdm6')

# 存储类型：filestore or bluestore
storage_type=filestore

# journal devices数组
array_journal=('sdf7' 'sdm7')	# for filestore only

# osd weight size, 参考值: 1T = 1.0
osd_weight=1.0

# 存放OSD挂载相关信息，临时fstab。可以选择存在当前文件夹下，也可以自定义路径
fstab_info=mount_info

###################################################################################################
###################################### 以下部分无需修改 ###########################################
###################################################################################################

# 得到数组中元素的数量
arrayNum=${#array_osd[@]}

# 创建osd目录
for dir_no in ${array_osd[@]}
do
    mkdir -p /var/lib/ceph/osd/ceph-$dir_no
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
#    mount -noatime /dev/${array_dev[$i]} /var/lib/ceph/osd/ceph-${array_osd[$i]}
    mount -noatime `blkid /dev/${array_dev[$i]} | awk '{print $NF}'` /var/lib/ceph/osd/ceph-${array_osd[$i]}  		# 通过partuuid来挂载磁盘
    osd_partuuid=`blkid /dev/${array_dev[$i]} | awk -F'[="]+' '{print $(NF-1)}'`
    echo "PARTUUID=$osd_partuuid  /var/lib/ceph/osd/ceph-${array_osd[$i]}  xfs  defaults,noatime  0  2" >> $fstab_info	# 将挂载信息写入启动关系文件
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
    if [ $storage_type == 'bluestore' ]
    then
        chown -R ceph:ceph /var/lib/ceph/osd/ceph-$osd_num
        chown -R ceph:ceph /var/log/ceph/
        systemctl start ceph-osd@$osd_num
    fi
done

# 将osd的 journal 软链到journal磁盘上 
if [ $storage_type == 'filestore' ]
then
    for ((j=0; j<arrayNum; j++))
    do
        partuuid=`blkid /dev/${array_journal[$j]} | awk -F'[="]+' '{print $(NF-1)}'`
        ln -s -f /dev/disk/by-partuuid/$partuuid /var/lib/ceph/osd/ceph-${array_osd[$j]}/journal	# 将journal通过partuuid软链到日志盘
#        ln -s -f /dev/${array_journal[$j]} /var/lib/ceph/osd/ceph-${array_osd[$j]}/journal
        ceph-osd -i ${array_osd[$j]} --mkjournal
        chown -R ceph:ceph /dev/${array_journal[$j]}
        chown -R ceph:ceph /var/lib/ceph/osd/ceph-${array_osd[$j]}
        chown -R ceph:ceph /var/log/ceph/
        systemctl start ceph-osd@${array_osd[$j]}
    done
fi
