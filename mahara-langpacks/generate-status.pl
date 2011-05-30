#!/usr/bin/perl -w

use HTML::Tiny;
use POSIX qw(strftime ceil);

my $tarballs = $ARGV[0];
my $docroot  = $ARGV[1];

my @table = ();

my $last;
my $savefile = "$tarballs/mahara-langpacks.last";
if ( -f $savefile ) {
    eval(`cat $savefile`);
}

foreach my $lang (sort keys %{$last}) {
    my $l = $lang;
    my $c = { class => 'next' };
    foreach my $branch (sort keys %{$last->{$lang}->{branches}}) {
        my $status = [ \'span', { style => "color: #080" }, 'ok' ];
        if ( $last->{$lang}->{branches}->{$branch}->{status} == -1 ) {
            open $errorfh, '>', "$docroot/$lang-$branch-errors.txt";
            print $errorfh $last->{$lang}->{branches}->{$branch}->{errors};
            $status = [ \'a', { href => "$lang-$branch-errors.txt", style => "color: #a00;" }, 'errors' ];
        }
        push @table,
          [ \'tr', $c,
            [ \'td',
              { style => 'font-weight: bold;' }, $l, $branch,
              { style => 'font-weight: normal; color: #888;' }, [ \'tt', $last->{$lang}->{branches}->{$branch}->{commit} ],
              $status
            ]
          ];
        $l = '';
        $c = {};
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
