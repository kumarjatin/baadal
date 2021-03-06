# -*- coding: utf-8 -*-

import ConfigParser

Config = ConfigParser.ConfigParser()
Config.read("/home/www-data/web2py/applications/baadal/config-file-baadal")


Auth_Type = Config.get("AUTHENTICATION_CONF","authentication_type").strip()
DB_Type = Config.get("GENERAL_CONF","database_type").strip()


if DB_Type.lower() == "sqlite":
	db = DAL('sqlite://storage.sqlite')
elif DB_Type.lower() == "mysql":
	mysql_password=Config.get("MYSQL_CONF","mysql_password").strip()
	db = DAL('mysql://root:'+str(mysql_password)+'@localhost/baadal')

from gluon.tools import *
mail = Mail()                                  # mailer
auth = Auth(globals(),db)                      # authentication/authorization
crud = Crud(globals(),db)                      # for CRUD helpers using auth
service = Service(globals())                   # for json, xml, jsonrpc, xmlrpc, amfrpc
plugins = PluginManager()
help_text=""
msg=""

# adding extra field in auth_user table the tells weather the 
#  user is admin or faculty or normal
auth.settings.extra_fields['auth_user']= [ Field('cateogory')]

#########################################################################
auth.define_tables(username=True)                           # creates all needed tables
auth.settings.mailer = mail                    # for user email verification
auth.settings.remember_me_form = False

if Auth_Type.lower() == "localDB":
	auth.settings.actions_disabled=['register','request_reset_password','profile','forgot_username','retrieve_username']
elif Auth_Type.lower() == "ldap":
	from gluon.contrib.login_methods.pam_auth import pam_auth
	auth.settings.actions_disabled=['register','change_password','request_reset_password','profile','forgot_username','retrieve_username','remember']
	auth.settings.login_methods=[pam_auth()]

auth.settings.allow_basic_login = True  #for CLI access
crud.settings.auth = None                      # =auth to enforce authorization on crud
#########################################################################
#########################################################################
db.define_table('host',
    SQLField('name', requires=IS_NOT_EMPTY(),unique=True),
    SQLField('ip',default="",requires=IS_NOT_EMPTY(),unique=True),
    SQLField('mac',default="",requires=IS_NOT_EMPTY(),unique=True),
    SQLField('HDD','integer',default="",requires=IS_NOT_EMPTY()),
    SQLField('CPUs','integer',default="",requires=IS_NOT_EMPTY()),
    SQLField('RAM','integer',default="",requires=IS_NOT_EMPTY()),
    SQLField('status','integer',default=0),  #0 means DOWN, 1 means UP
    SQLField('rr_server','boolean',default=False),
    SQLField('vmcount','integer',default="0",requires=IS_NOT_EMPTY(),readable=False,writable=False))
db.host.HDD.requires=IS_INT_IN_RANGE(1,1000)
db.host.RAM.requires=IS_INT_IN_RANGE(1,40964)

db.define_table('template',
    SQLField('name',default="",requires=IS_NOT_EMPTY(),unique=True),
    SQLField('ostype',default="Linux",requires=IS_IN_SET(('Linux', 'Windows', 'Others'))),
    SQLField('arch',default="amd64",requires=IS_IN_SET(('amd64','i386'))),
    SQLField('hdd',requires=IS_NOT_EMPTY()),
    SQLField('hdfile', default="lenny_505_32.qcow2", requires=IS_NOT_EMPTY()),
    SQLField('other_details',default="i386 Desktop",requires=IS_NOT_EMPTY()))

db.define_table('isofile',
    SQLField('name',requires=IS_NOT_EMPTY()),
    SQLField('ostype',default="Linux",requires=IS_IN_SET(('Linux', 'Windows', 'Others'))),
    SQLField('cdimage',requires=IS_NOT_EMPTY()),
    SQLField('architecture',default="i386",requires=IS_IN_SET(('i386','i686'))))

db.define_table('datastores',
    SQLField('name','string'),
    SQLField('ip','string'),
    SQLField('path','string'),
    SQLField('username','string',default='root',requires=IS_NOT_EMPTY()),
    SQLField('password','string',default='root@123',requires=IS_NOT_EMPTY()),
    SQLField('capacity','integer',default='0'), #Capacity in GB
    SQLField('used','integer',default='0'),     #Used in GB
    SQLField('type',requires=IS_IN_SET(('SAN','NAS'))),     #NFS,SAN,NAS
    SQLField('other','string'))

db.define_table('vm',
    SQLField('name','string'),
    SQLField('userid',db.auth_user),
    SQLField('hostid',db.host),
    SQLField('definedon',db.host),  #id of host the vm is actually running on
    SQLField('RAM','integer',requires=IS_NOT_EMPTY()),
    SQLField('HDD','integer',requires=IS_NOT_EMPTY()),
    SQLField('vCPU','integer',requires=IS_NOT_EMPTY()),
    SQLField('templateid',db.template),
    SQLField('ip','string'),
    SQLField('mac','string'),
    SQLField('datastore',db.datastores),
    SQLField('purpose', 'text', default="Purpose not entered.", requires=IS_NOT_EMPTY()),
    SQLField('expire_date','datetime',requires=IS_NOT_EMPTY()),
    SQLField('sport','integer'),
    SQLField('dport','integer'),
    SQLField('rrport'),
    SQLField('tap_no',type='integer'),  
    SQLField('rr','boolean',default=False),#Failover safe
    SQLField('locked','boolean',default=False), #True if locked by Administrator else False
    SQLField('totalcost',default=0),    # Total cost except the current cost(if the machine is running)
    SQLField('laststarttime','string'), # Last start time, is put to 0 if it is shutdown
    SQLField('lastrunlevel','integer',default=0),# when the machine is started by default it is at the runlevel previosly set by user or during change in runlevel
    SQLField('runlevel','integer',default=3),   # 0:shutdown    1:1cpu,512MB    2:2cpu,1GB  3:4cpu,2GB
    SQLField('nextrunlevel','integer',default=3))   # 0:shutdown    1:1cpu,512MB    2:2cpu,1GB  3:4cpu,2GB
db.vm.templateid.requires=IS_IN_DB(db,'template.id','%(name)s')
db.vm.datastore.requires=IS_IN_DB(db,'datastores.id','%(name)s')

db.define_table('attacheddisks',
    SQLField('vmname',db.vm),
    SQLField('size','integer',default=10),  #Size is in GB
    SQLField('addinfo','string'))
db.attacheddisks.vmname.requires=IS_IN_DB(db,'vm.id','%(name)s')

db.define_table('clonevm',
    SQLField('name',requires=IS_NOT_EMPTY()))

db.define_table('snapshots',
    SQLField('name'),
    SQLField('vm',db.vm))
db.snapshots.vm.requires=IS_IN_DB(db,'vm.id','%(name)s')

db.define_table('email',
    SQLField('from_address','string'),
    SQLField('to_address','string'),
    SQLField('subject','string'),
    SQLField('email_txt','text',length=40000))
db.email.from_address.requires = IS_EMAIL(error_message=T('Invalid From Address!'))

db.define_table('faculty',
    SQLField('name','string'))

#db.define_table('cpu_logs',
#   SQLField('vm'),
#   SQLField('timestamp'),
#   SQLField('usage'))
#db.cpu_logs.vm.requires=IS_IN_DB(db,'vm.id','%(name)s')

db.define_table('request',
    SQLField('vmname', 'string',requires=IS_NOT_EMPTY()),
    SQLField('userid', db.auth_user, writable=False, readable=False),
    #SQLField('config','string',default='1 CPU, 1GB RAM, 40GB HDD',requires=IS_IN_SET(('1 CPU, 1GB RAM, 40GB HDD','1 CPU, 2GB RAM, 40GB HDD','2 CPU, 2GB RAM, 40GB HDD','2 CPU, 4GB RAM, 40GB HDD','4 CPU, 4GB RAM, 40GB HDD','4 CPU, 8GB RAM, 40GB HDD','8 CPU, 8GB RAM, 40GB HDD','8 CPU, 16GB RAM, 40GB HDD'))),
    SQLField('config','string',default='1 CPU, 1GB RAM, 40GB HDD',requires=IS_IN_SET(('1 CPU, 1GB RAM, 40GB HDD','1 CPU, 2GB RAM, 40GB HDD','2 CPU, 2GB RAM, 40GB HDD','2 CPU, 4GB RAM, 40GB HDD','4 CPU, 4GB RAM, 40GB HDD','4 CPU, 8GB RAM, 40GB HDD','8 CPU, 8GB RAM, 40GB HDD'))),
    SQLField('RAM', 'integer', default='512', requires=IS_NOT_EMPTY()),
    SQLField('HDD', 'integer', default='0'),
    SQLField('vCPUs', 'integer', default='1'),
    SQLField('templateid',db.template),
    SQLField('cloneparentname','string'),
    SQLField('kvmhost'),
    SQLField('kvmrrhost'),
    SQLField('rr','boolean',default=False),#Failover safe
    SQLField('status', 'integer', default=0, requires=IS_NOT_EMPTY(), writable=False),
    SQLField('purpose', 'text', default="Please specify the details of the project:\n\nExplain the reason for choosing this configuration:", requires=IS_NOT_EMPTY()),
    SQLField('faculty', 'string', requires=IS_NOT_EMPTY()),
    SQLField('expire_date','datetime',requires=IS_NOT_EMPTY()))
db.request.faculty.widget = SQLFORM.widgets.autocomplete(request, db.faculty.name)
db.request.faculty.requires = IS_IN_DB(db,'faculty.name','%(name)s',error_message="No faculty with such username exists")
db.request.vmname.requires = IS_NOT_IN_DB(db,'vm.name','VM with same name already exists. Please try some other name.')
db.request.templateid.requires=IS_IN_DB(db, 'template.id', '%(name)s')
db.request.kvmhost.requires=IS_IN_DB(db,'host.id','%(name)s')
db.request.HDD.requires=requires=IS_INT_IN_RANGE(0,1024)

db.define_table('logs_request',
    SQLField('vmname', 'string', default='cloudburst', requires=IS_NOT_EMPTY()),
    SQLField('userid', db.auth_user, writable=False, readable=False),
    SQLField('RAM', 'integer', default='64', requires=IS_NOT_EMPTY()),
    SQLField('HDD', 'integer', default='10'),
    SQLField('vCPUs', 'integer', default='1'),
    SQLField('templateid', db.template),
    SQLField('cloneparentname', 'string'),
    SQLField('status', 'text', requires=IS_NOT_EMPTY(), writable=False),
    SQLField('expire_date','datetime',requires=IS_NOT_EMPTY()),
    SQLField('purpose', 'text', default="Project name: \n\nProject Members: ", requires=IS_NOT_EMPTY()),
    SQLField('faculty', 'string', requires=IS_NOT_EMPTY()))
db.logs_request.templateid.requires=IS_IN_DB(db, 'template.id', '%(name)s')

db.define_table('logs',
    SQLField('record','string',requires=IS_NOT_EMPTY()),
    SQLField('timestamp','datetime',default=request.now,update=request.now,writable=False))

db.define_table('vmaccpermissions',
    SQLField('userid',db.auth_user),
    SQLField('vmid',db.vm))
db.vmaccpermissions.vmid.requires=IS_IN_DB(db,'vm.id','%(name)s')
db.vmaccpermissions.userid.requires=IS_IN_DB(db,'auth_user.id','%(username)s')

db.define_table('constants',
    SQLField('name',requires=IS_NOT_EMPTY()),
    SQLField('value',requires=IS_NOT_EMPTY()),
    primarykey=['name'])

db.define_table('queue',
    SQLField('task','string'),
    SQLField('vm',db.vm),
    SQLField('chost',db.host),
    SQLField('dhost',db.host),
    SQLField('parameters',requires=IS_NOT_EMPTY()),
    SQLField('status','integer'), #0=>pending 1=>success, -1=>fail
    SQLField('comments','text'),
    SQLField('user',db.auth_user),
    SQLField('rtime','datetime',writable=False),    #Request time
    SQLField('ftime','datetime',writable=False),    #Finish time
    SQLField('datetime','datetime',default=request.now,update=request.now,writable=False)
)
db.queue.vm.requires=IS_IN_DB(db,'vm.id','%(name)s')
db.queue.user.requires=IS_IN_DB(db,'auth_user.id','%(username)s')
db.queue.chost.requires=IS_IN_DB(db,'host.id','%(name)s')
db.queue.dhost.requires=IS_IN_DB(db,'host.id','%(name)s')

db.define_table('migrate',
    SQLField('chost',requires=IS_NOT_EMPTY()),  #Current host of vm
    SQLField('dhost',requires=IS_NOT_EMPTY()),  #Destination host of vm
    SQLField('vm',requires=IS_NOT_EMPTY()),
    SQLField('live','boolean',default=True),
    SQLField('p2p','boolean'),
    SQLField('tunnelled','boolean'),
    SQLField('persistent','boolean'),
    SQLField('suspend','boolean'),
    SQLField('dname',requires=IS_NOT_EMPTY()))
db.migrate.dhost.requires=IS_IN_DB(db,'host.id','%(ip)s')

db.define_table('errors',
    SQLField('error',requires=IS_NOT_EMPTY()),                          #Insert error ticket
    SQLField('status','boolean',default=True,requires=IS_NOT_EMPTY()))  #True if error exits, False if done


db.define_table('help',
    SQLField('token',requires=IS_NOT_EMPTY()),
    SQLField('text',requires=IS_NOT_EMPTY()))
####### DB initialization ##########


if db(db.constants).select().__len__() == 0:
    db.constants.insert(name = 'ifbaadaldown', value = '0')
    db.constants.insert(name = 'webserver_ip', value = '10.7.22.1') ############################
    db.constants.insert(name = 'webserver_interface', value = 'eth0')
    db.constants.insert(name = 'iptables_path', value = '/sbin/iptables')
    db.constants.insert(name = 'vmfiles_path', value = '/vms/')
    db.constants.insert(name = 'isofilespath', value = 'isofiles/') 
    db.constants.insert(name = 'templates_path', value = 'vm_templates/') ################################
    db.constants.insert(name = 'templates_dir', value = 'vm_templates') ##################################
    db.constants.insert(name = 'datastore_int',value = 'ds_')
    db.constants.insert(name = 'diffports', value = '1000')
    db.constants.insert(name = 'netapp_loc', value = "/vol/kvm_test/kvm/")
    db.constants.insert(name = 'iptables_backup_path', value = '/var/www/ipt_latest')
    db.constants.insert(name = 'mac_range', value = '54:52:00:01:')     #Cost per cpu per hour
    db.constants.insert(name = 'ip_range', value = '10.20.17.')        #Cost per cpu per hour
    db.constants.insert(name = 'vncport_range', value = '5920')     #Cost per cpu per hour
    db.constants.insert(name = 'defined_vms', value = '68')     #Cost per cpu per hour
    db.constants.insert(name = 'cost_cpu', value = '1')     #Cost per cpu per hour
    db.constants.insert(name = 'cost_ram', value = '1')     #Cost per 1 GB RAM per hour
    db.constants.insert(name = 'cost_scale', value = '1.2') #Cost scaling factor
    db.constants.insert(name = 'cost_runlevel_0', value = '0')
    db.constants.insert(name = 'cost_runlevel_1', value = '5')
    db.constants.insert(name = 'cost_runlevel_2', value = '15')
    db.constants.insert(name = 'cost_runlevel_3', value = '30')
    db.constants.insert(name = 'provisionl3', value = '4')   #Provisioning value for Bronze level, default 4:1
    db.constants.insert(name = 'provisionl2', value = '2')   #Provisioning value for Silver level, default 2:1
    db.constants.insert(name = 'provisionl1', value = '1')   #Provisioning value for Gold level, default 1:1
    db.constants.insert(name = 'log_level', value = '1')
    db.constants.insert(name = 'lock_loc', value = "/var/lock/web2py/")
    db.constants.insert(name = 'mac_script',value = '/vms/scripts/macaddress')
    db.constants.insert(name = 'tap_default', value = '0')
    db.constants.insert(name = 'tap_script', value = '/vms/scripts/qemu-ifup')
    db.constants.insert(name = 'rr_default_port', value = '2000')
    db.constants.insert(name = 'authentication_type', value = Auth_Type)
    db.constants.insert(name = 'database__type', value = DB_Type)
    db.constants.insert(name = 'email_from', value = Config.get("MAIL_CONF","email_from").strip())
    db.constants.insert(name = 'smtp_server', value = Config.get("MAIL_CONF","smtp_server").strip())
    db.constants.insert(name = 'smtp_port', value = Config.get("MAIL_CONF","smtp_port").strip())
    db.constants.insert(name = 'email_to', value = Config.get("MAIL_CONF","email_to").strip())
    db.constants.insert(name = 'email_sender_account_username', value = Config.get("MAIL_CONF","email_sender_account_username").strip())
    db.constants.insert(name = 'email_sender_account_password', value = Config.get("MAIL_CONF","email_sender_account_password").strip())

if db(db.help).select().__len__() == 0:
    db.help.insert(token = 'request_vm_template', text = 'Form for request of creation of virtual machines based on predefined templates.')
    db.help.insert(token = 'request_vm_manual', text = 'Form for request of creation of virtual machines which are not based on templates.')
    db.help.insert(token = 'postman', text = 'Form to mail multiple users (seperated by commas) regarding their virtual machines.')
