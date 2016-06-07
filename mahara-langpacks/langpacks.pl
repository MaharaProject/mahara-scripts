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

###########################
# Mahara langpacks generation file.
#
# This script pulls the latest .po translation files from all the translation
# branches, processes them into Mahara language files, and compresses them
# into tarballs.
#
# NOTE: It contains multiple hard-coded lists of branch names to get translations
# from. Whenever there's a new Mahara series, you'll need to manually update those
# lists. Each one has been tagged with this comment:
#
#     # @UPDATE when there is a new series
#

use Data::Dumper;
use FindBin;
use File::Path qw(mkpath rmtree);
use LWP::UserAgent;

foreach my $c (qw(DATA DOCROOT SCRIPTS)) {
    exists $ENV{$c} or die ("\$ENV{$c} undefined");
}

my $DATA      = $ENV{DATA};
my $DOCROOT   = $ENV{DOCROOT};
my $SCRIPTS   = $ENV{SCRIPTS};

my $CLEANCMD  = "/usr/bin/php $FindBin::Bin/clean-php.php";
my $SYNTAXCMD = "/usr/bin/php -l";
my $UTF8CMD   = "/usr/bin/perl $FindBin::Bin/check-utf8.pl";
my $POCMD     = "/usr/bin/perl $FindBin::Bin/po-php.pl";

my $GITDIR    = "${DATA}/git";
my $BZRDIR    = "${DATA}/bzr";
my $DIRTY     = "${DATA}/old";
my $CLEAN     = "${DATA}/new";
my $TARBALLS  = "${DATA}/tarballs";
my $MAHARA    = "${DATA}/mahara";

my $MAHARAREMOTE = 'https://git.mahara.org/mahara/mahara.git';
my $REPOLIST     = 'https://git.mahara.org/scripts/mahara-scripts/raw/master/mahara-langpacks/language-repos.txt';

mkpath $GITDIR;
mkpath $DIRTY;
mkpath $CLEAN;
mkpath $TARBALLS;

print STDERR "Checking langpacks for updates: " . `date \"+%Y-%m-%d %H:%M:%S\"`;

# A language repo list can be put in the $DATA dir for testing.  If there's not one
# there, try to get an up-to-date one out of the mahara-scripts repository
# (allows updates to the repo list without having to redeploy the package).
my $repolist;
if ( -f "$DATA/language-repos.txt" ) {
    print STDERR "Using repository list in $DATA/language-repos.txt\n";
    open $repofh, '<', "$DATA/language-repos.txt" or die $!;
    local $/ = undef;
    $repolist = <$repofh>;
}
else {
    print STDERR "Retrieving repository list from $REPOLIST\n";

    my $ua = LWP::UserAgent->new;
    $ua->timeout(10);
    $ua->env_proxy;
    my $response = $ua->get($REPOLIST);
    $repolist = $response->is_success ? $response->content : undef;

    if ( ! defined $repolist ) {
        print STDERR "Failed to get language list, exiting.\n";
        exit;
    }
}

my %langs = ();
if ( defined $repolist ) {
    foreach ( split "\n", $repolist ) {
        if ( m/^([a-zA-Z_]{2,5})\s+(\S+)\s*$/ ) {
            $langs{$1} = { repo => $2 };
        }
    }
}

my @langkeys = sort keys %langs;
if ( scalar @langkeys < 1 ) {
    @langkeys = qw(ar ca cs da de el en_GB en_us es eu fi fr he it ja ko mi nl nb ru sl zh_TW);
}

print STDERR "Languages: " . join(' ', @langkeys) . "\n";

my $last;
my $savefile = "$TARBALLS/mahara-langpacks.last";
if ( -f $savefile ) {
    eval(`cat $savefile`);
}
else {
    $last = {};
}


# Mahara checkout, used for reading the en.utf8 langpack
# during php langpack sanitisation.
! -d "$MAHARA" && system "git clone --quiet $MAHARAREMOTE $MAHARA";
chdir $MAHARA;
system "git fetch --quiet origin";


# For launchpad, all languages are in a single branch, so update the lot
system "bzr launchpad-login dev-mahara";
! -d $BZRDIR && system "bzr init-repo $BZRDIR";
# @UPDATE when there is a new series
my @branches = qw(1.10_STABLE 15.04_STABLE 15.10_STABLE 16.04_STABLE master);

foreach my $branch (@branches) {
    if ( ! -d "$BZRDIR/$branch" ) {
        system "bzr branch lp:~mahara-lang/mahara-lang/$branch-export $BZRDIR/$branch";
    }
    else {
        chdir "$BZRDIR/$branch";
        system "bzr pull";
    }
}

foreach my $lang (@langkeys) {

    if ( ! defined $last->{$lang} ) {
        $last->{$lang} = { repo => "https://git.mahara.org/lang-old/$lang.git" };
    }

    if ( defined $langs{$lang}->{repo} ) {
        $last->{$lang}->{repo} = $langs{$lang}->{repo};
    }

    my $repotype;
    my $remote       = $last->{$lang}->{repo};
    my $gitlangdir   = "$GITDIR/$lang";
    my $dirtylangdir = "$DIRTY/$lang";
    my $cleanlangdir = "$CLEAN/$lang";

    mkpath $dirtylangdir;
    mkpath $cleanlangdir;


    if ( $remote =~ m/^lp:mahara-lang/ ) {
        $repotype = 'launchpad';
        # @UPDATE when there is a new series
        @branches = qw(1.10_STABLE 15.04_STABLE 15.10_STABLE 16.04_STABLE master);
    }
    elsif ( $remote =~ m{^https://git\.mahara\.org|^https://gitlab\.com} ) {
        $repotype = 'git';
        ! -d "$gitlangdir" && system "git clone --quiet $remote $gitlangdir";
        chdir $gitlangdir;
        system "git fetch --quiet";
        # @UPDATE when there is a new series
        # When adding a new branch name here, make sure to preface it with 
        # "\|", that is, a backslash, then a pipe.
        my $remotebranchcmd = 'git branch -r | grep -v "HEAD" | grep "origin\/\(master\|1.10_STABLE\|15.04_STABLE\|15.10_STABLE\|16.04_STABLE\)$"';
        my $remotebranches = `$remotebranchcmd`;
        $remotebranches =~ s/\s+/ /;
        @branches = ();
        foreach my $b (split(" ", $remotebranches)) {
            $b =~ s{^origin/}{};
            push @branches, $b;
        }
    }
    else {
        print STDERR "Don't know what to do with $remote; skipping $lang\n";
        next;
    }

    foreach my $branch (@branches) {

        my $remotecommit;
        my $currentdir;
        if ( $repotype eq 'launchpad' ) {
            $currentdir = "$BZRDIR/$branch";
            chdir $currentdir;
            next if ! -f "$currentdir/mahara/$lang.po";
            my $remotecommitcmd = "bzr log --line mahara/$lang.po | head -1";
            $remotecommit = `$remotecommitcmd`;
        }
        else {
            my $remotecommitcmd = 'git log --pretty=format:"%H %ai %an" origin/' . $branch . ' | head -1';
            $remotecommit = `$remotecommitcmd`;
            $currentdir = $gitlangdir;
            chdir $currentdir;
        }
        chomp $remotecommit;

        if ( ! defined $last->{$lang}->{branches}->{$branch} ) {
            $last->{$lang}->{branches}->{$branch} = {};
        }

        my $filenamebase = "$lang-$branch";
        my $tarball = "$TARBALLS/$filenamebase.tar.gz";
        my $diff    = "$TARBALLS/$filenamebase.diff";

        -f $tarball && unlink $tarball;
        -f $diff && unlink $diff;

        my $lastruncommit = '';

        if ( defined $last->{$lang}->{branches}->{$branch}->{commit} ) {
            $lastruncommit = $last->{$lang}->{branches}->{$branch}->{commit};
        }

        if ( "$remotecommit" ne "$lastruncommit" ) {
            print STDERR "Updating $lang $branch\n";

            if ( $repotype eq 'git' ) {
                my $branchcmd = 'git branch | grep "' . $branch . '$"';
                my $branchexists = `$branchcmd`;

                if ( length $branchexists ) {
                    system "git checkout --quiet $branch";
                    system "git reset --hard -q origin/$branch";
                }
                else {
                    system "git checkout --quiet -b $branch origin/$branch";
                }
            }

            $last->{$lang}->{branches}->{$branch}->{status} = 0;
            $last->{$lang}->{branches}->{$branch}->{errors} = '';

            my $cleanbranchdir = "$cleanlangdir/$branch";
            -d "$cleanbranchdir/lang" && rmtree $cleanbranchdir;
            ! -d $cleanbranchdir && mkpath $cleanbranchdir;

            my $pofile = "$currentdir/mahara/$lang.po";

            if ( -f $pofile ) {

                $last->{$lang}->{branches}->{$branch}->{type} = 'po';

                print STDERR "$lang $branch: using .po file\n";

                # Check utf8ness of .po file?
                my $output = `$UTF8CMD $pofile`;
                if ( length $output ) {
                    $last->{$lang}->{branches}->{$branch}->{errors} = "$pofile\n$output";
                    $last->{$lang}->{branches}->{$branch}->{status} = -1;
                }

                # Create langpack from .po file
                my $pocmd = "$POCMD $pofile $cleanbranchdir \"$lang.utf8\"";
                $output = `$pocmd`;

                if ( length $output ) {
                    $last->{$lang}->{branches}->{$branch}->{errors} .= "Failed to create langpack from .po file $pofile\n";
                    $last->{$lang}->{branches}->{$branch}->{errors} .= "$output";
                    $last->{$lang}->{branches}->{$branch}->{status} = -1;
                }

            }
            elsif ( $repotype eq 'git' ) {

                # .po is not available, so this is a php langpack

                my $langconfig = 0;

                if ( $lang =~ m/^([a-z]{2})_([a-z]{2})$/ ) {
                    $langconfig = -f "$currentdir/lang/$1_" . lc($2) . '.utf8/langconfig.php'
                      || -f "$currentdir/lang/$1_" . uc($2) . '.utf8/langconfig.php';
                }
                else {
                    $langconfig = -f "$currentdir/lang/$lang.utf8/langconfig.php";
                }

                if ( ! $langconfig ) {
                    print STDERR "$lang $branch: Couldn't find lang/$lang.utf8/langconfig.php in $currentdir; skipping\n";
                    next;
                }

                $last->{$lang}->{branches}->{$branch}->{type} = 'mahara';

                print STDERR "$lang $branch: sanitising\n";

                # sanitise langpack
                my $dirtybranchdir = "$dirtylangdir/$branch";
                ! -d $dirtybranchdir && mkpath $dirtybranchdir;

                system("cp -r $currentdir/" . '[a-z]* ' . $dirtybranchdir);

                # Make en.utf8 available
                chdir $MAHARA;
                system "git reset --hard -q origin/$branch";

                # Clean out stray php from the langpacks
                system "$CLEANCMD $MAHARA/htdocs $dirtybranchdir $cleanbranchdir";

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
                            $last->{$lang}->{branches}->{$branch}->{errors} = "$phpfile\n$output";
                            $last->{$lang}->{branches}->{$branch}->{status} = -1;
                        }
                    }
                }

                my $allfiles = `find .`;

                # Check utf8ness of all files
                foreach my $file (split("\n", $allfiles)) {
                    $file =~ s/^\s*(\S.*\S)\s*$/$1/;
                    $output = `$UTF8CMD $file`;
                    if ( length $output ) {
                        $last->{$lang}->{branches}->{$branch}->{errors} .= "$file\n$output";
                        $last->{$lang}->{branches}->{$branch}->{status} = -1;
                    }
                }
            }
            else {
                print STDERR "$lang $branch: Couldn't find mahara/$lang.po or lang/$lang.utf8/langconfig.php in $currentdir; skipping\n";
                next;
            }

            if ( $last->{$lang}->{branches}->{$branch}->{status} == 0 ) {
                my $strip = $cleanbranchdir;
                $strip =~ s{^/}{^};
                system "tar --transform \"s,$strip,$lang.utf8,\" -zcf $tarball $cleanbranchdir";
            }

            chdir $currentdir;

            my $localcommit;
            if ( $repotype eq 'git' ) {
                $localcommit = `git log --pretty=format:\"%H %ai %an\" $branch | head -1`;
            }
            else {
                $localcommit = `bzr log --line mahara/$lang.po | head -1`;
            }
            chomp $localcommit;
            $last->{$lang}->{branches}->{$branch}->{commit} = $localcommit;
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
