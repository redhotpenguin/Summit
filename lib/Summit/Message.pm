package Summit::Message;

=head1 NAME

  Summit::Message - a message object

=cut

=head1 SYNOPSIS

[SYNOPSIS]

=cut

use strict;
use warnings;

use WWW::Mechanize ();

use constant ACCOUNT_TRIAL => 1;

=head1 METHODS

=over 4

=item C<new>

Instantiates a new object.

  my $obj = $class->new($args_ref);

=over 4

=item pkg: C<$class> ( C<[PACKAGE]> CLASS ref )

The package, or class reference.

=item arg: C<$args_ref>

A reference to the arguments you are passing to the constructor.

=item obj: C<$obj> ( C<[PACKAGE> object )

=back

=cut

sub new {
    my ($class, $args_ref) = @_;

    my $self = {};
    bless $self, $class;

    my $success = $self->_init($args_ref);

    return $self;
}

=item C<_init>

Initialize the object with $args_ref

  $success = $self->_init($args_ref);

=over 4

=item obj: C<$self> ( C<[PACKAGE]> object )

The object to be initialized.

=item arg: C<$args_ref>

The arguments which initialize the object

=item ret: C<$success> ( boolean )

Returns true on success.

=back

=cut

sub _init {
    my ($self, $args_ref) = @_;

    die unless (exists $args_ref->{headers} && exists $args_ref->{body});
    require MIME::Parser;
    my $p = MIME::Parser->new;
    $p->output_to_core(1);
    my $entity =
      $p->parse_data(join("\n\n", $args_ref->{headers}, $args_ref->{body}));
    $self->entity($entity);
    return 1;
}

sub has_rfc_822 {
    my $self = shift;
    my ($rfc_822) =
      grep { $_->mime_type eq 'message/rfc822' } $self->entity->parts;
    defined $rfc_822 ? return $rfc_822 : return;
}

sub _comment_err_log {
    my $self = shift;
    @_ and $self->{_comment_err_log} = shift;
    return $self->{_comment_err_log};
}

sub _comment_err_msg {
    my $self = shift;
    @_ and $self->{_comment_err_msg} = shift;
    return $self->{_comment_err_msg};
}

sub entity {
    my $self = shift;
    @_ and $self->{_entity} = shift;
    return $self->{_entity};
}

sub basecamp_login {
    my $self = shift;
    @_ and $self->{_basecamp_login} = shift;
    return $self->{_basecamp_login};
}

sub basecamp_pass {
    my $self = shift;
    @_ and $self->{_basecamp_pass} = shift;
    return $self->{_basecamp_pass};
}

sub comment {
    my $self = shift;

    return $self->{_comment} if defined $self->{_comment};

    # we want to grab the first mime_entity
    my $body = $self->entity->parts(0);
    return $body->body_as_string if defined $body;

    # or the body as string if no mime entities
    $body = $self->entity->body_as_string;

    # split on ---- Forwarded Messaqe
    #          ---------- Original Message
    my ($comment) = split(/[-]{4,10}/, $body);
    if (defined $comment && $comment =~ m/\S/) {
        chomp($comment);
        $self->{_comment} = $comment;
        return $comment;
    }

    ## Hmmm, no comment extracted so just return;
    return;
}

sub url {
    my $self = shift;

    return $self->{_url} if defined $self->{_url};

    my $body;
    if (my $rfc_822 = $self->has_rfc_822) {
        $body = $rfc_822->body_as_string;
    }
    else {
        $body = $self->entity->body_as_string;
    }

    my ($url) =
      $body =~ m{(http://\w+\.(?:clientsection|projectpath)\.com/\w+)}s;

    return unless defined $url;

    $self->{_url} = $url;
    return $url;
}

sub account_type {
    return 1;
}

sub post_to_basecamp {
    my $self = shift;

    my $comment = $self->comment;
    if ($self->account_type == ACCOUNT_TRIAL) {
        $comment .=
          "\n- comment posted via Sherpa (http://sherpa.redhotpenguin.com)";
    }

    my $mech = WWW::Mechanize->new(cookie_jar => {});

    # Time to have some fun
    $mech->get($self->url);
    unless ($mech->success) {

        # couldn't get the page
        $self->_comment_err_log("Problem grabbing url " . $self->url,
                                ", rc " . $mech->res->code);
        $self->_comment_err_msg("\nSorry the url "
                       . $self->url
                       . " is currently inaccessible.  Please try again later");
        return;
    }
    elsif (!$mech->res->content =~ m/username/) {    # hmm wrong page
        $self->_comment_err_log(  "The login page didn't contain a valid url: "
                                . $self->url . ", rc "
                                . $mech->res->code);
        $self->_comment_err_msg("\nPlease check your account settings, the url "
                                . $self->url
                                . " doesn't look like a valid request");
    }

    #    $self->log(LOGDEBUG, "Response from login page get: \n" .
    #		Dumper($mech->res->content));
    $mech->submit_form(
                       form_number => 1,
                       fields      => {
                                  user_name => $self->basecamp_login,
                                  password  => $self->basecamp_pass,
                                 },
                      );

    if ($mech->res->content =~ m/is invalid/) {
        $self->_comment_err_log(  "Invalid username or password, url "
                                . $self->url
                                . ", login "
                                . $self->basecamp_login);
        my $msg =
            "\nSorry we had a problem logging in, username "
          . $self->basecamp_login
          . ", pass "
          . $self->basecamp_pass . "\n\n";
        $self->_comment_err_msg($msg);
        return;
    }
    elsif (!$mech->success) {
        $self->_comment_err_log(  "no mech response for login url "
                                . $self->url
                                . ", login "
                                . $self->basecamp_login);
        my $msg = "\nSorry we couldn't log in to " . $self->url . "\n";
        $self->_comment_err_msg($msg);
        return;
    }

#$self->log( LOGDEBUG, "Page after logging in: \n" . Dumper($mech->res->content));
    $mech->field('comment[body]' => $comment);
    $mech->click_button(value => "Post this Comment");

#$self->log( LOGDEBUG, "Page content after posting: " . Dumper($mech->res->content));
    unless ($mech->res->is_success) {
        $self->_comment_err_log("Problem posting comment: $comment");
        $self->_comment_err_msg(
                  "Sorry there was a problem posting your comment: \n$comment");
        return;
    }

    # Success!
    return 1;
}

=item C<save>

Saves the object.

  $success = $obj->save;

=over 4

=item obj: C<$obj> ( C<[PACKAGE]> object )

The object to save.

=item ret: C<$success> ( boolean )

True if the object could be saved successfully.

=back

=cut

sub save {
    my $self = shift;

    return 0;    # no save by default
}

# some other methods

=pos

=back

=cut

1;

__END__

