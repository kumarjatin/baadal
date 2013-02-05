import time,sys
while True:
    db.commit()
    try :
        print "\nChecking Required no. of hosts\n-------------------------------------"
        hostpoweroperation()
        print "\nSanity check for host status in database\n-----------------------------------------"
        hoststatussanitycheck()
	db.commit()
        time.sleep(10)
    except :
        import traceback
        etype, value, tb = sys.exc_info()
        msg=''.join(traceback.format_exception(etype, value, tb, 10))
        print msg
        time.sleep(10)
