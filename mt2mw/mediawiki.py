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

class MWWiki:
    def __init__(self, baseurl, username, password):
        try:
            self.site = wt.wiki.Wiki('%s/api.php' % baseurl)
            self.site.login(username, password=password, remember=True)
        except Exception, e:
            print e

    @staticmethod
    def subpage_menu(page):
        if page.subpages:
            result = '\n\n===Subpages===\n\n%s' % '\n'.join(list('* [[%s|%s]]' % (s.path, s.title) for s in page.subpages))
            return result.encode('utf-8')
        return ''

    @staticmethod
    def files_list(page):
        if page.files:
            result = '\n\n===Files===\n\n%s' % '\n'.join(list('*[[File:%s]]' % (f.title) for f in page.files))
            return result.encode('utf-8')
        return ''

    def write(self, page):
        # upload the files for this page
        for file in page.files:
            f = wt.wikifile.File(self.site, file.title)
            try:
                f.upload(url=file.url)
            except Exception, e:
                print e
        # write the page itself
        p = wt.page.Page(self.site, title=page.path)
        try:
            p.edit(
                text='%s%s%s' % (
                    page.towiki(),
                    MWWiki.files_list(page),
                    MWWiki.subpage_menu(page)
                ),
                skipmd5=True
            )
        except Exception, e:
            print  e

    def update_mainpage(self, root):
        p = wt.page.Page(self.site, title='MediaWiki:Mainpage')
        try:
            p.edit(text=root.title.replace(' ', '_'))
        except Exception, e:
            print e

    def create_from_mindtouch(self, root):
        self.write(root)
        for subpage in root.subpages:
            self.create_from_mindtouch(subpage)

    def done(self):
        self.site.logout()

