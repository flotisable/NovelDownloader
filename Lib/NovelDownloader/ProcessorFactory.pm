#!/usr/bin/perl
package NovelDownloader::ProcessorFactory;

use Moose;

# pragmas
use constant BUILDIN_PROCESSOR_CONFIG_FILE => 'processors.txt';
# end pragmas

# packages
use Module::Load;
# end packages

# attributes
has processors =>
(
  is      =>  'ro',
  isa     =>  'ArrayRef[HashRef[Defined]]',
  default =>  sub { [] },
);
# end attributes

# public member functions
sub BUILD;
sub generate;
# end public member functions

# private member functions
sub loadProcessors;
# end private member functions

# public member functions
sub BUILD
{
  my $self = shift;

  $self->loadProcessors();
}

sub generate
{
  my ( $self, $url ) = @_;

  for my $processor ( @{ $self->processors() } )
  {
     if( $url =~ /$processor->{pattern}/ )
     {
       load $processor->{$_} for qw/downloader exporter/;

       return ( $processor->{downloader}->new(),
                $processor->{exporter}->new()     );
     }
  }
  die "No processor for $url!\n";
};
# end public member functions

# private member functions
sub loadProcessors
{
  my $self = shift;

  open my $fh, '<', BUILDIN_PROCESSOR_CONFIG_FILE;

  while( <$fh> )
  {
    my $processor = {};

    chomp;

    @{$processor}{qw/pattern downloader exporter/}  = split /,/;
    $processor->{pattern}                           = qr/$processor->{pattern}/;

    push @{ $self->processors() }, $processor;
  }
  close $fh;
};
# end private member functions

no Moose;
1;
