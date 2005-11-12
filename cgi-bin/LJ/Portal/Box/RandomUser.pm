package LJ::Portal::Box::RandomUser; # <--- Change this
use base 'LJ::Portal::Box';
use strict;

######################## override this stuff ######################

our $_box_class = "RandomUser";
our $_box_description = "See a random user's journal";
our $_box_name = "Random User";

sub generate_content {
    my $self = shift;
    my $content = '';
    my $pboxid = $self->pboxid;
    my $u = $self->{'u'};

    my $dbr = LJ::get_db_reader();
    my $max = $dbr->selectrow_array("SELECT statval FROM stats ".
                                    "WHERE statcat='userinfo' AND statkey='randomcount'");
    if ($max) {
        my $rand = int(rand($max))+1;
        my $username = $dbr->selectrow_array("SELECT u.user FROM randomuserset r, useridmap u ".
                                         "WHERE r.userid=u.userid AND r.rid=$rand");
        my $user = LJ::load_user($username);
        return "Error loading user $username" unless $user;

        # get most recent post
        my @items = LJ::get_recent_items({
            'remote' => $u,
            'userid' => $user->{'userid'},
            'clusterid' => $user->{'clusterid'},
            'skip' => 0,
            'itemshow' => 1,
        });

        my $entryinfo = $items[0];
        return "No entries found." unless $entryinfo;

        my $entry;

        if ($entryinfo->{'ditemid'}) {
            $entry = LJ::Entry->new($user,
                                    ditemid => $entryinfo->{'ditemid'});
        } elsif ($entryinfo->{'itemid'} && $entryinfo->{'anum'}) {
            $entry = LJ::Entry->new($user,
                                    jitemid => $entryinfo->{'itemid'},
                                    anum    => $entryinfo->{'anum'});
        } else {
            return "Could not load entry.";
        }

        return "Could not load entry." unless $entry;

        my $subject    = $entry->subject_html;
        my $entrylink  = $entry->url;
        my $event      = $entry->event_html( { 'cuturl' => $entrylink  } );
        my $posteru    = $entry->poster;
        my $poster     = $posteru->ljuser_display;
        my $journalid  = $entryinfo->{journalid};
        my $posterid   = $entry->posterid;

        # is this a post in a comm?
        if ($journalid != $posterid) {
            my $journalu = LJ::load_userid($journalid);
            if ($journalu) {
                $poster = $poster . " posting in ";
                $poster .= $journalu->ljuser_display;
            }
        }

        $content .= qq {
            $poster:<br/>
            $event
        };
    } else {
        $content = 'No random users generated.';
    }

    return $content;
}


#######################################


sub box_description { $_box_description; }
sub box_name { $_box_name; };
sub box_class { $_box_class; }
sub can_refresh { 1; }

1;
