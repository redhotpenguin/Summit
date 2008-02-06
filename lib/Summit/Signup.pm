package Summit::Signup;

use strict;
use warnings;

use base qw( CGI::Application );
use CGI::Application::Plugin::ValidateRM qw( check_rm);
use CGI::Application::Plugin::TT;
use Mail::Mailer;
use Data::FormValidator;
use WWW::Mechanize;
use Data::Dumper qw( Dumper );
use Summit::DB;
use DBI;

my $ADMIN = 'info@redhotpenguin.com';
my $SUPPORT_URL = 'http://www.sherpamail.com.com/support.html';
my $HOST = '127.0.0.1';
my $TT_INCLUDE_PATH='/var/www/sherpamail.com/tmpl';
my $DOMAIN = 'sherpamail.com';
my $PHONE = '415.720.2103';

my %args = ( agent        =>
    'Mozilla/5.0 (Macintosh; U; PPC Mac OS X Mach-O; en-US; rv:1.8.0.2) Gecko/20060308 Firefox/1.5.0.2' );

sub setup {
    my $self = shift;
    $self->start_mode('signup');
    $self->run_modes(
        [ qw( signup thanks ) ] );
}

sub cgiapp_init {
    my $self = shift;
    $self->tt_include_path($TT_INCLUDE_PATH);
}

sub signup {
    my ($self, $error_msgs) = @_;
    my $output = $self->tt_process('signup.tmpl', $error_msgs);
    return $output;
}

sub _check_url {
    my $self = shift;
	my $url = shift;
	unless ($url =~ m/https?\:\/\//) {
	    $url = 'http://' . $url;
	}
    $url =~ s/\/?$//g;
    $url .= '/clients';
    my $mech = $self->{mech} || WWW::Mechanize->new(%args);
    $mech->get($url);
    return unless $mech->success;
    return unless (
        $mech->res->content =~ m/username/i && 
        $mech->res->content =~ m/password/i &&
        $mech->res->title =~ m/login$/i
    );
	return $url; 
}

sub _basecamp_login {
    my $self = shift;
    my ($login, $pass, $url) = @_;
    return unless ($login && $pass && $url);
    my $mech = $self->{mech} || WWW::Mechanize->new(%args);
	unless ($url =~ m/https?\:\/\//) {
			$url = 'http://' . $url;
	}
    $url =~ s/\/?$//g;
    $url .= '/clients';
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
    my $db_connect_params = Summit::DB->params( db_host => $HOST);
#	print STDERR "DB connect params are " . Dumper($db_connect_params);
    die unless $db_connect_params;
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
            url => {
                name => 'basecamp_url',
                params => [qw( url)],
                constraint_method => \&_check_url,
			},
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

    my $db_connect_params = Summit::DB->params( db_host => $HOST);
    die unless $db_connect_params;
    my $dbh = DBI->connect(@{$db_connect_params});

    my $sql = <<SQL;
INSERT INTO account (basecamp_login, basecamp_pass,
    sender, recipient, active, basecamp_url)
VALUES ( ?, ?,
    ?, ?, 't', ?);
SQL

    my $recipient = join('@', (lc($valid_data->{name}) . '.sherpa'), $DOMAIN);
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
            'From' => "Sherpa Signup <sherpa_signup\@sherpamail.com>",
            'Subject' => $valid_data->{email} . " has signed up!" });

    print $mailer "I'm the signup form for Sherpa, someone has signed up!\n";
  
    print $mailer "\nrecipient: $recipient\n";  
    foreach my $key ( qw( name email login url) ) {
      print $mailer "\n$key: " . $valid_data->{$key} . "\n";
    }
    $mailer->close;

    $mailer->open({
            'To' => $valid_data->{email},
            'From' => "Sherpa Signup <sherpa\@$DOMAIN>",
            'Subject' => 'Your Sherpa account is active'});
	
    my $output = $self->tt_process('signup_email.tmpl', {
		domain    => $DOMAIN,
        recipient => $recipient,
		phone     => $PHONE,
	  }
	);
	
	print $mailer $$output;
    $mailer->close;

    $self->header_type('redirect');
    $self->header_props(-url => 'http://www.sherpamail.com/signup/thanks.html');
}

1;

