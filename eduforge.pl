#!/usr/bin/perl
# One-off script to pull bugs out of eduforge and format for launchpad import.

use DBI;
use Data::Dumper;
use XML::LibXML;
use Date::Format;
use HTML::Entities;

my $bugsql = "SELECT
       a.artifact_id,
       a.group_artifact_id,
       a.status_id,
       a.summary,
       a.details,
       a.priority,
       a.open_date,
       a.last_modified_date,
       submitter.realname AS submittername,
       submitter.email AS submitteremail,
       assignee.realname  AS assigneename,
       assignee.email  AS assigneeemail,
       dbtypeelement.element_name AS dbtype,
       resolutionelement.element_name AS resolution,
       versionelement.element_name AS version,
       categoryelement.element_name AS category
FROM
       artifact a
       LEFT JOIN users submitter ON (a.submitted_by = submitter.user_id)
       LEFT JOIN users assignee ON (a.assigned_to = assignee.user_id)

       LEFT JOIN artifact_extra_field_data dbtypedata ON (a.artifact_id = dbtypedata.artifact_id AND dbtypedata.extra_field_id = 1803 AND dbtypedata.field_data <> 100)
       LEFT JOIN artifact_extra_field_elements dbtypeelement ON (dbtypedata.field_data = dbtypeelement.element_id AND dbtypeelement.element_id <> 100)

       LEFT JOIN artifact_extra_field_data resolutiondata ON (a.artifact_id = resolutiondata.artifact_id AND resolutiondata.extra_field_id = 1498)
       LEFT JOIN artifact_extra_field_elements resolutionelement ON (resolutiondata.field_data = resolutionelement.element_id)

       LEFT JOIN artifact_extra_field_data versiondata ON (a.artifact_id = versiondata.artifact_id AND versiondata.extra_field_id = 1497 AND versiondata.field_data <> 100)
       LEFT JOIN artifact_extra_field_elements versionelement ON (versiondata.field_data = versionelement.element_id AND versionelement.element_id <> 100)

       LEFT JOIN artifact_extra_field_data categorydata ON (a.artifact_id = categorydata.artifact_id AND categorydata.extra_field_id = 1496 AND categorydata.field_data <> 100)
       LEFT JOIN artifact_extra_field_elements categoryelement ON (categorydata.field_data = categoryelement.element_id AND categoryelement.element_id <> 100)
WHERE
       a.group_artifact_id = 739
       -- AND a.artifact_id >= 3420 -- testing
       AND a.status_id <> 3
       AND resolutiondata.field_data NOT IN (2642)
       -- AND resolutiondata.field_data NOT IN (2431,2432,2433,2434,2597,2641,2642)";

my $frsql = "SELECT
       a.artifact_id,
       a.group_artifact_id,
       a.status_id,
       a.summary,
       a.details,
       a.priority,
       a.open_date,
       a.last_modified_date,
       submitter.realname AS submittername,
       submitter.email AS submitteremail,
       assignee.realname  AS assigneename,
       assignee.email  AS assigneeemail,
       resolutionelement.element_name AS resolution,
       versionelement.element_name AS version,
       categoryelement.element_name AS category
FROM
       artifact a
       LEFT JOIN users submitter ON (a.submitted_by = submitter.user_id)
       LEFT JOIN users assignee ON (a.assigned_to = assignee.user_id)

       LEFT JOIN artifact_extra_field_data resolutiondata ON (a.artifact_id = resolutiondata.artifact_id AND resolutiondata.extra_field_id = 1748)
       LEFT JOIN artifact_extra_field_elements resolutionelement ON (resolutiondata.field_data = resolutionelement.element_id)

       LEFT JOIN artifact_extra_field_data versiondata ON (a.artifact_id = versiondata.artifact_id AND versiondata.extra_field_id = 1504 AND versiondata.field_data <> 100)
       LEFT JOIN artifact_extra_field_elements versionelement ON (versiondata.field_data = versionelement.element_id AND versionelement.element_id <> 100)

       LEFT JOIN artifact_extra_field_data categorydata ON (a.artifact_id = categorydata.artifact_id AND categorydata.extra_field_id = 1503 AND categorydata.field_data <> 100)
       LEFT JOIN artifact_extra_field_elements categoryelement ON (categorydata.field_data = categoryelement.element_id AND categoryelement.element_id <> 100)
WHERE
       a.group_artifact_id = 742
       -- AND a.artifact_id >= 3420 -- testing
       AND a.status_id <> 3
       AND resolutiondata.field_data NOT IN (2815)
       -- AND resolutiondata.field_data NOT IN (2815, 2814, 2813, 2812, 2811, 2810, 2809)
";

my $dbh = DBI->connect("dbi:Pg:dbname=eduforge", "gforge", "xxxxxxxx") or croak("Cannot connect to db");
my $bugs = $dbh->selectall_hashref($bugsql, 'artifact_id');
my $frs  = $dbh->selectall_hashref($frsql, 'artifact_id');

foreach my $frid ( keys %$frs ) {
    $bugs->{$frid} = $frs->{$frid};
}

my $idlist = join(',', keys %$bugs);
my $commentsql = "
    SELECT m.*, s.realname AS commentername, s.user_name AS commenterusername
    FROM artifact_message m
    LEFT JOIN users s ON m.submitted_by = s.user_id
    WHERE artifact_id IN ($idlist)";
my $comments  = $dbh->selectall_hashref($commentsql, 'id');

foreach my $id ( keys %$comments ) {
    push @{$bugs->{$comments->{$id}{artifact_id}}{comments}}, $comments->{$id};
}

my $filesql = "
    SELECT f.*, s.realname AS submittername, s.email AS submitteremail
    FROM artifact_file f
    LEFT JOIN users s ON f.submitted_by = s.user_id
    WHERE artifact_id IN ($idlist)";
my $files  = $dbh->selectall_hashref($filesql, 'id');

foreach my $id ( keys %$files ) {
    push @{$bugs->{$files->{$id}{artifact_id}}{files}}, $files->{$id};
}

$dbh->disconnect();

my @importance = qw( LOW LOW LOW MEDIUM MEDIUM HIGH );

my %statuses = (
    'Accepted' => 'CONFIRMED',
    'None' => 'NEW',
    'Duplicate' => 'UNKNOWN',
    'Fixed' => 'FIXRELEASED',
    'Pending' => 'FIXRELEASED',
    'Out of date' => 'INVALID',
    'Postponed' => 'UNKNOWN',
    'Works For Me' => 'INVALID',
    'Rejected' => 'INVALID',
);

# my $dom = XML::LibXML::Document->new('1.0', 'UTF-8');
my $dom = XML::LibXML::Document->new();
my $rootnode = $dom->createElement('launchpad-bugs');
$rootnode->setNamespace("https://launchpad.net/xmlns/2006/bugs");
$dom->setDocumentElement($rootnode);

foreach my $id ( keys %$bugs ) {
    my $bug = $dom->createElement('bug');
    $bug->setAttribute('id', $id);
    $bug->setNamespace("https://launchpad.net/xmlns/2006/bugs");

    my $e = $dom->createElement('datecreated');
    $e->appendTextNode(time2str("%Y-%m-%dT%H:%M:%SZ", $bugs->{$id}{open_date}));
    $bug->appendChild($e);

    my $type = $bugs->{$id}{group_artifact_id} == 742 ? 'feature-request' : 'bug';
    $e = $dom->createElement('nickname');
    $e->appendTextNode("mahara-eduforge-$type-$bugs->{$id}->{artifact_id}");
    $bug->appendChild($e);

    $e = $dom->createElement('title');
    $e->appendTextNode($bugs->{$id}{summary});
    $bug->appendChild($e);

    my $url = "https://eduforge.org/tracker/index.php?func=detail&aid=$bugs->{$id}->{artifact_id}&group_id=176&atid=$bugs->{$id}->{group_artifact_id}";

    my $note = "This bug was imported from eduforge.org, see:\n$url\n";

    $e = $dom->createElement('description');
    $e->appendTextNode(decode_entities($bugs->{$id}{details}) . "\n\n$note");
    $bug->appendChild($e);

    $e = $dom->createElement('reporter');
    $e->setAttribute('email', $bugs->{$id}{submitteremail});
    $e->appendTextNode($bugs->{$id}{submittername});
    $bug->appendChild($e);

    if ( $bugs->{$id}{assigneeemail} ne 'noreply@sourceforge.net' or $bugs->{$id}{assigneename} ne 'Nobody' ) {
        $e = $dom->createElement('assignee');
        $e->setAttribute('email', $bugs->{$id}{assigneeemail});
        $e->appendTextNode($bugs->{$id}{assigneename});
        $bug->appendChild($e);
    }

    $e = $dom->createElement('status');
    $e->appendTextNode($statuses{$bugs->{$id}{resolution}} || 'UNKONWN');
    $bug->appendChild($e);

    $e = $dom->createElement('importance');
    $e->appendTextNode($type eq 'feature-request' ? 'WISHLIST' : $importance[$bugs->{$id}{priority}]);
    $bug->appendChild($e);

    $tags = $dom->createElement('tags');
    $e = $dom->createElement('tag');
    $e->appendTextNode("mahara-eduforge-$type");
    $tags->appendChild($e);
    $bug->appendChild($tags);

    $urls = $dom->createElement('urls');
    $e = $dom->createElement('url');
    $e->setAttribute('href', $url);
    $e->appendTextNode($url);
    $urls->appendChild($e);
    $bug->appendChild($urls);

    # Launchpad requires at least one comment
    # Create an initial comment containing the bug description
    $cnode = $dom->createElement('comment');

    $e = $dom->createElement('sender');
    $e->setAttribute('email', $bugs->{$id}{submitteremail});
    $e->appendTextNode($bugs->{$id}{submittername});
    $cnode->appendChild($e);

    $e = $dom->createElement('date');
    $e->appendTextNode(time2str("%Y-%m-%dT%H:%M:%SZ", $bugs->{$id}{open_date}));
    $cnode->appendChild($e);

    $e = $dom->createElement('text');
    $e->appendTextNode(decode_entities($bugs->{$id}{details}));
    $cnode->appendChild($e);

    $bug->appendChild($cnode);


    if ( $bugs->{$id}->{comments} or $bugs->{$id}->{files} ) {
        foreach my $comment ( @{$bugs->{$id}{comments}} ) {
            $cnode = $dom->createElement('comment');

            $e = $dom->createElement('sender');
            $e->setAttribute('email', $comment->{from_email});
            $e->appendTextNode($comment->{commentername});
            $cnode->appendChild($e);

            $e = $dom->createElement('date');
            $e->appendTextNode(time2str("%Y-%m-%dT%H:%M:%SZ", $comment->{adddate}));
            $cnode->appendChild($e);

            $e = $dom->createElement('text');
            $e->appendTextNode(decode_entities($comment->{body}));
            $cnode->appendChild($e);

            $bug->appendChild($cnode);
        }
        foreach my $file ( @{$bugs->{$id}{files}} ) {
            $cnode = $dom->createElement('comment');

            $e = $dom->createElement('sender');
            $e->setAttribute('email', $file->{submitteremail});
            $e->appendTextNode($file->{submittername});
            $cnode->appendChild($e);

            $e = $dom->createElement('date');
            $e->appendTextNode(time2str("%Y-%m-%dT%H:%M:%SZ", $file->{adddate}));
            $cnode->appendChild($e);

            $e = $dom->createElement('text');
            $e->appendTextNode('Attached ' . $file->{filename} . '.');
            $cnode->appendChild($e);

            $attachment = $dom->createElement('attachment');
            $e = $dom->createElement('filename');
            $e->appendTextNode($file->{filename});
            $attachment->appendChild($e);
            $e = $dom->createElement('title');
            if ( $file->{description} ) {
                $e->appendTextNode($file->{description});
            } else {
                $e->appendTextNode($file->{filename});
            }
            $attachment->appendChild($e);
            $e = $dom->createElement('mimetype');
            $e->appendTextNode($file->{filetype});
            $attachment->appendChild($e);
            $e = $dom->createElement('contents');
            $e->appendTextNode($file->{bin_data});
            $attachment->appendChild($e);
            $cnode->appendChild($attachment);

            $bug->appendChild($cnode);
        }
    }

    $rootnode->appendChild($bug);
}

print $dom->toString(1);


