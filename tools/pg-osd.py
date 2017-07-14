#!/usr/bin/env  python
import sys 
import os
import json
cmd = '''
#ceph pg dump | awk ' /^PG_STAT/ { col=1; while($col!="UP") {col++}; col++ } /^[0-9a-f]+\.[0-9a-f]+/ {print $1,$col}'
ceph pg dump | awk ' /^pg_stat/ { col=1; while($col!="up") {col++}; col++ } /^[0-9a-f]+\.[0-9a-f]+/ {print $1,$col}'
'''
body = os.popen(cmd).read()
SUM = {}
for line in  body.split('\n'):
       if not line.strip():
        continue
       SUM[line.split()[0]] = json.loads(line.split()[1])
pool = set()
for  key in  SUM:
      pool.add(key.split('.')[0])
mapping = {}
for number in pool:
      for k,v in SUM.items():
        if k.split('.')[0] == number:
               if number in mapping:
                   mapping[number] += v
               else:
                   mapping[number] = v
MSG = """%(pool)-6s: %(pools)s | SUM
%(line)s
%(dy)s
%(line)s
%(sun)-6s: %(end)s |"""
pools = " ".join(['%(a)-6s' % {"a": x} for x in sorted(list(mapping))])
line = len(pools) + 20
MA = {}
OSD = []
for p in mapping:
    osd = sorted(list(set(mapping[p])))
    OSD += osd
    count = sum([mapping[p].count(x) for x in osd])
    osds = {}
    for x in osd:
        osds[x] = mapping[p].count(x)
    MA[p] = {"osd": osds, "count": count}
MA = sorted(MA.items(), key=lambda x:x[0])
OSD = sorted(list(set(OSD)))
DY = ""
for osd in OSD:
    count = sum([x[1]["osd"].get(osd,0) for x in MA])
    w = ["%(x)-6s" % {"x": x[1]["osd"].get(osd,0)} for x in MA]
    #print w
    w.append("| %(x)-6s" % {"x": count})
    DY += 'osd.%(osd)-3s %(osds)s\n' % {"osd": osd, "osds": " ".join(w)}
SUM = " ".join(["%(x)-6s" % {"x": x[1]["count"]} for x in MA])
msg = {"pool": "pool", "pools": pools, "line": "-" * line, "dy": DY, "end": SUM, "sun": "SUM"}
print MSG % msg
