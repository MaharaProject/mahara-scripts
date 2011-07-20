#!/usr/bin/perl -w

use HTML::Tiny;
use POSIX qw(strftime ceil);

my $docroot = $ARGV[0];

my $lastlang = '0';
my @tarballs = `find $docroot -name "*.tar.gz"`;
my @table = ();

foreach my $tarball (sort @tarballs) {
    chomp $tarball;
    if ($tarball =~ m{$docroot/([a-zA-Z_]+)-([0-9A-Za-z\._]+)\.tar\.gz}) {
        my $lang = $1;
        my $branch = $2;
        my @fileinfo = stat $tarball;
        my $l = '';
        my $c = {};
        if ( $lang ne $lastlang ) {
            $l = $lang;
            $c = { class => 'next' };
        }
        push @table,
          [ \'tr', $c,
            [ \'td',
              { style => 'font-weight: bold;' }, $l,
              [ \'a', { href => "$lang-$branch.tar.gz" }, "$lang-$branch.tar.gz" ],
              { style => 'font-weight: normal; color: #888;' },
              strftime("%Y-%m-%d %H:%M:%S", localtime $fileinfo[9]), ceil($fileinfo[7] / 1024 - 0.5) . 'k'
            ]
          ];
        $lastlang = $lang;
    }
}

open(my $fh, '>', "$docroot/index.html") or die $!;

my $h = HTML::Tiny->new( mode => 'html' );

print $fh $h->html(
  [
    $h->head(
      [
        $h->title( 'Mahara Language Packs' ),
        $h->style( 'td,th {padding:0 .5em;} tr.next td {border-top: 1px dotted #ccc;}' ),
      ]
    ),
    $h->body(
      [
        $h->div( { style => "float: right; margin-right: 1em;" }, [ \'a', { href => 'status.html' }, 'Status' ] ),
        $h->h3( 'Mahara Language Packs' ),
        $h->table(\@table),
      ]
    )
  ]
);
