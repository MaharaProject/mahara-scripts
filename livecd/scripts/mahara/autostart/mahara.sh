#!/bin/bash

# Update the latest code from git.mahara.org
cd /var/www/html
sudo -H -u www-data git pull && git checkout main
# Update the CSS
sudo -H -u www-data make css

# Update mahara site
sudo -H -u www-data htdocs/admin/cli/upgrade.php
cd $HOME

# Hide Unity launcher
#dconf write /org/compiz/profiles/unity/plugins/unityshell/launcher-hide-mode 1
#dconf write /org/compiz/profiles/unity/plugins/unityshell/edge-responsiveness 0
#dconf write /org/compiz/profiles/unity/plugins/unityshell/shortcut-overlay false

# Remove the Examples shortcut on desktop
rm -f $HOME/Desktop/examples.desktop

# Open Firefox in full screen
Xaxis=$(xrandr --current | grep '*' | uniq | awk '{print $1}' | cut -d 'x' -f1)
Yaxis=$(xrandr --current | grep '*' | uniq | awk '{print $1}' | cut -d 'x' -f2)
firefox -height $Yaxis -width $Xaxis http://localhost
