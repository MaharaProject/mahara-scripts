#!/usr/bin/perl -w

# Updates a Mahara .po translation with changes from a new .pot
# template.

# Changes to the msgid in the .pot are considered unimportant unless
# the mahara string key (stored as msgctxt and reference in the .pot
# file) has also changed.

# For example:
# po-po.pl /path/to/po/file/fr.po /path/to/pot/file/mahara.pot /path/to/output/files/fr.po

use Locale::PO;
use Data::Dumper;

my ($po, $pot, $outputfile) = @ARGV;

open my $fh, '>', $outputfile or die "Cannot write to $outputfile";
close $fh;

# Locale::PO's load_file_ashash claims to use msgid as the key, but
# that's no good here, our unique key is msgctxt/reference, so just
# load the .pot entries as an array and build a hash afterwards.
my $enstrings = Locale::PO->load_file_asarray($pot);
my %enstrings = ();

foreach my $entry (@$enstrings) {
    my $reference = $entry->reference();

    next if ( ! defined $reference );

    $reference = $entry->dequote($reference);

    if ( length $reference ) {
        $enstrings{$reference} = $entry;
    }
}

# Go through the translated strings.  If an entry specifies a
# reference that already appears in the pot file, and the msgid has
# changed, update the msgid to the one from the pot.  We're assuming
# that important updates to English strings will have changed the
# reference.
my $trstrings = Locale::PO->load_file_asarray($po);
my $updated = [];

foreach my $entry (@$trstrings) {
    my $reference = $entry->reference();

    # Somewhere along the line, imports fail when launchpad decides to
    # insert a line break inside msgstr and it falls between e.g. \
    # and ' in a commented-out (obsolete) translation, so just skip
    # all the obsolete translations
    next if ( $entry->obsolete() );

    # Check whether the string is translated.  If not, we can leave it
    # out of the file.
    my $content = $entry->msgstr();
    my $content_n = $entry->msgstr_n();

    next if ( ! defined $content && ! defined $content_n );

    if ( defined $content ) {
        # Non-plural translation
        next if ( $content eq '' || $content eq '""' );
    }
    if ( defined $content_n ) {
        # Translation with plural forms.  If all forms are
        # untranslated, we can leave this entry out of the file.
        my $anything = 0;
        foreach my $k ( keys %$content_n ) {
            $anything ||= ($content_n->{$k} ne '' && $content_n->{$k} ne '""');
        }
        next if ! $anything;
    }

    if ( defined $reference ) {

        $reference = $entry->dequote($reference);

        if ( length $reference && defined $enstrings{$reference} ) {
            $pot_msgid = $entry->dequote($enstrings{$reference}->msgid);
            $po_msgid = $entry->dequote($entry->msgid);

            if ( $po_msgid && $pot_msgid && $po_msgid ne $pot_msgid ) {
                $entry->msgid($pot_msgid);
            }
        }
    }

    push @$updated, $entry;
}

Locale::PO->save_file_fromarray("$outputfile", $updated);
