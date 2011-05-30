#!/usr/bin/perl -w

# Copyright (C) 2010 Catalyst IT Ltd
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or
# (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with this program.  If not, see <http://www.gnu.org/licenses/>.

use Data::Dumper;
use FindBin;
use File::Path qw(make_path remove_tree);

foreach my $c qw(DATA DOCROOT) {
    exists $ENV{$c} or die ("\$ENV{$c} undefined");
}

my $DATA      = $ENV{DATA};
my $DOCROOT   = $ENV{DOCROOT};

my $CLEANCMD  = "/usr/bin/php $FindBin::Bin/langpack.php";
my $SYNTAXCMD = "/usr/bin/php -l";
my $UTF8CMD   = "/usr/bin/perl $FindBin::Bin/check-utf8.pl";
my $POCMD     = "/usr/bin/perl $FindBin::Bin/po-php.pl";

my $GITDIR    = "${DATA}/git";
my $DIRTY     = "${DATA}/old";
my $CLEAN     = "${DATA}/new";
my $TARBALLS  = "${DATA}/tarballs";

make_path $GITDIR;
make_path $DIRTY;
make_path $CLEAN;
make_path $TARBALLS;

print STDERR "Checking langpacks for updates: " . `date \"+%Y-%m-%d %H:%M:%S\"`;

my @langs = qw(ar ca cs da de en_us es eu fi fr he it ja ko nl no_nb sl zh_tw);

my $last;
my $savefile = "$TARBALLS/mahara-langpacks.last";
if ( -f $savefile ) {
    eval(`cat $savefile`);
}
else {
    $last = {};
}

foreach my $lang (@langs) {

    if ( ! defined $last->{$lang} ) {
        $last->{$lang} = { repo => "git://gitorious.org/mahara-lang/$lang.git" };
    }

    my $remote       = $last->{$lang}->{repo};
    my $gitlangdir   = "$GITDIR/$lang";
    my $dirtylangdir = "$DIRTY/$lang";
    my $cleanlangdir = "$CLEAN/$lang";

    if ( ! -d $gitlangdir ) {
        system "git clone --quiet $remote $gitlangdir";
    }

    make_path $dirtylangdir;
    make_path $cleanlangdir;

    chdir $gitlangdir;
    system "git fetch --quiet";

    my $remotebranchcmd = 'git branch -r | grep -v "HEAD" | grep "origin\/\(master\|1.2_STABLE\|1.3_STABLE\|1.4_STABLE\)$"';
    my $remotebranches = `$remotebranchcmd`;
    $remotebranches =~ s/\s+/ /;

    foreach my $remotebranch (split(" ", $remotebranches)) {

        my $remotecommitcmd = 'git log --pretty=format:"%H %ai %an" ' . $remotebranch . ' | head -1';
        my $remotecommit = `$remotecommitcmd`;
        chomp $remotecommit;

        my $localbranch = $remotebranch;
        $localbranch =~ s/^origin\///;

        if ( ! defined $last->{$lang}->{branches}->{$localbranch} ) {
            $last->{$lang}->{branches}->{$localbranch} = {};
        }

        my $filenamebase = "$lang-$localbranch";
        my $tarball = "$TARBALLS/$filenamebase.tar.gz";
        my $diff    = "$TARBALLS/$filenamebase.diff";

        -f $tarball && unlink $tarball;
        -f $diff && unlink $diff;

        my $lastruncommit = '';

        if ( defined $last->{$lang}->{branches}->{$localbranch}->{commit} ) {
            $lastruncommit = $last->{$lang}->{branches}->{$localbranch}->{commit};
        }

        if ( "$remotecommit" ne "$lastruncommit" ) {
            print STDERR "Updating $lang $localbranch\n";

            my $branchcmd = 'git branch | grep "' . $localbranch . '$"';
            my $branchexists = `$branchcmd`;

            if ( length $branchexists ) {
                system "git checkout --quiet $localbranch";
                system "git reset --hard -q $remotebranch";
            } else {
                system "git checkout --quiet -b $localbranch $remotebranch";
            }

            $last->{$lang}->{branches}->{$localbranch}->{status} = 0;
            $last->{$lang}->{branches}->{$localbranch}->{errors} = '';

            my $cleanbranchdir = "$cleanlangdir/$localbranch";
            -d "$cleanbranchdir/lang" && remove_tree $cleanbranchdir;
            ! -d $cleanbranchdir && make_path $cleanbranchdir;

            my $pofile = "$gitlangdir/mahara/$lang.po";

            if ( -f $pofile ) {

                print STDERR "$lang $localbranch: using .po file\n";

                # Check utf8ness of .po file?
                my $output = `$UTF8CMD $pofile`;
                if ( length $output ) {
                    $last->{$lang}->{branches}->{$localbranch}->{errors} = "$pofile\n$output";
                    $last->{$lang}->{branches}->{$localbranch}->{status} = -1;
                }

                # Create langpack from .po file
                my $pocmd = "$POCMD $pofile $cleanbranchdir \"$lang.utf8\"";
                $output = `$pocmd`;

                if ( length $output ) {
                    $last->{$lang}->{branches}->{$localbranch}->{errors} .= "Failed to create langpack from .po file $pofile\n";
                    $last->{$lang}->{branches}->{$localbranch}->{errors} .= "$output";
                    $last->{$lang}->{branches}->{$localbranch}->{status} = -1;
                }

            } else {

                print STDERR "$lang $localbranch: sanitising\n";

                # sanitise langpack
                my $dirtybranchdir = "$dirtylangdir/$localbranch";
                ! -d $dirtybranchdir && make_path $dirtybranchdir;

                system("cp -r $gitlangdir/" . '[a-z]* ' . $dirtybranchdir);

                # Clean out stray php from the langpacks
                system "$CLEANCMD $dirtybranchdir $cleanbranchdir";

                chdir $DATA;
                system "diff -Bwr $dirtybranchdir $cleanbranchdir > $diff";

                # Check syntax of php files
                chdir $cleanbranchdir;
                my $phpfiles = `find . -name \"\*.php\"`;
                foreach my $phpfile (split("\n", $phpfiles)) {
                    $phpfile =~ s/^\s*(\S.*\S)\s*$/$1/;
                    if ( $phpfile =~ m/php$/ ) {
                        my $output = `$SYNTAXCMD $phpfile >/dev/null`;
                        if ( length $output ) {
                            $last->{$lang}->{branches}->{$localbranch}->{errors} = "$phpfile\n$output";
                            $last->{$lang}->{branches}->{$localbranch}->{status} = -1;
                        }
                    }
                }

                my $allfiles = `find .`;

                # Check utf8ness of all files
                foreach my $file (split("\n", $allfiles)) {
                    $file =~ s/^\s*(\S.*\S)\s*$/$1/;
                    $output = `$UTF8CMD $file`;
                    if ( length $output ) {
                        $last->{$lang}->{branches}->{$localbranch}->{errors} .= "$file\n$output";
                        $last->{$lang}->{branches}->{$localbranch}->{status} = -1;
                    }
                }
            }

            if ( $last->{$lang}->{branches}->{$localbranch}->{status} == 0 ) {
                my $strip = $cleanbranchdir;
                $strip =~ s{$/}{};
                system "tar --transform \"s,$strip,$lang.utf8,\" -zcf $tarball $cleanbranchdir";
            }

            chdir $gitlangdir;

            my $localcommit = `git log --pretty=format:\"%H %ai %an\" $localbranch | head -1`;
            chomp $localcommit;
            $last->{$lang}->{branches}->{$localbranch}->{commit} = $localcommit;
        }
    }
}

# Move new tarballs & log files to web directory
foreach my $file (split /\n/, `find $TARBALLS -name \"\*.tar.gz\"`) {
    system "mv $file $DOCROOT";
}

foreach my $file (split /\n/, `find $TARBALLS -name \"\*.diff\"`) {
    my $base = $file;
    $base =~ s{^.*/([^/\s]+)\.diff\s*$}{$1};
    system "mv $file $DOCROOT/$base-diff.txt";
}

# Generate index.html
system "/usr/bin/perl $FindBin::Bin/generate-index.pl $DOCROOT";

# Save latest commits
open $savefh, '>', $savefile;
print $savefh Data::Dumper->Dump([$last], ['last']);

# Generate status.html
system "/usr/bin/perl $FindBin::Bin/generate-status.pl $TARBALLS $DOCROOT";

print STDERR "Done.\n";
