#!/usr/bin/perl

use strict;
use warnings;
use File::Find;
use File::Slurp qw/slurp/;
use Text::Diff;

my $EXCLUDE_FILES = [
    qr{ .* test/                            }xms,
    qr{ .* htdocs/config.php                }xms,
    qr{ .* htdocs/tests                     }xms,
    qr{ .* htdocs/lib/adodb                 }xms,
    qr{ .* htdocs/lib/phpmailer             }xms,
    qr{ .* htdocs/lib/xmldb                 }xms,
    qr{ .* htdocs/lib/pieforms              }xms,
    qr{ .* htdocs/lib/smarty                }xms,
    qr{ .* htdocs/lib/ddl.php               }xms,
    qr{ .* htdocs/lib/dml.php               }xms,
    qr{ .* htdocs/lib/file.php              }xms,
    qr{ .* htdocs/lib/uploadmanager.php     }xms,
    qr{ .* htdocs/lib/xmlize.php            }xms,
    qr{ .* htdocs/lib/pear/                 }xms,
    qr{ .* htdocs/lib/htmlpurifier/         }xms,
    qr{ .* htdocs/lib/snoopy/               }xms,
    qr{ .*de\.utf8.* }xms,
];

my $FILE_HEADER = <<EOF;
<?php
/**
 * Mahara: Electronic portfolio, weblog, resume builder and social networking
 * Copyright (C) 2006-2008 Catalyst IT Ltd (http://www.catalyst.net.nz)
 *
 * This program is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this program.  If not, see <http://www.gnu.org/licenses/>.
 *
 * \@package    mahara
EOF

my $projectroot = $ARGV[0]; # This sucks, please improve!
my $language_strings = {};

#find( \&readlang, $projectroot );
find( \&process, $projectroot );

# loads language strings
#sub readlang {
#    my $filename = $_;
#    my $directory = $File::Find::dir;
#
#    return unless $directory =~ m{ lang/en.utf8/? \z }xms;
#    return unless $filename =~ m{ \A (.*)\.php \z }xms;
#    my $section = $1;
#    
#    my $file_data = slurp $directory . '/' . $filename;
#
#    while ( $file_data =~ m{ \$string\['(.*?)'\] \s+ = \s+ }xmsg ) {
#        $language_strings->{$section}{$1} = 1;
#    }
#}

sub process {
    my $filename = $_;
    my $directory = $File::Find::dir;
    $directory =~ s{ \A $projectroot }{}xms;
    $directory =~ s{ ([^/])$ }{$1/}xms;

    return unless $filename =~ m{ \.php \z }xms;

    foreach my $exclude_file ( @{$EXCLUDE_FILES} ) {
        return if ( ( $directory . $filename ) =~ $exclude_file );
    }

    my $file_data = slurp $projectroot . $directory . $filename;

    # check header
    if ( $FILE_HEADER ne substr ($file_data, 0, length $FILE_HEADER) ) {
        my $header = substr ($file_data, 0, length $FILE_HEADER);
        print $directory, $filename, " failed header check\n";
        print diff \$header, \$FILE_HEADER;
    }

    # check footer
    if ( $file_data !~ m{ \? > \n \z }xms ) {
        print $directory, $filename, " failed footer check\n";
    }

    # check subpackage
    if ( $file_data =~ m{ \@subpackage (.*?) $ }xms ) {
        my $subpackage_data = $1;
        unless (
            $subpackage_data =~ m{ \A \s* ( core | lang | tests | admin | xmlrpc | ( auth | form | artefact | notification | search | blocktype | interaction )(?:-.+)? ) \s* \z }xms
        ) {
            print $directory, $filename, " invalid \@subpackage '$subpackage_data'\n";
        }
    }
    else {
        print $directory, $filename, " missing \@subpackage\n";
    }

    # check author
    my $author;
    if ( $file_data =~ m{ \@author (.*?) $ }xms ) {
        my $author_data = $1;
        my $valid_authors = {
            Catalyst  => qr{ \s* Catalyst \s IT \s Ltd \s* }xms,
        };

        while ( my ($name, $regexp) = each %{$valid_authors} ) {
            $author = $name if ( $author_data =~ $regexp );
        }
        print $directory, $filename, " invalid \@author '$author_data'\n" unless defined $author;
    }
    else {
        print $directory, $filename, " missing \@author\n";
    }

    # check copyright
    if ( $file_data !~ m{\@copyright  \(C\) 2006-2008 Catalyst IT Ltd http://catalyst\.net\.nz} ) {
        print $directory, $filename, " missing \@copyright (or invalid)\n";
    }

    # check for json stuff
    if ($filename =~ m{.*\.json\.php}) {
	if ($file_data !~ m{define\('JSON',\s*1\)} ) {
	    print $directory, $filename, " appears to be a json script but doesn't define('JSON', 1);\n";
	}
	if ($file_data !~ m{json_reply} ) {
	    print $directory, $filename, " appears to be a json script but doesn't json_reply(); \n";
	}
	if ($file_data =~ m{json_headers} ) {
	    print $directory, $filename, " appears to call json_headers directly, it should use json_reply() instead \n";
	}
    }

    # check language strings
    # Commented out as it's quite buggy now...
    #while ( $file_data =~ m{ get_string\( ['"](.*?)['"] \s* (?: , \s* ['"](.*?)['"] )? .*? \)* }xmg ) {
    #    my ( $tag, $section ) = ( $1, $2 );

    #    next if ( $tag =~ m{ \$ }xms or ( defined $section and $section =~ m{ \$ }xms ) );
    #    next if ( defined $section and $section =~ m{ \.$ }xms );

    #    $section ||= 'mahara';

    #    unless ( exists $language_strings->{$section}{$tag} ) {
    #        print "($author) ", $directory, $filename, " has call to get_string that doesn't exist: get_string('$tag', '$section')\n";
    #    }
    #}

    # check for page titles
    if ( $file_data =~ m{define.*\(.*INTERNAL.*1.*\)} and $file_data !~ m{define.*\(.*JSON.*1.*\)} and $file_data !~ m{define.*\(.*TITLE.*\)} ) {
        print "($author) ", $directory, $filename, " is missing page title [ define('TITLE', get_string(...)); ]\n";
    }
}

