#!/usr/bin/perl
package NovelDownloader::Exporter;

use Moose::Role;

# pragmas
binmode STDOUT, ":encoding(utf8)";
# end pragmas

# global variables
my %formats = (
                org   =>  {
                            name            =>  'org',
                            exportFunction  =>  \&exportOrg,
                          },
                epub  =>  {
                            name            =>  'epub',
                            exportFunction  =>  \&exportEpub,
                          },
              );
# end global variables

# attributes
has 'downloader' =>
(
  is    => 'rw',
  does  => 'NovelDownloader::Downloader',
);

has 'outputFileName' =>
(
  is  => 'rw',
  isa => 'Str',
);

# end attributes

# public member functions
sub export;
sub exportOrg;
sub exportEpub;

requires qw/exportOrgCore exportEpubCore/;
# end public member functions

# public member functions
sub export
{
  my ( $self, $url, $formatName ) = @_;

  defined $self->downloader() or die "No downloader being set!\n";

  my $data = $self->downloader()->parseIndex( $url );

  for my $format ( values %formats )
  {
    if( $formatName eq $format->{name} )
    {
      $self->${ \$format->{exportFunction} }( $data );
      last;
    }
  }
}

sub exportOrg
{
  my ( $self, $data ) = @_;

  my $fh;

  if( defined $self->outputFileName() )
  {
    open $fh, ">", $self->outputFileName();

    binmode $fh, ":encoding(utf8)";
    select $fh;
  }
  $self->exportOrgCore( $data );

  close $fh if defined $fh;
}

sub exportEpub
{
  my ( $self, $data ) = @_;

  defined $self->outputFileName() or die "Forget to specify output file name!";

  $self->exportEpubCore( $data );
}
# end public member functions

no Moose::Role;
1;
