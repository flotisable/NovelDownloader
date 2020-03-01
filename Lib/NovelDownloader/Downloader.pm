#!/usr/bin/perl
package NovelDownloader::Downloader;

use Moose::Role;

# packages
use HTTP::Tiny;
use File::Temp;
# end packages

# public member functions
sub parseIndex;
sub parseContent;

requires qw/parseIndexCore parseContentCore/;
# end public member functions

# private member functions
sub fetchUrlToTempFile;

requires 'processfetchedContent';
# end private member functions

# attributes
has 'http' =>
(
  is      => 'ro',
  isa     => 'HTTP::Tiny',
  default => sub { return HTTP::Tiny->new() },
);
# end attributes

# public member functions
sub parseIndex
{
  my ( $self, $url ) = @_;

  return $self->parseIndexCore( $self->fetchUrlToTempFile( $url ) );
}

sub parseContent
{
  my ( $self, $url ) = @_;

  return $self->parseContentCore( $self->fetchUrlToTempFile( $url ) );
}
# end public member functions

# private member functions
sub fetchUrlToTempFile
{
  my ( $self, $url ) = @_;

  my $response = $self->http()->get( $url );

  die "$url Fail!\n" unless $response->{success};

  my $file  = File::Temp->new();
  my $pos   = $file->getpos();

  binmode $file, ":encoding(utf8)";
  print $file $self->processfetchedContent( $response->{content} );
  $file->setpos($pos);

  return $file;
}
# end private member functions

no Moose::Role;
1;
