#!perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;

BEGIN { use_ok('Summit::Message'); }

my $msg = do { local $/; <DATA> };

my $comment = Summit::Message::_extract_comment($msg);

is($comment, "Another test response\n\n", 'comment extracted');

__DATA__
Another test response

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
http://prdf.clientsection.com/P3029497
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
http://prdf.clientsection.com/P3029497
