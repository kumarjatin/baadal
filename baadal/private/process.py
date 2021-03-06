task = {'start'     :   start,
        'shutdown'  :   shutdown,
        'destroy'   :   destroy,
        'suspend'   :   suspend,
        'resume'    :   resume,
        'migrate'   :   migrate,
        'changelevel':  changelevel,
        'delete'    :   delete,
        'install'   :   install,
}

import time,sys,commands
counter=0   #After every 12 iterations of idle it checks if runlevel and vmstate are consistent
while True:
    db.commit()
    try :
        processes=db(db.queue.status==0).select()
        print len(processes)
        if(len(processes) >= 1):
            try:
		print commands.getstatusoutput('date')[1]
                process=processes[0]
		print str(process)
                task[process['task']](process['id'],process['vm'],process['chost'],process['dhost'],process['parameters'])
                db.commit()
                print "Task done"
            except Exception as e:
                import traceback
		print e
                etype, value, tb = sys.exc_info()
                msg=''.join(traceback.format_exception(etype, value, tb, 10))
                db(db.queue.id==process['id']).update(status=-1,comments=msg,ftime=putdate())
        else :
            if(counter%12==0):
                #counter=0
		print commands.getstatusoutput('date')[1]
                print "Synching vm runlevels and their actual state"
                allvms=db(db.vm.id>=0).select(db.vm.name,db.vm.runlevel)
                for vm in allvms:
                   # if vm.name[:2] == 'vm':
                   #     continue
                    print "Working on "+vm.name
		    try:
                    	level=getactualvmlevel(vm.name)
		    except Exception as e:
			import traceback
			print e
			etype, value, tb = sys.exc_info()
			msg=''.join(traceback.format_exception(etype, value, tb, 10))
			print msg
                    if(vm.runlevel!=level):
                        print "Updating runlevel of "+vm.name+" to "+str(level)
                        db(db.vm.name==vm.name).update(runlevel=level)
            if(counter%1000==0):
                counter=0
		auth_type = getconstant('authentication_type')		

		if(auth_type == "ldap"):
	        	print "Synching ldap users"
    	            	ldapsync()
    	            	print "Synching faculty from ldap with database faculty"
    	            	faculty_sync()
    	            	print "Synching complete"
            counter=counter+1
            print "Taking a cofee break"
            time.sleep(10)
    except :
        import traceback
        etype, value, tb = sys.exc_info()
        msg=''.join(traceback.format_exception(etype, value, tb, 10))
        print msg
        time.sleep(10)
