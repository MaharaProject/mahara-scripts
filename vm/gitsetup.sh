#!/bin/bash

# This is a shell script to assist non-technical users in customizing the git environment
# in a VM that already has Mahara installed.
localuser=qa
homedir=/home/$localuser
sshdir=$homedir/.ssh
desktopdir=$homedir/Desktop

echo ""
echo "This script will help you set up your git and generate your SSH public key"
echo "for the Mahara Project's Gerrit."
echo ""
echo "If you haven't set up accounts on"
echo " * https://launchpad.net"
echo " * https://reviews.mahara.org"
echo "... hit Control-C to quit, and set those up now."
echo ""
echo "Otherwise, hit Return to continue."
read


echo "Please enter your name (example: Mike O'Connor): "
read name
echo "Please enter your email address: "
read email

echo ""
echo "Setting up \"${name} <${email}>\..."
echo ""

git config --global user.name $name
git config --global user.email $email

mkdir $sshdir >> /dev/null 2>&1
mkdir $desktopdir >> /dev/null 2>&1
chmod 700 $sshdir
if [ ! -f $sshdir/id_rsa.pub ]; then
    ssh-keygen -t rsa -b 4096 -C $email -f $sshdir/id_rsa -N ""
fi
cp $sshdir/id_rsa.pub $desktopdir/id_rsa.pub.txt

echo ""
echo "Almost done! Now you need to enter your public SSH key into your Gerrit account."
echo ""
echo "1. Open up the text file \"id_rsa.pub.txt\" on your VM's desktop."
echo "2. Copy its contents to the clipboard."
echo "3. Go to https://reviews.mahara.org/#/settings/ssh-keys"
echo "4. Click the \"Add Key ...\" button."
echo "5. Paste the contents of \"id_rsa.pub.txt\" into the text field."
echo "6. Click the \"Add\" button."
echo ""
echo "Then you should be able to push patches to Mahara's Gerrit, using \"make push\"!"
