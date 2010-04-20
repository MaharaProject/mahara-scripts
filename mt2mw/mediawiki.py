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
import wikitools as wt

# our library
from page import WikiPage, html2wiki

class MWWiki:
    def __init__(self, baseurl, username, password):
        try:
            self.site = wt.wiki.Wiki('%s/api.php' % baseurl)
            self.site.login(username, password=password, remember=True)
        except Exception, e:
            print e

    def html_write(self, page):
        p = wt.page.Page(self.site, title=page.path)
        try:
            p.edit(text=html2wiki(page.get_content()))
        except Exception, e:
            print e

    def write(self, page):
        p = wt.page.Page(self.site, title=page.path)
        try:
            p.edit(text=page.get_content())
        except Exception, e:
            print e

    def update_mainpage(self, root):
        mainpage = WikiPage('MediaWiki:Mainpage')
        mainpage.content = root.title.replace(' ', '_')
        self.write(mainpage)

    def create_from_mindtouch(self, root):
        self.html_write(root)
        for subpage in root.subpages:
            self.create_from_mindtouch(subpage)

    def done(self):
        self.site.logout()

