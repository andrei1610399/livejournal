package LJ::Widget::RecentComments;

use strict;
use base qw(LJ::Widget);
use Carp qw(croak);
use LJ::Text;
use String::CRC32;

use constant { WIDGET_EXPIRE_TIME => 15*60};

sub need_res {
    return qw( stc/widgets/recentcomments.css );
}

my @_ml_strings = (
    'widget.recentcomments.title',
    'widget.recentcomments.viewall',
    'widget.recentcomments.anon',
    'widget.recentcomments.nocomments',
    'widget.recentcomments.nosubject',
    'widget.recentcomments.commentheading',
    'widget.recentcomments.link',
    'widget.recentcomments.reply',
);

# args
#   user: optional $u whose recent received comments we should get (remote is default)
#   limit: number of recent comments to show, or 3
sub render_body {
    my $class = shift;
    my %opts = @_;

    my $u = $opts{user} && LJ::isu($opts{user}) ? $opts{user} : LJ::get_remote();
    return "" unless $u;
    return "" if $u->is_identity;

    my $lncode = LJ::Lang::get_effective_lang();
    LJ::Lang::get_text_multi($lncode, undef, \@_ml_strings);

    my $limit = defined $opts{limit} ? $opts{limit} : 3;

    my @comments = $u->get_recent_talkitems($limit, memcache => 1);

    my $ret;

    $ret .= "<div class='w-head'>";
    $ret .= "<h2><span class='w-head-in'>" . $class->ml('widget.recentcomments.title') . "</span></h2>";
    $ret .= "<a href='$LJ::SITEROOT/tools/recent_comments.bml' class='more-link'>" . $class->ml('widget.recentcomments.viewall') . "</a>";
    $ret .= "<i class='w-head-corner'></i></div>";

    # return if no comments
    return "<h2><span>" . $class->ml('widget.recentcomments.title') . "</span></h2><div class='warningbar'>" . $class->ml('widget.recentcomments.nocomments', {'aopts' => "href='$LJ::SITEROOT/update.bml'"}) . "</div>"
        unless @comments && defined $comments[0];

    my $key_part = crc32(join(':', map { $_->{jtalkid} } @comments));
    my $key = "recent_comments_widget:$key_part:" .
              ":" . $lncode .
              ":" . $u->userid;

    my $data = LJ::MemCache::get($key);
    if ($data) {
        return $data;
    }

    # there are comments, print them
    @comments = reverse @comments; # reverse the comments so newest is printed first
    $ret .= "<div class='w-body'>";
    $ret .= "<ul>";
    my $ct = 0;
    foreach my $row (@comments) {
        next unless $row->{nodetype} eq 'L';

        # load the comment
        my $comment = LJ::Comment->new($u, jtalkid => $row->{jtalkid});
        next if $comment->is_deleted || $comment->is_spam;

        # load the comment poster
        my $posteru = $comment->poster;
        next if $posteru && ($posteru->is_suspended || $posteru->is_expunged);
        my $poster = $posteru ? $posteru->ljuser_display : $class->ml('widget.recentcomments.anon');

        # load the entry the comment was posted to
        my $entry = $comment->entry;
        my $class_name = ($ct == scalar(@comments) - 1) ? "last" : "";
        $class_name .= (($ct + 1)%2 == 0) ? " odd" : "";

        my $subject = $entry->subject_text ? $entry->subject_text : $class->ml('widget.recentcomments.nosubject');
        my $body_part = LJ::Text->truncate_to_word_with_ellipsis( 'str'=>$comment->body_text, 'chars'=>150 ) . "&nbsp;";

        # prevent BML tags interpretation inside comment subject/body
        $subject =~ s/<\?/&lt;?/g;
        $subject =~ s/\?>/?&gt;/g;
        $body_part =~ s/<\?/&lt;?/g;
        $body_part =~ s/\?>/?&gt;/g;

        # print the comment
        $ret .= "<li class='$class_name'>";
        $ret .= $comment->poster_userpic;
        $ret .= $class->ml('widget.recentcomments.commentheading', {'poster' => $poster, 'entry' => "<a href='" . $entry->url . "'>"});
        $ret .= $subject;
        $ret .= "</a><br />";
        $ret .= "<span class='comment-body'>" . $body_part . "</span>";
        $ret .= "<span class='detail'>(<a href='" . $comment->url . "'>" . $class->ml('widget.recentcomments.link') . "</a>)</span> ";
        $ret .= "<span class='detail'>(<a href='" . $comment->reply_url . "'>" . $class->ml('widget.recentcomments.reply') . "</a>)</span> ";
        $ret .= "</li>";
        $ct++;
    }
    $ret .= "</ul>";
    $ret .= "</div>";

    LJ::MemCache::set($key, $ret, WIDGET_EXPIRE_TIME);
    return $ret;
}

1;
