def sanity_check():
    import libvirt, string
    vmcheck=[]
    hosts=db(db.host.status==1).select()
    print hosts
    for host in hosts:
        try:
            #Establish a read only remote connection to libvirtd
            #find out all domains running and not running
            #Since it might result in an error add an exception handler
            conn = libvirt.openReadOnly('qemu+ssh://root@'+host.ip+'/system')
            domains=[]
            ids = conn.listDomainsID()
            for id in ids:
                domains.append(conn.lookupByID(id))
            names = conn.listDefinedDomains()
            for name in names:
                domains.append(conn.lookupByName(name))
            for dom in domains:
                try:
                    name = dom.name()
                    vm = db(db.vm.name == name).select(db.vm.hostid,db.vm.name)
                    status=vminfotostate(dom.info()[0])
                    if(len(vm)!=0):
                        vm=vm[0]
                        if(vm.hostid!=host.id):
                            vmcheck.append({'host':host.name,'vmname':vm.name,'status':status,'operation':'Moved from '+vm.hostid.name+' to '+host.name})#Stupid VMs
                            db(db.vm.name==name).update(hostid=host.id)
                        else:
                            vmcheck.append({'host':host.name,'vmname':vm.name,'status':status,'operation':'Is on expected host '+vm.hostid.name})#Good VMs
                    else:
                        vmcheck.append({'host':host.name,'vmname':dom.name(),'status':status,'operation':'Orphan, VM is not in database'})#Orphan VMs
                    dom=""
                except:vmcheck.append({'vmname':vm.name,'vmid':vm.id,'operation':'Some Error Occured'})
            domains=[]
            names=[]
            print conn.close()
        except:pass
    return vmcheck
