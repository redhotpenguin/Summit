#!perl

use strict;
use warnings FATAL => 'all';

use Test::More tests => 2;

BEGIN { use_ok('Summit::Message'); }

my $msg = do { local $/; <DATA> };

my $comment = Summit::Message::_extract_comment($msg);

my $test_comment = <<COMMENT;
Testing Sherpa

Jeff Lennan
(503) 715-6293


COMMENT

is($comment, $test_comment, 'comment extracted');

__DATA__
Testing Sherpa

Jeff Lennan
(503) 715-6293


Begin forwarded message:

> From: Jill Stear <do-not-reply-C14063518@winningmark.clientsection.com 
>
> Date: February 6, 2008 7:25:34 PM PST
> To: Jeff Lennan <jeff@winningmark.com>
> Subject: [Winning Mark Dashboard] Re: Dingfelder Mail Plan
>
> A new comment has been posted. DO NOT REPLY TO THIS EMAIL.
> To post your own comment or read the original message, visit:
> https://winningmark.clientsection.com/P11203049
>
> -----------------------------------------------------------------
> Company: Winning Mark
> Project: Jackie Dingfelder
> -----------------------------------------------------------------
> Jill Stear posted this comment:
> .................................................................
>
>   Jackie has approved the mailplan so we can proceed with writing  
> text
>   for Mail Piece 1.
>
>   Jill
>
> --
> DO NOT REPLY TO THIS EMAIL
> To post a comment of your own, read the original message, or to
> read all existing comments, visit:
> https://winningmark.clientsection.com/C14063518
