# mt2mw -- package for migrating a Mindtouch wiki to MediaWiki
# Copyright (C) 2010 Catalyst IT Ltd 

# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.

# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.

# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.


# system library
import ConfigParser as cp

# our library
from mindtouch import MTWiki
from mediawiki import MWWiki

cfg = cp.SafeConfigParser()
cfg.read('config.ini')

# get the root element in the page structure
print "Attempting to get the mindtouch wiki layout"
mtwiki = MTWiki(cfg.get('config', 'mindtouch_url'))
homepage = mtwiki.get_sitemap()
if homepage:
    print "Have mindtouch layout."

directdb = cfg.get('config', 'direct_db')
dbconfig = None
if directdb:
    dbconfig = {
        'host': cfg.get('config', 'mediawiki_db_host'),
        'database': cfg.get('config', 'mediawiki_db'),
        'user': cfg.get('config', 'mediawiki_db_user'),
        'password': cfg.get('config', 'mediawiki_db_password'),
    }

print "Attempting to create mediawiki connection"
mwwiki = MWWiki(
    cfg.get('config', 'mediawiki_url'),
    cfg.get('config', 'mediawiki_user'),
    cfg.get('config', 'mediawiki_password'),
    dbconfig,
    cfg.get('config', 'dataroot'),
)
if mwwiki:
    print "MediaWiki Connection created"

print "Creating MediaWiki from mindtouch site..."
mwwiki.create_from_mindtouch(homepage)
print "MediaWiki updated"

# point MediaWiki:MainPage at the new homepage
print "Updating MediaWiki homepage"
mwwiki.update_mainpage(homepage)
mwwiki.done()
print "All done!"
