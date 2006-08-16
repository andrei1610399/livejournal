package LJ::Setting::CtxPopup;
use base 'LJ::Setting::BoolSetting';
use strict;
use warnings;
no warnings 'redefine';

sub tags { qw(hide popup contextual user head icon pop) }

sub label {
    return "Contextual Popup";
}

sub des {
    return "Show contextual popup when hovering over user icons and userpics.";
}

sub is_selected {
    my ($class, $u) = @_;
    return $u->prop('opt_ctxpopup');
}

sub prop_name { "opt_ctxpopup" }
sub checked_value { "Y" }
sub unchecked_value { "N" }

1;
