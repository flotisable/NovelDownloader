#!/usr/bin/perl
package NovelDownloader::Downloader::ComicBusDownloader;

use Moose;

with 'NovelDownloader::Downloader';

# packages
use Class::Struct;
# end packages

# structure declarations
struct( Comic =>  {
                    title   => '$',
                    author  => '$',
                    books   => '@',
                  } );
struct( Book  =>  {
                    chapters  => '@',
                  } );
struct( Chapter =>  {
                      pages => '@',
                    } );
# end structure declarations

# public member functions
sub parseIndexCore;
sub parseContentCore;
# end public member functions

# private member functions
sub processfetchedContent;
# end private member functions

# public member functions
sub parseIndexCore
{
  my ( $self, $fh ) = @_;

  open my $file, '>', 'Temp/index.html';

  print $file "$_\n" while( <$fh> );

  return '';
}

sub parseContentCore
{
  my ( $self, $fh ) = @_;
}
# end public member functions

# private member functions
sub processfetchedContent
{
  my ( $self, $content ) = @_;

  return $content;
}
# end private member functions

no Moose;
1;
