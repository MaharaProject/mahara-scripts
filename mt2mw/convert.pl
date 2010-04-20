#! /usr/bin/env perl

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


@input = <STDIN>;

use HTML::WikiConverter;
use Config::Simple;

$cfg = new Config::Simple('config.ini');
$url = $cfg->param('config.mindtouch_url');

$html = join(' ', @input);
$wc = new HTML::WikiConverter(
    dialect => 'MediaWiki',
    base_uri => $url, 
    wiki_uri => $url, 
);
print $wc->html2wiki(html => $html);

