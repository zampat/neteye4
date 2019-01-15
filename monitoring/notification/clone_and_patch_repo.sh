
# Clone Git Repo
if [ ! -d "./Nagios-Responsive-HTML-Email-Notifications" ]
then
   /usr/bin/git clone https://github.com/heiniha/Nagios-Responsive-HTML-Email-Notifications.git

   patch Nagios-Responsive-HTML-Email-Notifications/php-html-email/nagios_host_mail < nagios_host_mail.diff

   patch Nagios-Responsive-HTML-Email-Notifications/php-html-email/nagios_service_mail < nagios_service_mail.diff
fi


