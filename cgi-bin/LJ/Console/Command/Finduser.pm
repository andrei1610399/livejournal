package LJ::Console::Command::Finduser;

use strict;
use base qw(LJ::Console::Command);
use Carp qw(croak);
use LJ::TimeUtil;

sub cmd { "finduser" }

sub desc { "Finds all accounts matching a certain criterion." }

sub args_desc { [
                 'criteria' => "One of: 'user', 'userid', 'email', 'timeupdate', 'openid', or 'openid-raw'.",
                 'data' => "Either a username or email address, a userid when using 'userid', or an OpenID identity URL.\nThe URL is canonicalized in the 'openid' mode.",
                 ] }

sub usage { '<criteria> <data>' }

sub can_execute {
    my $remote = LJ::get_remote();
    return LJ::check_priv($remote, "finduser");
}

sub execute {
    my ($self, @args) = @_;

    my ($crit, $data, $opt);
    if (scalar(@args) == 1) {
        # we can auto-detect emails easy enough
        $data = $args[0];
        if ($data =~ /@/) {
            $crit = 'email';
        } elsif ($data =~ /^http:/) {
            $crit = 'openid';
        } else {
            $crit = 'user';
        }
    } else {
        # old format...but new variations
        $crit = $args[0];
        $data = $args[1];

        # if they gave us the timeupdate flag as the criterion,
        # rewrite as a regular finduser, but display last update time, too
        if ($crit eq 'timeupdate') {
            $opt = 'timeupdate';
            if ($data !~ /@/) {
                $crit = 'user';
            } else {
                $crit = 'email';
            }
        }

        # if they gave us a username and want to search by email, instead find
        # all users with that email address
        if ($crit eq 'email' && $data !~ /@/) {
            my $u = LJ::load_user($data)
                or return $self->error("User $data doesn't exist.");
            $data = $u->email_raw
                or return $self->error($u->user . " does not have an email address.");
        }
    }

    my $dbh = LJ::get_db_reader();
    my $userlist;

    if ($crit eq 'email') {
        $userlist = $dbh->selectcol_arrayref("SELECT userid FROM email WHERE email = ?", undef, $data);
    } elsif ($crit eq 'userid') {
        $userlist = $dbh->selectcol_arrayref("SELECT userid FROM user WHERE userid = ?", undef, $data);
    } elsif ($crit eq 'user') {
        $data = LJ::canonical_username($data);
        $userlist = $dbh->selectcol_arrayref("SELECT userid FROM user WHERE user = ?", undef, $data);
    } elsif ($crit eq 'openid' || $crit eq 'openid-raw') {
        if ($crit eq 'openid') {
            # canonicalize the address first
            my $csr = LJ::OpenID::consumer();
            my $id = $csr->claimed_identity($data);
            $data = $id->claimed_url;
        }

        $userlist = $dbh->selectcol_arrayref('SELECT userid FROM identitymap WHERE identity=? AND idtype="O"', undef, $data);
    } else {
        return $self->error("Unknown criterion. Consult the reference.");
    }

    return $self->error("Error in database query.")
        if $dbh->err;

    my $userids = [];
    push @$userids, @{$userlist || []};

    return $self->error("No matches")
        unless @$userids;

    my $us = LJ::load_userids(@$userids);

    my $timeupdate;
    $timeupdate = LJ::get_timeupdate_multi({}, @$userids)
        if $opt eq 'timeupdate';

    foreach my $u (sort { $a->id <=> $b->id } values %$us) {
        next unless $u;
        my $userid = $u->id;

        $self->info("User: " . $u->user . " (" . $u->id . "), journaltype: " . $u->journaltype . ", statusvis: " .
                    $u->statusvis . ", email: (" . $u->email_status . ") " . $u->email_raw);

        $self->info("  User is currently in read-only mode.")
            if $u->readonly;

        if ($u->underage) {
            my $reason;
            if ($u->underage_status eq 'M') {
                $reason = "manual set (see statushistory type set_underage)";
            } elsif ($u->underage_status eq 'Y') {
                $reason = "provided birthdate";
            } elsif ($u->underage_status eq 'O') {
                $reason = "unique cookie";
            }
            $self->info("  User is marked underage due to $reason");
        }

        $self->info("  Last updated: " . ($timeupdate->{$userid} ? LJ::TimeUtil->time_to_http($timeupdate->{$userid}) : "Never"))
            if $opt eq 'timeupdate';

        foreach (LJ::run_hooks("finduser_extrainfo", { 'dbh' => $dbh, 'u' => $u })) {
            next unless $_->[0];
            $self->info($_) foreach (split(/\n/, $_->[0]));
        }
    }

    return 1;
}

1;
