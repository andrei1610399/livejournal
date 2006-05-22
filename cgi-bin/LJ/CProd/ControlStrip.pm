package LJ::CProd::ControlStrip;
use base 'LJ::CProd';

sub applicable {
    my ($class, $u) = @_;
    return 0 if $u->prop("view_control_strip") || $u->prop("show_control_strip");
    return 1;
}

sub render {
    my ($class, $u) = @_;
    my $user = LJ::ljuser($u);
    my $link = $class->clickthru_link(BML::ml('controlstrip.link'));

    return "<p>".BML::ml('controlstrip.text', { "link" => $link }) . "</p>";

}

sub link { "$LJ::SITEROOT/manage/settings/" }
sub button_text { "Navigation strip" }

1;
