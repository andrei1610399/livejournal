package LJ::Worker::TheSchwartz;
use strict;

use lib "$ENV{LJHOME}/cgi-bin";
use base "LJ::Worker", "Exporter";
require "ljlib.pl";
use vars qw(@EXPORT @EXPORT_OK);
use Getopt::Long qw(:config pass_through);

my $interval = 5;
die "Unknown options" unless GetOptions('interval|n=i' => \$interval);

@EXPORT = qw(schwartz_decl schwartz_work schwartz_on_idle schwartz_on_afterwork schwartz_on_prework);

my $sclient;

my $on_idle = sub {};
my $on_afterwork = sub {};

my $on_prework = sub { 1 };  # return 1 to proceed and do work

my $used_role;

sub schwartz_init {
    my ($role) = @_;
    $role ||= 'drain';

    $sclient = LJ::theschwartz({ role => $role }) or die "Could not get schwartz client";
    $used_role = $role; # save success role
    $sclient->set_verbose(LJ::Worker::VERBOSE());
}

sub schwartz_decl {
    my ($classname, $role) = @_;
    $role ||= 'drain';

    die "Already connected to TheSchwartz with role '$used_role'" if defined $used_role and $role ne $used_role;

    schwartz_init($role) unless $sclient;

    $sclient->can_do($classname);
}

sub schwartz_on_idle {
    my ($code) = @_;
    $on_idle = $code;
}

sub schwartz_on_afterwork {
    my ($code) = @_;
    $on_afterwork = $code;
}

# coderef to return 1 to proceed, 0 to sleep
sub schwartz_on_prework {
    my ($code) = @_;
    $on_prework = $code;
}

sub schwartz_work {
    my $sleep = 0;

    schwartz_init() unless $sclient;

    LJ::Worker->setup_mother();

    my $last_death_check = time();
    while (1) {
        LJ::start_request();
        LJ::Worker->check_limits();

        # check to see if we should quit
        exit 0 if LJ::Worker->should_quit;

        my $did_work = 0;
        LJ::Worker::DEBUG("looking for work...");
        if ($on_prework->()) {
            $did_work = $sclient->work_once;
            $on_afterwork->($did_work);
        }
        LJ::Worker::DEBUG("   did work = ", $did_work);

        exit 0 if LJ::Worker->should_quit;

        if ($did_work) {
            $sleep--;
            $sleep = 0 if $sleep < 0;
        } else {
            $on_idle->();
            $sleep = $interval if ++$sleep > $interval;
            sleep $sleep;
        }

        # do request cleanup before we process another job
        LJ::end_request();
    }
}

1;
