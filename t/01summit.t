#!perl

use strict;
use warnings FATAL => 'all';

use Data::Dumper;
use DBI;
use MIME::Entity;
use Summit::DB;
use Test::More tests => 4;

my $recipient = "summit_recipient\@redhotpenguin.com";
my $sender = "summit_sender\@redhotpenguin.com";
my $msg_data = do { local $/; <DATA> };
my $entity = MIME::Entity->build(Type => 'text/plain',
	From =>  "Summit Test Sender<$sender>",
	To =>  "Summit Test Receiver<$recipient>",
	Data => $msg_data);

my $db_params_ref = Summit::DB->params(db_user => $ENV{USER});
my $dbh = DBI->connect(@{$db_params_ref});
my $del_sql = "DELETE FROM ACCOUNT where basecamp_login = '$ENV{USER}'";
my $del_sth = $dbh->prepare($del_sql);
my $ins_sql = <<SQL;
insert into account (basecamp_login, basecamp_pass, sender, recipient, active) values ('fred', 'moyer', '$sender', '$recipient', 't')
SQL
my $ins_sth = $dbh->prepare($ins_sql);

diag("Removing user $ENV{USER} from database and emailing to check auth\n");
$del_sth->execute;
$dbh->commit;
$DB::single = 1;
ok(! $entity->smtpsend(MailFrom => $sender), 'mail failed to send successfully');

diag("put the user back, send a legitimate mail");
$ins_sth->execute;
$dbh->commit;
ok($entity->smtpsend(MailFrom => $sender), 'mail sent successfully');



sleep 1;

__DATA__
Test response

-----Original Message-----
From: Fred Moyer <do-not-reply-P2980326@prdf.clientsection.com>
To: Jeff Lennan <jeff@redhotpenguin.com>, Fred Moyer
<fred@redhotpenguin.com>, Hans Eisenman <hansntc@earthlink.net>, Darren
Waddell <darren_waddell@yahoo.com>, Garrett Suchecki
<garrettsuchecki@gmail.com>
Subject: [SL] Minor Bugfix release
Date: Fri, 28 Jul 2006 00:27:47 -0500

A new message has been posted. DO NOT REPLY TO THIS EMAIL.
To comment on this message, visit:
http://prdf.clientsection.com/P2980326

-----------------------------------------------------------------
Company: Silver Lining
Project: QA
-----------------------------------------------------------------
Fred <fred@redhotpenguin.com> from Silver Lining said:
.................................................................

I fixed a bug with alaskaair.com that may have have affected some
other sites. It's surfing pretty fast here from home.


--
DO NOT REPLY TO THIS EMAIL
To comment on this message, visit:
http://prdf.clientsection.com/P2980326
