'''
Created on 18-Dec-2012

@author: vaio
'''
import commands
import smtplib 
import logging
from logging.handlers import TimedRotatingFileHandler
from email.mime.text import MIMEText

logHandler = TimedRotatingFileHandler('/home/www-data/web2py/applications/baadal/logs/logfile','midnight')
logFormatter = logging.Formatter('%(asctime)s : %(message)s')
logHandler.setFormatter( logFormatter )
LOGGER = logging.getLogger(__name__)
LOGGER.addHandler(logHandler)
LOGGER.setLevel(logging.DEBUG)

ipaddress = commands.getoutput("/sbin/ifconfig").split("\n")[1].split()[1][5:]

def send_alert_mail(raw_msg):
    
    From = getconstant('email_from') 
    To  = getconstant('email_to').split(",")
    Usrnm = getconstant('email_sender_account_username')
    Pswd = getconstant('email_sender_account_password') 

    message = MIMEText(raw_msg)

    message['Subject'] = '[BAADAL CSE: ' + ipaddress + '] MAIL ALERT'
    message['From'] = From

    try:         
        server = smtplib.SMTP(getconstant('smtp_server')+":"+getconstant('smtp_port'))
        server.starttls()
        server.login(Usrnm,Pswd)
        server.sendmail(From, To, message.as_string())
    except Exception as e:
        LOGGER.error('UNABLE TO SEND MAIL!!!')
        LOGGER.exception(e)
    else: 
        LOGGER.info('Mail Sending Successful!!!')
    finally: 
        server.quit()


def check_process_status(proc_list,proc_type):

    send_mail = 0
    message = '\n'

    for proc_name in proc_list:

        command = 'ps -ef | grep '+proc_type+' | grep /home/www-data/web2py/applications/baadal/private/'+proc_name+' | wc -l';
        flag = int(commands.getoutput(command))
	flag -= 1
    
        if 0 == flag:
            message += proc_name + " IS NOT RUNNING!!!\n"
            LOGGER.info(message)
            LOGGER.info("Initializing sending alert mail...............")
            send_mail = 1
        elif 1 == flag:
            LOGGER.info(proc_name + " IS RUNNING FINE")
        elif 1 < flag:
            message += "MULTIPLE INSTANCES OF " + proc_name + " RUNNING!!!\n"
            LOGGER.info(message)
            LOGGER.info("Initializing sending alert mail...............")
            send_mail = 1
        
    message = "IP Address: " + ipaddress + "\n" + message

    if 1 == send_mail:
        send_alert_mail(message)

def report_baadal_cse_status():
    
    proc_list = ['process.py','hostpower.py']
    proc_type = 'python'
    
    check_process_status(proc_list, proc_type)
        
def main():
    
    report_baadal_cse_status()

if "__main__" == __name__:
    main()
