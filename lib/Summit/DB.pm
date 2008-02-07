package Summit::DB;

use strict;
use warnings FATAL => 'all';

=item C<params>

Returns an array reference for DBI connection parameters

 $params_ref = SL::DB->params;
 DBI->connect(@{$params_ref});

=cut

sub params {
    my ( $class, %args ) = @_;
    my $db_user = $args{db_user} || 'summit';
    my $db_pass = $args{db_pass} || '';
    my $db_name = $args{db_name} || 'summit';
    my $db_host = $args{db_host};

    my $db_options = {
        RaiseError         => 1,
        PrintError         => 1,
        AutoCommit         => 0,
        FetchHashKeyName   => 'NAME_lc',
        ShowErrorStatement => 1,
        ChopBlanks         => 1,
    };
    my $dsn = qq/dbi:Pg:dbname='$db_name';/;
    $dsn .= "host=$db_host;" if $db_host;

    my @connect = ( $dsn, $db_user, $db_pass, $db_options );
	return wantarray ? @connect : \@connect
}

1;
