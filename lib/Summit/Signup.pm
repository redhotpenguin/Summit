package Summit::Signup;

use strict;
use warnings;

use base qw( CGI::Application );
use CGI::Application::Plugin::ValidateRM qw( check_rm);
use CGI::Application::Plugin::TT;
use Mail::Mailer;
use Data::FormValidator;

use Data::Dumper qw( Dumper );

use constant DOMAIN => 'redhotpenguin.com';

my $ADMIN = 'fred@redhotpenguin.com';
my $SUPPORT_URL = 'http://summit.redhotpenguin.com/faq.html';

sub setup {
    my $self = shift;
    $self->start_mode('signup');
    $self->run_modes(
        [ qw( signup thanks ) ] );
}

sub cgiapp_init {
    my $self = shift;
    $self->tt_include_path('/var/www/localhost/tt/summit');
}

sub signup {
    my ($self, $error_msgs) = @_;
    my $output = $self->tt_process('signup.tmpl', $error_msgs);
    return $output;
}

sub _basecamp_login {
    my $self = shift;
    my ($login, $pass, $url) = @_;
    return unless ($login && $pass && $url);
    require WWW::Mechanize;
    my $mech = $self->{mech} || WWW::Mechanize->new;
    unless ($url =~ m/http\:\/\//) {
        $url = 'http://' . $url;
    }
    $mech->get($url);
    $self->{mech} = $mech;
    return unless $mech->success;
    return unless (
        $mech->res->content =~ m/username/i && 
        $mech->res->content =~ m/password/i &&
        $mech->res->title =~ m/login$/i
    );
    $mech->submit_form(
        form_number => 1,
        fields => {
            user_name => $login,
            password  => $pass,
        },
    );
    return unless $mech->success;
    return if ($mech->res->content =~ m/entered is invalid/i);
    return if ($mech->res->title =~ m/login$/i); # just in case
    return 1;
}

sub _dupe_user {
    my $self = shift;
    my ($email, $login) = @_;
    return 1 unless ($email && $login); # lower precedence constraint
    require Summit::DB;
    my $db_connect_params = Summit::DB->params;
    die unless $db_connect_params;
    require DBI;
    my $dbh = DBI->connect(@{$db_connect_params});

    my $sql = <<SQL;
SELECT count(basecamp_login) from account
WHERE basecamp_login = ? AND sender = ? AND active='t'
SQL
    
    my $sth = $dbh->prepare($sql);
    $sth->bind_param(1, $login);
    $sth->bind_param(2, $email);
    $sth->execute or die $DBI::errstr;
    my $res = $sth->fetchrow_arrayref;
    $dbh->rollback;
    if ($res->[0] > 0) {
        return; # user already exists
    }
    return 1; # user does not exist yet
}

sub thanks {
    my $self = shift;
    my $valid = {
        required => [
            qw( email
                login
                pass
                url
                name
                dupe_user
            ) ],
        constraints => {
            login => {
                name => 'basecamp_login',
                params => [qw(login pass url)],
                constraint_method => \&_basecamp_login,
            },
            dupe_user => {
                name => 'dupe_user_check',
                params => [qw(email login)],
                constraint_method => \&_dupe_user,
            },
            email => 'email',
            name => qr/^\w+$/,
        },
        msgs => 
        {
        prefix      => 'err_',
        any_errors  => 'any_errors',
        format      => '%s',
        missing     => 'Missing',
        invalid     => 'Invalid',
        },
    };

    my ($results, $err_page ) = $self->check_rm( 'signup', $valid);
    return $err_page if ($err_page);

    my $valid_data = $results->valid();

    require Summit::DB;

    my $db_connect_params = Summit::DB->params;
    die unless $db_connect_params;
    require DBI;
    my $dbh = DBI->connect(@{$db_connect_params});

    my $sql = <<SQL;
INSERT INTO account (basecamp_login, basecamp_pass,
    sender, recipient, active, basecamp_url)
VALUES ( ?, ?,
    ?, ?, 't', ?);
SQL

    my $recipient = join('@', ($valid_data->{name} . '_summit'), DOMAIN);
    my $sth = $dbh->prepare($sql);
    $sth->bind_param(1, $valid_data->{login});
    $sth->bind_param(2, $valid_data->{pass});
    $sth->bind_param(3, $valid_data->{email});
    $sth->bind_param(4, $recipient);
    $sth->bind_param(5, $valid_data->{basecamp_url});
    $sth->execute or die $DBI::errstr;
    $dbh->commit;
 
    my $mailer = Mail::Mailer->new('qmail');
    $mailer->open({
            'To' => $ADMIN,
            'From' => "Summit Signup <summit_signup\@redhotpenguin.com>",
            'Subject' => $valid_data->{email} . " has signed up!" });

    print $mailer "I'm the signup form for summit, someone has signed up!\n";
  
    foreach my $key ( qw( name email login pass url) ) {
      print $mailer "\n$key: " . $valid_data->{$key} . "\n";
      print $mailer "\nrecipient: $recipient\n";  
    }
    $mailer->close;
   
    my $url = $valid_data->{url};
    $mailer->open({
            'To' => $valid_data->{email},
            'From' => "Summit Signup <summit_signup\@redhotpenguin.com>",
            'Subject' => 'Your Summit account is active'});
    my $msg = <<MSG;
Thank you for signing up for the Summit email reply service.  With this 
service, you can forward your Basecamp emails to $recipient with a comment 
above the forwarded message, and the comment will be posted to your basecamp 
account located at $url.  Please make sure to end your comment with at least 
two returns.  For more information on how to use summit, visit $SUPPORT_URL. 
\nWe hope you enjoy this free 30 day trial.  As the end of the trial draws 
near, we will send you a link which will allow you to purchase an account. 

MSG
    print $mailer $msg;
    $mailer->close;

    $self->header_type('redirect');
    $self->header_props(-url => 'http://summit.redhotpenguin.com/signup/thanks.html');
}

1;

