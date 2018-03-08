import commands, sys, json

cmd = 'ceph osd tree -f json'
status, output = commands.getstatusoutput(cmd)
jd = json.loads(output)
#print jd['nodes']
osd_dict = {}
for node in jd['nodes']:
    if node.has_key('crush_weight'):
        #print '%s %.3f' % (node['name'], node['crush_weight'])
        osd_dict[node['name']] = node['crush_weight']
if len(sys.argv) >= 2:
    key = 'osd.%s' % str(int(sys.argv[1]))
    if osd_dict.has_key(key):
        print '%s\'s weight %.3f' % (key, osd_dict[key])
    else:
        print 'osd.%s not exists.' % sys.argv[1]
        sys.exit(1)
    if len(sys.argv) == 3:
        plus_weight = float(sys.argv[2])
        cmd = 'ceph osd crush reweight %s %.3f' % (key, osd_dict[key]+plus_weight)
        #print cmd
        status, output = commands.getstatusoutput(cmd)
        if status == 0:
            print '[OK]', cmd
        else:
            print '[FAIL]', cmd
#print json.dumps(jd, indent=4)
