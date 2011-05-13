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
import urllib2
import mimetypes
from datetime import datetime, tzinfo
import psycopg2 as pg
import re

class File:
    def __init__(self, title, url):
        self.title = title.capitalize().replace(' ', '_')
        self.url = url

    def download_to(self, path):
        self.path = path
        dir = os.path.dirname(path)
        if not os.path.exists(dir):
            os.makedirs(dir)
        dl = urllib2.urlopen(self.url)
        f = open(path, 'wb')
        f.write(dl.read())
        f.close()

    def get_info(self):
        data = dict()
        data['name'] = self.title
        data['metadata'] = ''
        data['description'] = ''
        data['size'] = os.path.getsize(self.path)
        data['sha1'] = ''
        data['timestamp'] = datetime.now(pg.tz.LocalTimezone()) 
        data['width'] = 0
        data['height'] = 0
        data['bits'] = 0
        mime = mimetypes.guess_type(self.path)[0]
        if mime:
            bits = mime.split('/')
            data['major_mime'] = bits[0]
            data['minor_mime'] = bits[1]
        else:
            data['major_mime'] = 'unknown'
            data['minor_mime'] = 'unknown'
        if data['major_mime'] == 'image':
            data['media_type'] = 'BITMAP'
        else:
            data['media_type'] = 'UNKNOWN'
        return data



class HTMLPage:
    def __init__(self, id, title, wiki, path):
        self.id = id
        self.title = title
        self.wiki = wiki
        self.path = path
        self.subpages = list()
        self.files = list()

    def add_subpage(self, page):
        self.subpages.append(page)

    def add_file(self, file):
        self.files.append(file)

    def get_content(self):
        return self.wiki.get_page_content(self)

    def get_files(self):
        return self.wiki.get_page_files(self)

    def towiki(self):
        return html2wiki(self.get_content())


def reducechars(m):
    match = m.group()
    return match[:3] + match[-3:]

def html2wiki(html):
    cmd = os.path.join(os.getcwd(), 'convert.pl')
    converter = sp.Popen(cmd, stdin=sp.PIPE, stdout=sp.PIPE, stderr=sp.PIPE, shell=True)
    out, err = converter.communicate(input=html)
    if err:
        raise Exception(err)
    return out

