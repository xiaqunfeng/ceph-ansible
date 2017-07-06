# README
该项目是在原有ceph-ansible项目基础上根据自己的需要进行的一些修改。
## 原项目地址和版本
github: https://github.com/ceph/ceph-ansible
release: 2.2.1

安装完后版本信息：
```
# ansible --version
ansible 2.3.0.0
  config file = /etc/ansible/ansible.cfg
  configured module search path = Default w/o overrides
  python version = 2.7.5 (default, Sep 15 2016, 22:37:39) [GCC 4.8.5 20150623 (Red Hat 4.8.5-4)]
```
原先的README.md改名为README-origin.md

## 修改
### ceph-osd role
在原有基础上进行了少量修改，使之可以更好的支持分区部署osd。

### install-ansible.sh
根据系统环境自动安装`lsb_release`，不必手动再安装，并校验是否安装完成。

## 新增roles
### 1、ceph-install
当选择 `ceph_custom` 方式安装的时候才使用该role。在这里用于离线安装，在内网的某一台机器上搭建一个源站，然后通过yum的方式安装ceph。group/all.yml中需要开启的配置如下：
```
ceph_origin: 'upstream'
...
ceph_custom: true # use custom ceph repository
ceph_custom_repo: http://172.20.2.158/ceph-kraken-repos
...
monitor_interface: eth0
...
public_network: 172.20.2.0/24

```
其中`http://172.20.2.158/ceph-kraken-repos` 为我自己配置的内网仓库。

>只针对 custom 模式下使用，如果是非`custom` 模式的话在site.yml 中将该role对应的task注释掉

### 2、ceph-purge
清除整个集群的信息，包括以下几件事情
- 停止所有ceph相关进程
- umount 所有osd挂载的磁盘
- 删除 /etc/ceph/ 下所有文件
- 删除 /var/lib/ceph/ 下所有文件

**新增变量**: `ceph_pkg_purge`，默认为 `false`。可在group_vars/all.yml 中开启。
**功能**：当开启时，在purge ceph集群数据完成后，会purge 掉 ceph package，以及ceph 安装版本所对应的相关依赖包，以便环境在下次安装不同版本的 ceph 时不会有问题。

>该变量当前只针对 centos 系统实现

**使用方法**：
当前目录下单独提供了一个yml文件 `ceph-purge.yml` 可供直接调用

### 3、firewalld
关闭防火墙和selinux，在ceph部署前就执行此操作，防止在部署过程中因为该步骤未操作引发的一些问题。
默认在site.yml中开启

### 4、parted-create
给磁盘分区，用于ceph的部署
TODO

### 5、parted-rm
删除所有磁盘的分区
TODO
