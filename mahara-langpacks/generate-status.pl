#!/usr/bin/perl -w

use HTML::Tiny;
use POSIX qw(strftime ceil);

my $tarballs = $ARGV[0];
my $docroot  = $ARGV[1];

my $lastlang = '0';
my @last = `find $tarballs -name "*.last"`;
my @table = ();

foreach my $last (sort @last) {
    chomp $last;
    if ($last =~ m{$tarballs/([a-z_]+)-([0-9A-Za-z\._]+)\.last}) {
        my $lang = $1;
        my $branch = $2;
        my $commitinfo = `cat $last`;
        my $l = '';
        my $c = {};
        if ( $lang ne $lastlang ) {
            $l = $lang;
            $c = { class => 'next' };
        }
        my $errors = -f "$docroot/$lang-$branch-errors.txt";
        push @table,
          [ \'tr', $c,
            [ \'td',
              { style => 'font-weight: bold;' }, $l, $branch,
              { style => 'font-weight: normal; color: #888;' }, [ \'tt', $commitinfo ],
              $errors ? [ \'a', { href => "$lang-$branch-errors.txt", style => "color: #a00;" }, 'errors' ] : [ \'span', { style => "color: #080" }, 'ok' ]
            ]
          ];
        $lastlang = $lang;
    }
}

open(my $fh, '>', "$docroot/status.html") or die $!;

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
        $h->div( { style => "float: right; margin-right: 1em;" }, [ \'a', { href => 'index.html' }, 'Download' ] ),
        $h->h3( 'Mahara Language Packs' ),
        $h->table(\@table),
      ]
    )
  ]
);
