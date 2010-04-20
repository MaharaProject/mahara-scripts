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
import urllib2
import xml.etree.ElementTree as etree
from xml.sax.saxutils import unescape

# our library
from page import HTMLPage, File

class MTWiki:
    def __init__(self, baseurl):
        self.baseurl = baseurl

    def request(self, api_func):
        url = '%s/@api/deki/%s' % (self.baseurl, api_func)
        response = urllib2.urlopen(url)

        if response.msg != 'OK':
            raise Exception('ERROR: Mindtouch api request failed')

        return response.read()

    @staticmethod
    def generate_sitemap(root, wiki):
        id = root.get('id')
        title = root.find('title').text
        path = root.find('path').text
        page = HTMLPage(id, title, wiki, path)
        wiki.set_page_files(page)
        for subpage in root.find('subpages').findall('page'):
            page.add_subpage(MTWiki.generate_sitemap(subpage, wiki))
        return page

    def get_sitemap(self):
        root = etree.fromstring(self.request('pages')).find('page')
        self.homepage = self.generate_sitemap(root, self)
        self.homepage.path = self.homepage.title
        return self.homepage

    def get_page_content(self, page):
        response = etree.fromstring(
            self.request('pages/%s/contents' % page.id)
        )
        return unescape(response.find('body').text.strip())

    def set_page_files(self, page):
        response = etree.fromstring(
            self.request('pages/%s/files' % page.id)
        )
        files = response.findall('file');
        for file in files:
            page.add_file(File(
                file.find('filename').text,
                file.find('contents').get('href')
            ))

