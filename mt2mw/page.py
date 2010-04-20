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
import os
import subprocess as sp

class HTMLPage:
    def __init__(self, id, title, wiki, path):
        self.id = id
        self.title = title
        self.wiki = wiki
        self.path = path
        self.subpages = list()

    def add_subpage(self, page):
        self.subpages.append(page)

    def get_content(self):
        return self.wiki.get_page_content(self)


class WikiPage:
    def __init__(self, title):
        self.title = title
        self.path = title

    def get_content(self):
        return self.content


def html2wiki(html):
    cmd = os.path.join(os.getcwd(), 'convert.pl')
    converter = sp.Popen(cmd, stdin=sp.PIPE, stdout=sp.PIPE, stderr=sp.PIPE, shell=True)
    out, err = converter.communicate(input=html)
    if err:
        raise Exception(err)
    return out

