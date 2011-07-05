#
# Regular cron jobs for the custom-site-mahara-langpacks package
#
22 *    * * *   maharabot    [ -x /usr/lib/mahara-langpacks/langpacks.sh ] && /usr/lib/mahara-langpacks/langpacks.sh >> /var/log/mahara-langpacks/langpacks.log 2>&1
52 7    * * *   maharabot    [ -x /usr/lib/mahara-langpacks/update-pot.sh ] && /usr/lib/mahara-langpacks/update-pot.sh >> /var/log/mahara-langpacks/update-pot.log 2>&1

