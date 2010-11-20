#
# Regular cron jobs for the custom-site-mahara-langpacks package
#
22 *    * * *   root    [ -x /usr/lib/mahara-langpacks/langpacks.sh ] && /usr/lib/mahara-langpacks/langpacks.sh >> /var/log/mahara-langpacks.log

