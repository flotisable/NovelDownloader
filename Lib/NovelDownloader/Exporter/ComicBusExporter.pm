#!/usr/bin/perl
package NovelDownloader::Exporter::ComicBusExporter;

use Moose;

with 'NovelDownloader::Exporter';

# packages
use EBook::EPUB;

use XHTML::Writer;
# end packages

# public member functions
sub exportOrgCore;
sub exportEpubCore;
# end public member functions

# public member functions
sub exportOrgCore
{
  my ( $self, $comic ) = @_;
}

sub exportEpubCore
{
  my ( $self, $comic ) = @_;
}
# end public member functions

no Moose;
1;
