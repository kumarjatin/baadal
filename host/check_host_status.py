'''
Created on 18-Dec-2012

@author: vaio
'''
import commands
import smtplib 
import logging
import ConfigParser
from logging.handlers import TimedRotatingFileHandler
from email.mime.text import MIMEText

Config = ConfigParser.ConfigParser()
Config.read("config-file-host")

logHandler = TimedRotatingFileHandler('/var/tmp/baadal_host_log','midnight')
logFormatter = logging.Formatter('%(asctime)s : %(message)s')
logHandler.setFormatter( logFormatter )
LOGGER = logging.getLogger(__name__)
LOGGER.addHandler(logHandler)
LOGGER.setLevel(logging.DEBUG)

ipaddress = commands.getoutput("/sbin/ifconfig").split("\n")[1].split()[1][5:]

def send_alert_mail(raw_msg):
    
    From = Config.get("MAIL_CONF","email_from").strip()
    To  = Config.get("MAIL_CONF","email_to").strip().split(",")
    Usrnm = Config.get("MAIL_CONF","email_sender_account_username").strip()
    Pswd = Config.get("MAIL_CONF","email_sender_account_password").strip()

    message = MIMEText(raw_msg)

    message['Subject'] = '[BAADAL HOST - '+ipaddress+' ] MAIL ALERT'
    message['From'] = From

    try:         
        server = smtplib.SMTP(Config.get("MAIL_CONF","smtp_server").strip()+":"+Config.get("MAIL_CONF","smtp_port").strip())
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


def check_bridge_status():

    send_mail = 0
    message = '\n'

    command = 'ps -ef | grep -w br0 | grep -w yes | wc -l';
    flag = int(commands.getoutput(command))
    flag-=1
    
    if 0 == flag:
        message += "BRIDGE IS NOT RUNNING ON HOST - "+ ipaddress +" !!!\n"
        LOGGER.info(message)
        LOGGER.info("Initializing sending alert mail...............")
        send_mail = 1
    elif 1 == flag:
        LOGGER.info("BRIDGE IS RUNNING FINE!!!")


    if 1 == send_mail:
        send_alert_mail(message)

       
def main():
    
    check_bridge_status()

if "__main__" == __name__:

    main()
