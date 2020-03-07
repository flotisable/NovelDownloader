#!/usr/bin/perl
package NovelDownloader::ProcessorFactory;

use Moose;

use constant BUILDIN_PROCESSOR_CONFIG_FILE => 'processors.txt';

use Module::Load;

has processors =>
(
  is      =>  'ro',
  isa     =>  'ArrayRef[HashRef[Defined]]',
  default =>  sub { [] },
);

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

no Moose;
1;
