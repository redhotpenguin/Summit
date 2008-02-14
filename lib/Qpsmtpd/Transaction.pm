package Qpsmtpd::Transaction;
use Qpsmtpd;
@ISA = qw(Qpsmtpd);
use strict;
use Qpsmtpd::Utils;
use Qpsmtpd::Constants;

use IO::File qw(O_RDWR O_CREAT);

sub new { start(@_) }

sub start {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my %args = @_;
  my $self = { _rcpt => [], started => time };
  bless ($self, $class);
  return $self;
}

sub add_recipient {
  my $self = shift;
  @_ and push @{$self->{_recipients}}, shift;
}

sub recipients {
  my $self = shift;
  @_ and $self->{_recipients} = [@_];
  ($self->{_recipients} ? @{$self->{_recipients}} : ());
}

sub sender {
  my $self = shift;
  @_ and $self->{_sender} = shift;
  $self->{_sender};
}

sub header {
  my $self = shift;
  @_ and $self->{_header} = shift;
  $self->{_header};
}

# blocked() will return when we actually can do something useful with it...
#sub blocked {
#  my $self = shift;
#  carp 'Use of transaction->blocked is deprecated;'
#       . 'tell ask@develooper.com if you have a reason to use it';
#  @_ and $self->{_blocked} = shift;
#  $self->{_blocked};
#}

sub notes {
  my $self = shift;
  my $key  = shift;
  @_ and $self->{_notes}->{$key} = shift;
  #warn Data::Dumper->Dump([\$self->{_notes}], [qw(notes)]);
  $self->{_notes}->{$key};
}

sub set_body_start {
    my $self = shift;
    $self->{_body_start} = $self->body_current_pos;
    if ($self->{_body_file}) {
               $self->{_header_size} = $self->{_body_start};
    }
    else {
        $self->{_header_size} = 0;
        if ($self->{_body_array}) {
            foreach my $line (@{ $self->{_body_array} }) {
                $self->{_header_size} += length($line);
            }
        }
   }
}

sub body_start {
  my $self = shift;
  @_ and die "body_start now read only";
  $self->{_body_start};
}

sub body_current_pos {
    my $self = shift;
    if ($self->{_body_file}) {
        return tell($self->{_body_file});
    }
    return $self->{_body_current_pos} || 0;
}

sub body_filename {
  my $self = shift;
  $self->body_spool() unless $self->{_filename};
  $self->{_body_file}->flush(); # so contents won't be cached
  return $self->{_filename};
}

sub body_spool {
  my $self = shift;
  $self->log(LOGINFO, "spooling message to disk");
  $self->{_filename} = $self->temp_file();
  $self->{_body_file} = IO::File->new($self->{_filename}, O_RDWR|O_CREAT, 0600)
    or die "Could not open file $self->{_filename} - $! "; # . $self->{_body_file}->error;
  if ($self->{_body_array}) {
    foreach my $line (@{ $self->{_body_array} }) {
      $self->{_body_file}->print($line) or die "Cannot print to temp file: $!";
    }
    $self->{_body_start} = $self->{_header_size};
  }
  $self->{_body_array} = undef;
}

sub replace_body {
	my $self = shift;
	my $data = shift;
	
      if ($self->{_body_file}) {
            warn("body_front_write to file\n");
        
            # go to the beginning of the file

	    $self->body_resetpos
		    unless $self->{body_front_writing};
	    $self->{_body_file_writing} = 1;

        my $new_body;
            if (ref $data eq "SCALAR") {
                    $new_body = $$data;
                } else {
                    $new_body = $data;
                }
            $self->body_resetpos;
        
        
        $self->{_body_file}->print($new_body)
            and $self->{_body_size} = length ($new_body);
}
      else {
            warn("body_front_write to array\n");
            $self->{_body_array} = [];
        
            my $ref = ref($data) eq "SCALAR" ? $data : \$data;
            my @data_ary = split('', $$ref);
            unshift @{ $self->{_body_array} }, @data_ary;
            $self->{_body_size} += scalar(@{ $self->{_body_array} });
            $self->{_body_current_pos} = ( scalar(@{ $self->{_body_array} }) - 1 );
            $self->body_spool if ( $self->{_body_size} >= $self->size_threshold() );
          }
}


sub body_front_write {
       my $self = shift;
      my $data = shift;
      if ($self->{_body_file}) {
            #warn("body_front_write to file\n");
        
            # go to the beginning of the file
            $self->body_resetpos
              unless $self->{body_file_writing};
            $self->{_body_file_writing} = 1;
        
              my $new_body;
            if (ref $data eq "SCALAR") {
                    $new_body = $$data . $self->body_as_string;
                } else {
                    $new_body = $data . $self->body_as_string;
                }
        
            $self->body_resetpos;
        
            $self->{_body_file}->print($new_body)
              and $self->{_body_size} = length ($new_body);
            $self->{_body_file_writing} = 0;
          }
      else {
            #warn("body_front_write to array\n");
            $self->{_body_array} ||= [];
        
            my $ref = ref($data) eq "SCALAR" ? $data : \$data;
            my @data_ary = split('', $$ref);
            unshift @{ $self->{_body_array} }, @data_ary;
            $self->{_body_size} += scalar(@{ $self->{_body_array} });
            $self->{_body_current_pos} = ( scalar(@{ $self->{_body_array} }) - 1 );
            $self->body_spool if ( $self->{_body_size} >= $self->size_threshold() );
          }
}

sub body_write {
  my $self = shift;
  my $data = shift;
  if ($self->{_body_file}) {
    #warn("body_write to file\n");
    # go to the end of the file
    seek($self->{_body_file},0,2)
      unless $self->{_body_file_writing};
    $self->{_body_file_writing} = 1;
    $self->{_body_file}->print(ref $data eq "SCALAR" ? $$data : $data)
      and $self->{_body_size} += length (ref $data eq "SCALAR" ? $$data : $data);
  }
  else {
    #warn("body_write to array\n");
    $self->{_body_array} ||= [];
    my $ref = ref($data) eq "SCALAR" ? $data : \$data;
    pos($$ref) = 0;
    while ($$ref =~ m/\G(.*?\n)/gc) {
      push @{ $self->{_body_array} }, $1;
      $self->{_body_size} += length($1);
      ++$self->{_body_current_pos};
    }
    if ($$ref =~ m/\G(.+)\z/gc) {
      push @{ $self->{_body_array} }, $1;
      $self->{_body_size} += length($1);
      ++$self->{_body_current_pos};
    }
    $self->body_spool if ( $self->{_body_size} >= $self->size_threshold() );
  }
}

sub body_size {
  shift->{_body_size} || 0;
}

sub body_resetpos {
  my $self = shift;
  
  if ($self->{_body_file}) {
    my $start = $self->{_body_start} || 0;
    seek($self->{_body_file}, $start, 0);
    $self->{_body_file_writing} = 0;
  }
  else {
    $self->{_body_current_pos} = $self->{_body_start};
  }
  
  1;
}

sub body_getline {
  my $self = shift;
  if ($self->{_body_file}) {
    my $start = $self->{_body_start} || 0;
    seek($self->{_body_file}, $start,0)
      if $self->{_body_file_writing};
    $self->{_body_file_writing} = 0;
    my $line = $self->{_body_file}->getline;
    return $line;
  }
  else {
    return unless $self->{_body_array};
    $self->{_body_current_pos} ||= 0;
    my $line = $self->{_body_array}->[$self->{_body_current_pos}];
    $self->{_body_current_pos}++;
    return $line;
  }
}

sub body_as_string {
    my $self = shift;
    $self->body_resetpos;
    local $/;
    my $str = '';
    while (defined(my $line = $self->body_getline)) {
        $str .= $line;
    }
    return $str;
}

sub DESTROY {
  my $self = shift;
  # would we save some disk flushing if we unlinked the file before
  # closing it?

  undef $self->{_body_file} if $self->{_body_file};
  if ($self->{_filename} and -e $self->{_filename}) {
    unlink $self->{_filename} or $self->log(LOGERROR, "Could not unlink ", $self->{_filename}, ": $!");
  }

  # These may not exist
  if ( $self->{_temp_files} ) {
    $self->log(LOGDEBUG, "Cleaning up temporary transaction files");
    foreach my $file ( @{$self->{_temp_files}} ) {
      next unless -e $file;
      unlink $file or $self->log(LOGERROR,
       "Could not unlink temporary file", $file, ": $!");
    }
  }
  # Ditto
  if ( $self->{_temp_dirs} ) {
    eval {use File::Path};
    $self->log(LOGDEBUG, "Cleaning up temporary directories");
    foreach my $dir ( @{$self->{_temp_dirs}} ) {
      rmtree($dir) or $self->log(LOGERROR, 
        "Could not unlink temporary dir", $dir, ": $!");
    }
  }
}


1;
__END__

=head1 NAME

Qpsmtpd::Transaction - single SMTP session transaction data

=head1 SYNOPSIS

  foreach my $recip ($transaction->recipients) {
    print "T", $recip->address, "\0";
  }

=head1 DESCRIPTION

Qpsmtpd::Transaction maintains a single SMTP session's data, including
the envelope details and the mail header and body.

The docs below cover using the C<$transaction> object from within plugins
rather than constructing a C<Qpsmtpd::Transaction> object, because the
latter is done for you by qpsmtpd.

=head1 API

=head2 add_recipient($recipient)

This adds a new recipient (as in RCPT TO) to the envelope of the mail.

The C<$recipient> is a C<Qpsmtpd::Address> object. See L<Qpsmtpd::Address>
for more details.

=head2 recipients( )

This returns a list of the current recipients in the envelope.

Each recipient returned is a C<Qpsmtpd::Address> object.

This method is also a setter. Pass in a list of recipients to change
the recipient list to an entirely new list. Note that the recipients
you pass in B<MUST> be C<Qpsmtpd::Address> objects.

=head2 sender( [ ADDRESS ] )

Get or set the sender (MAIL FROM) address in the envelope.

The sender is a C<Qpsmtpd::Address> object.

=head2 header( [ HEADER ] )

Get or set the header of the email.

The header is a <Mail::Header> object, which gives you access to all
the individual headers using a simple API. e.g.:

  my $headers = $transaction->header();
  my $msgid = $headers->get('Message-Id');
  my $subject = $headers->get('Subject');

=head2 notes( $key [, $value ] )

Get or set a note on the transaction. This is a piece of data that you wish
to attach to the transaction and read somewhere else. For example you can
use this to pass data between plugins.

Note though that these notes will be lost when a transaction ends, for
example on a C<RSET> or after C<DATA> completes, so you might want to
use the notes field in the C<Qpsmtpd::Connection> object instead.

=head2 body_filename ( )

Returns the temporary filename used to store the message contents; useful for
virus scanners so that an additional copy doesn't need to be made.

=head2 body_write( $data )

Write data to the end of the email.

C<$data> can be either a plain scalar, or a reference to a scalar.

=head2 body_size( )

Get the current size of the email.

=head2 body_resetpos( )

Resets the body filehandle to the start of the file (via C<seek()>).

Use this function before every time you wish to process the entire
body of the email to ensure that some other plugin has not moved the
file pointer.

=head2 body_getline( )

Returns a single line of data from the body of the email.

=head1 SEE ALSO

L<Mail::Header>, L<Qpsmtpd::Address>, L<Qpsmtpd::Connection>

=cut
