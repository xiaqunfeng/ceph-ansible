# coding: utf8
# how to color: http://www.cnblogs.com/ping-y/p/5897018.html

import sys, commands, time

def undo(rbd_info):
    if not rbd_info or len(rbd_info['undo_list']) == 0 : return
    undo_list = rbd_info['undo_list']
    undo_list.reverse()
    for x in undo_list:
        if x == 'mapped':
            cmdstr = 'rbd unmap %s' % rbd_info['map_device']
            success_or_exit(cmdstr, 'unmap the device')
        elif x == 'created':
            cmdstr = 'rbd rm %s' % rbd_info['rbd_name']
            success_or_exit(cmdstr, 'rm the device')
        else:
            assert 0

def success_or_exit(cmdstr, desc, rbd_info = None):
    status, output = commands.getstatusoutput(cmdstr)
    if status != 0:
        print '[\033[1;31mFAIL\033[0m] cmd=\'%s\', desc=\'%s\'' % (cmdstr, desc)
        if output:
            print 'message as below:\n%s' % (output.strip())
        undo(rbd_info)
        sys.exit(1)
    else:
        #print '[PASS] cmd=\'%s\', desc=\'%s\'' % (cmdstr, desc)
        return output

if __name__ == '__main__':
    if len(sys.argv) != 2:
        print 'EXAMPLE:'
        print 'python %s ${pool_name}' % sys.argv[0]
        sys.exit(1)
    rbd_info = {}
    rbd_name = '%s/fstype_test_device_%d' % (sys.argv[1], int(time.time()))
    rbd_info['rbd_name'] = rbd_name
    rbd_info['undo_list'] = []

    # -0- 判断随机生成的块设备是否冲突
    cmdstr = 'rbd info %s' % rbd_name
    status, output = commands.getstatusoutput(cmdstr)
    if status == 0:
        print '[\033[1;31mFAIL\033[0m] cmd=\'%s\', desc=\'device exists, try again\'' % cmdstr
        sys.exit(1)

    # -1- 创建一个之前不存在的设备(${pool_name})，默认大小1G
    cmdstr = 'rbd create %s --size=1024M --image-feature layering' % rbd_name
    success_or_exit(cmdstr, 'create new rbd device', rbd_info)
    rbd_info['undo_list'].append('created')

    # -2- 执行map操作
    cmdstr = 'rbd map %s' % rbd_name
    dev_name = success_or_exit(cmdstr, 'map rbd device', rbd_info)
    rbd_info['undo_list'].append('mapped')
    rbd_info['map_device'] = dev_name.strip()

    # -3- 执行文件系统格式化
    cmdstr = 'mkfs -t xfs %s' % dev_name.strip()
    success_or_exit(cmdstr, 'format the device with xfs')

    # -4- unmap解除绑定
    cmdstr = 'rbd unmap %s' % rbd_info['map_device']
    success_or_exit(cmdstr, 'unmap the device')
    rbd_info['undo_list'].pop(-1)

    # -5- 重新map
    cmdstr = 'rbd map %s' % rbd_name
    dev_name = success_or_exit(cmdstr, 'map rbd device', rbd_info)
    rbd_info['undo_list'].append('mapped')
    rbd_info['map_device'] = dev_name.strip()

    # -6- 使用lsblk判断是否能得到文件系统类型
    cmdstr = 'lsblk -nd -o FSTYPE %s' % dev_name.strip()
    fstype = success_or_exit(cmdstr, 'get the device fstype')
    if fstype != 'xfs':
        status, output = commands.getstatusoutput('cat /run/udev/data/b251\:0')
        print '[\033[1;31mFAIL\033[0m] cmd=\'%s\', desc=\'get device fstype\'' % (cmdstr)
    else:
        print '[\033[1;32mPASS\033[0m] get device fstype okay.'

    # -7- 清理
    undo(rbd_info)

    # -8- 确认清理成功
    cmdstr = 'rbd info %s' % rbd_name
    status, output = commands.getstatusoutput(cmdstr)
    if status == 0:
        print '[\033[1;31mFAIL\033[0m] rm the device %s, need manually remove' % rbd_name
        sys.exit(1)
