#!/bin/bash

ceph osd pool set rbd pg_num $1
ceph osd pool set rbd pgp_num $1
