minUtilCPU = 0.8
maxUtilCPU = 2.5 #take care of dual cores
minUtilMem = 0.4
maxUtilMem = 1.5
noMigH = [] #hack : if u simply write noMigH = 0, then u have to make them accessible thru some keywords like global etc...If u make list, globally accessible!!
noMigFF = []
underUtil = dict()
overUtil = dict()
normalUtil = dict()
vmUtil = dict()
hostUtil = dict()
actualvmlevel

"""
Shikhar
Variant of First fit (VFF)

IMPORTANT: CHECK CYCLES!!!
"""
def hostToMigrate(vm, checkFirst, vmUtil):
    print 'hosttomigrate'
    vucpu, vuram = vmUtil[vm.id]
    for id in checkFirst:
        if not id == vm.hostid:
            v = checkFirst[id]
            if (v[0] + vucpu) < maxUtilCPU * v[1] and (v[2] + vuram) < maxUtilMem * v[3]:
                return id
    return None


"""
Shikhar
Empty the host by migrating all the VMs if possible.
First we check if migration is possible on hosts in normalUtil.

EFFECT: deletes the host from the hostList or updates its util
entry in hostList if possible. We delete the entry so that
we do not form cycles later on.
"""
def emptyHost(hostid, hostList, checkFirst, checkSecond, vmUtil):
    vms = db(db.vm.hostid == hostid).select()
    ucpu, hcpu, uram, hram = hostList[hostid]
    """Maybe u can take vms in some sorted order : prefer LARGER ones for migration first"""
    for vm in vms:
        #print 'vm =' + vm.ip + ' ' + str(hostid)
        vucpu, vuram = vmUtil[vm.id]
        hostNew = hostToMigrate(vm, checkFirst, vmUtil)
        if hostNew:
            checkFirst[hostNew][0] += vucpu
            checkFirst[hostNew][2] += vuram
        else:
            hostNew = hostToMigrate(vm, checkSecond, vmUtil)
            if hostNew:
                #print hostNew
                checkSecond[hostNew][0] += vucpu
                checkSecond[hostNew][2] += vuram
            else:
                hostList[hostid][0] = ucpu
                hostList[hostid][2] = uram
                return False
        # add to queue to migrate vms[i]
        #print ' hostNew ' + str(hostNew)
        print vm.ip + ' go from ' + str(hostid) + ' to ' + str(hostNew) + ' in emptyHost'
        parameters="--live --persistent --undefinesource " + vm.name
        #db.queue.insert(task = 'migrate', vm = vm.id, chost = vm.hostid, dhost = hostNew, parameters = parameters, status=0, user=1, rtime = putdate())
        db.commit()
        noMigH[0] += 1
        ucpu -= vucpu
        uram -= vuram

    """
    We delete this entry from the hostList so that cycles are not formed
    """
    """
    IMPO: the other dequing code etc shd terminate the host if it is empty
    """
    del hostList[hostid] #UNCOMMENT!!!
    return True


"""
Shikhar
Reduces the utilization of host by migrating one/multiple VMs.
First we check if migration is possible on hosts in normalUtil.

EFFECT: puts the host in normal/under Util list and deletes/updates its
entry in overUtil list if possible
"""
def reduceUtil(hostid, hostList, checkFirst, checkSecond, vmUtil):
    vms = db(db.vm.hostid == hostid).select()
    ucpu, hcpu, uram, hram = hostList[hostid]
    """Maybe u can take vms in some sorted order : prefer smaller ones for migration"""
    i = 0
    while ucpu > maxUtilCPU * hcpu: #do for mem too
        vm = vms[i]
        vucpu, vuram = vmUtil[vm.id]
        hostNew = hostToMigrate(vm, checkFirst, vmUtil)
        if hostNew:
            checkFirst[hostNew][0] += vucpu
            checkFirst[hostNew][2] += vuram
        else:
            hostNew = hostToMigrate(vm, checkSecond, vmUtil)
            if hostNew:
                checkSecond[hostNew][0] += vucpu
                checkSecond[hostNew][2] += vuram
            else:
                hostList[hostid][0] = ucpu
                hostList[hostid][2] = uram
                return False
        # add to queue to migrate vms[i]
        print vm.ip + ' go from ' + str(hostid) + ' to ' + str(hostNew) + ' in reduceUtil'
        parameters="--live --persistent --undefinesource " + vm.name
        #db.queue.insert(task = "migrate", vm = vm.id, chost = vm.hostid, dhost = hostNew, parameters = parameters, status=0, user=1, rtime = putdate())
        db.commit()
        noMigH[0] += 1
        ucpu -= vucpu
        uram -= vuram
        i += 1

    hostList[hostid][0] = ucpu
    hostList[hostid][2] = uram
    flag = getHostUtilLevel(ucpu, hcpu, uram, hram)
    if flag <= 0:
        if flag == 0:
            checkFirst[hostid] = hostList[hostid]
        else:
            checkSecond[hostid] = hostList[hostid]
        del hostList[hostid]
    return True



"""
Shikhar
0 : ascending
1 : descending
Currently sorts v[0] in dict(k, v)
"""
def dictToSortList(overUtil, flag):
    import operator
    if flag == 0:
        return sorted(overUtil.iteritems(), key=operator.itemgetter(1))
    else:
        return sorted(overUtil.iteritems(), key=operator.itemgetter(1), reverse=True)



"""
Shikhar
Return the utilization level of the host based on cpu and mem
USEFUL for hosts
"""
def getHostUtilLevel(ucpu, hcpu, uram, hram):
    ratio1 = float(ucpu) / hcpu
    ratio2 = float(uram) / hram
    if ratio1 > maxUtilCPU or ratio2 > maxUtilMem:
        return 1
    elif ratio1 < minUtilCPU and ratio2 < minUtilMem:
        return -1
    else:
        return 0


"""
Shikhar
Checks the current CPU Utilization level by the data given by
/proc/stat
USEFUL for VMs
"""
def getCPUStatUtil(use, idle):
    if use == 0:
        return -1
    elif idle == 0:
        return 1

    ratio = float(use) / idle
    if ratio > 1.5:
        return 1
    elif ratio < 0.5:
        return -1
    else:
        return 0


"""
Shikhar
Checks the current memory Utilization level by the data given by
top utility
USEFUL for VMs
"""
def getMemStatUtil(use, total):
    ratio = float(use) / total
    if ratio > 0.85:
        return 1
    elif ratio < 0.3:
        return -1
    else:
        return 0


"""
Shikhar
Returns the actual memory in MB being used, and
effective CPUs being used
"""
def getVmUtil(name, vmUtil):
    import os, time
    #command = sudo -u www-data ssh -o StrictHostKeyChecking=no root@10.20.16.97 cat /proc/stat | grep 'cpu ' | awk -F  ' ' '{sum=$2+$3+$4} END {print sum}'
    #By default user is www-data
    if name.ip[0:8] == '10.17.1.':
        num = name.ip[8:]
        name.ip = '10.20.16.' + num
    if name.ip[0:8] == '10.17.2.':
        num = name.ip[8:]
        name.ip = '10.20.17.' + num
    """commandUtil = "ssh -o StrictHostKeyChecking=no root@" + name.ip + " cat /proc/stat | grep 'cpu ' | awk -F  ' ' '{sum=$2+$3+$4} END {print sum}'"
    utilcpu = int(os.popen(commandUtil).read())
    commandTotal = "ssh -o StrictHostKeyChecking=no root@" + name.ip + " cat /proc/stat | grep 'cpu ' | awk -F  ' ' '{sum=$2+$3+$4+$5} END {print sum}'"
    hcpu = int(os.popen(commandTotal).read())"""

    #print name.ip
    cmd = "ssh -o StrictHostKeyChecking=no root@" + name.ip + " top -n 1 -b | grep 'Mem:' | awk 'BEGIN { FS = \"[ \\t]+\" } ; { print $2\" \"$4 }'"
    line = os.popen(cmd).read()
    #print 'line ' + line
    l = line.split(' ')
    #print l
    totalMem = float(l[0].rsplit('k')[0]) / 1000
    usedMem = float(l[1].rsplit('k')[0]) / 1000

    cmd = "ssh -o StrictHostKeyChecking=no root@" + name.ip + " top -n 1 -b | grep 'Cpu(' | awk 'BEGIN { FS = \"[ \\t]+\" } ; { print $2 }'"
    line = os.popen(cmd).read()
    usedCpuPercent = float(line.rsplit('%')[0])
    usedCpu = (usedCpuPercent * name.vCPU) / 100

    #print 'chekunits'
    #print name.RAM
    print 'getVmutil util = ' + name.ip + ' ' + str(usedCpu) + ' ' + str(usedMem)

    vmUtil[name.id] = [usedCpu, usedMem]
    return vmUtil[name.id]



"""
Shikhar
Returns the total effective vCPUs and vRAM of all the VMs being effectively
used on the host
"""
def getHostUtil(hostid, vmUtil):
    vms = db(db.vm.hostid == hostid).select()
    ucpu = 0
    uram = 0
    for vm in vms:
        util = getVmUtil(vm, vmUtil)
        ucpu += util[0]
        uram += util[1]
    return ucpu, uram



def dummy(k):
    vms = db(db.vm.hostid == k).select()
    for vm in vms:
        print vm.ip


def printAllUtil(msg):
    print msg
    print underUtil
    print normalUtil
    print overUtil


"""
Shikhar
It first brings the overutilized hosts to normal.
Then it tries to empty the underutilized hosts and tries to place the VMs to normal
hosts preferably. And then empty the normal hosts if possible.
Currently it just takes into account the CPU utilization
"""
def reshuffle2():
    noMigH.append(0)
    hosts = db(db.host.status == 1).select()
    globalUcpu = 0
    globalHcpu = 0
    for host in hosts:
        ucpu, uram = getHostUtil(host.id, vmUtil)
        hcpu, hram = host.CPUs, (host.RAM * 1000)
        #print 'host ram = ' + str(hram)
        print str(host.id) + ' ' + host.ip + ' ' + str(ucpu) + ' ' + str(hcpu)
        globalUcpu += ucpu
        globalHcpu += hcpu
        """Currently we are looking at the CPU Utilization"""
        flag = getHostUtilLevel(ucpu, hcpu, uram, hram)
        inp = [ucpu, hcpu, uram, hram]
        if flag < 0:
            """
            We do not consider empty hosts as they would be powered-off
            by other cron job
            """
            vms = db(db.vm.hostid == host.id).select()
            if len(vms) > 0:
                underUtil[host.id] = inp
        elif flag > 0:
            overUtil[host.id] = inp
        else:
            normalUtil[host.id] = inp

    print vmUtil
    printAllUtil('initial lists:')

    """First make the overUtil list empty"""
    """This is just re-arranging the VMs..so globalUcpu and globalHcpu are not changed"""
    tmpOverUtil = dictToSortList(overUtil, 1)
    for k,v in tmpOverUtil:
        print 'overutil ' + str(k)
        success = reduceUtil(k, overUtil, normalUtil, underUtil, vmUtil)
        if not success:
            #IMPORTANT - switch on a host - shd be taken care by reduceUtil
            print 'Baadal overloaded'

    tmpUnderUtil = dictToSortList(underUtil, 0)
    for k,v in tmpUnderUtil:
        print 'underutil ' + str(k)
        ucpu, hcpu, uram, hram = v
        # take into consideration overprovisioning in the following line:
        if (globalHcpu - hcpu) - (globalUcpu - ucpu) >= maxUtilCPU * ucpu:
            # We can empty this VM. migrate all vms
            print 'khali karo!!'
            done = emptyHost(k, underUtil, normalUtil, underUtil, vmUtil)
            if done:
                globalHcpu -= hcpu
            else:
                globalUcpu -= underUtil[k][0]
                globalHcpu -= underUtil[k][1]
        #else:
            # We cannot empty any other host ... so better to return
            #return

    tmpNormalUtil = dictToSortList(normalUtil, 0)
    for k,v in tmpNormalUtil:
        print 'normalutil ' + str(k)
        ucpu, hcpu, uram, hram = v
        # take into consideration overprovisioning in the following line:
        if (globalHcpu - hcpu) - (globalUcpu - ucpu) > maxUtilCPU * ucpu:
            # We can empty this VM. migrate all vms
            print 'khali karo normal ko bhi!!'
            done = emptyHost(k, normalUtil, normalUtil, underUtil, vmUtil)
            if done:
                globalHcpu -= hcpu
            else:
                globalUcpu -= normalUtil[k][0]
                globalHcpu -= normalUtil[k][1]
        #else:
            # We cannot empty any other host ... so better to return
            #return
    printAllUtil('final lists:')

####################################################################################################

"""
Shikhar
Finds a new host purely on first fit
"""
def hostToMigrate2(vm, checkFirst, vmUtil):
    print 'hosttomigrate2'
    vucpu, vuram = vmUtil[vm.id]
    for id in checkFirst:
        v = checkFirst[id]
        if (v[0] + vucpu) < maxUtilCPU * v[1] and (v[2] + vuram) < maxUtilMem * v[3]:
            return id
    return None


"""
Shikhar
First fit (FF)
"""
def firstfit():
    noMigFF.append(0)
    hosts = db(db.host.status == 1).select()
    for host in hosts:
        hostUtil[host.id] = [0.0, host.CPUs, 0.0, host.RAM * 1000]
    print 'initial HostUtil = '
    print hostUtil
    print vmUtil

    vms = db(db.vm).select()
    for vm in vms:
        id = hostToMigrate2(vm, hostUtil, vmUtil)
        if not id:
            print 'Error'
            print ' HostUtil = '
            print hostUtil
            return

        hostUtil[id][0] += vmUtil[vm.id][0]
        hostUtil[id][2] += vmUtil[vm.id][1]
        if not id == vm.hostid:
            noMigFF[0] += 1
            print vm.ip + ' go from ' + str(vm.hostid) + ' to ' + str(id) + ' in firstfit'
            parameters="--live --persistent --undefinesource " + vm.name
            #db.queue.insert(task = 'migrate', vm = vm.id, chost = vm.hostid, dhost = id, parameters = parameters, status=0, user=1, rtime = putdate())
            db.commit()
    print 'final HostUtil = '
    print hostUtil



if __name__ == "__main__":
    reshuffle2()
    firstfit()
    print 'no of migrations of heuristics = '
    print noMigH[0]
    print 'no of migrations of firstfit = '
    print noMigFF[0]
