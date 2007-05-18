package LJ::Widget::QotD;

use strict;
use base qw(LJ::Widget);
use Carp qw(croak);
use Class::Autouse qw( LJ::QotD );

sub need_res {
    return qw( js/widgets/qotd.js stc/widgets/qotd.css );
}

sub render_body {
    my $class = shift;
    my %opts = @_;
    my $ret;

    my $skip = $opts{skip};

    my @questions = LJ::QotD->get_questions( skip => $skip );

    $ret .= "<h2>" . $class->ml('widget.qotd.title');
    $ret .= "<span class='qotd-controls'>";
    $ret .= "<img id='prev_questions' src='$LJ::IMGPREFIX/arrow-spotlight-prev.gif' alt='Previous' /> ";
    $ret .= "<img id='next_questions' src='$LJ::IMGPREFIX/arrow-spotlight-next.gif' alt='Next' />";
    $ret .= "</span>";
    $ret .= "</h2>";
    $ret .= "<div id='all_questions'>";
    $ret .= $class->qotd_display( questions => \@questions );
    $ret .= "</div>";

    return $ret;
}

sub qotd_display {
    my $class = shift;
    my %opts = @_;

    my $questions = $opts{questions} || [];
    my $remote = LJ::get_remote();

    my $ret;
    if (@$questions) {
        $ret .= "<div class='qotd pkg'>";
        foreach my $q (@$questions) {
            my $ml_key = $class->ml_key("$q->{qid}.text");
            my $text = $class->ml($ml_key);
            LJ::CleanHTML::clean_event(\$text);

            my $extra_text;
            if ($q->{extra_text} && LJ::run_hook('show_qotd_extra_text', $remote)) {
                $ml_key = $class->ml_key("$q->{qid}.extra_text");
                $extra_text = $class->ml($ml_key);
                LJ::CleanHTML::clean_event(\$extra_text);
            }

            if ($q->{img_url}) {
                $ret .= "<img src='$q->{img_url}' class='qotd-img' />";
            }
            $ret .= "<p>$text " . $class->answer_link($q) . "</p>";
            my $suggest = "<a href='mailto:feedback\@livejournal.com'>Suggestions</a>";
            $ret .= "<p class='detail'><span class='suggestions'>$suggest</span>$extra_text&nbsp;</p>";
        }
        $ret .= "</div>";
    }

    return $ret;
}

sub answer_link {
    my $class = shift;
    my $question = shift;
    my %opts = @_;
    my $ret;

    my $ml_key = $class->ml_key("$question->{qid}.text");
    my $subject = LJ::eurl($class->ml('widget.qotd.entry.subject'));
    my $event = LJ::eurl($class->ml($ml_key));
    my $tags = LJ::eurl($question->{tags});
    my $url = "$LJ::SITEROOT/update.bml?subject=$subject&event=$event&prop_taglist=$tags";

    $ret .= "<a href=\"$url\" class='answer'>" . $class->ml('widget.qotd.answer') . "</a>";

    return $ret;
}

1;
