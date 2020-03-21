#!/usr/bin/perl
package NovelDownloader::Downloader::ComicBusDownloader;

use Moose;

with 'NovelDownloader::Downloader';

# pragmas
use utf8;
# end pragmas

# packages
use Class::Struct;
use Data::Dump      qw/dump/;

use Encode qw/decode/;
# end packages

# structure declarations
struct( Comic =>  {
                    title   => '$',
                    author  => '$',
                    cover   => '$',
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

  my %pattern = (
                  title     => qr/<img src="..\/images\/bon_1.gif" width="4" height="11" hspace="6" \/><font color="#FFFFFF" style="font-size:10pt; letter-spacing:1px">(.+)<\/font>/,
                  cover     => qr/<img src='\/(pics\/0\/\d+.jpg)' hspace="10" vspace="10" border="0" style="border:#CCCCCC solid 1px;width:240px;" \/>/,
                  authorPre => qr/作者：/,
                  author    => qr/<td nowrap="nowrap">(.+)<\/td>/,
                  chapter   => qr/<a href='#' onclick="cview\('(\d+-(\d+)\.html)',6,1\);return false;" id="c\d+" class="Ch">/,
                );

  my $comic = Comic->new( books => [ Book->new() ] );

  while( <$fh> )
  {
    $comic->title( $1 ) if /$pattern{title}/; # get title

    if( my ( $path ) = /$pattern{cover}/ ) # get cover image
    {
      my $url = ( $self->url() =~ s/html\/\d+\.html/$path/r );

      $comic->cover( $url );
    }
    if( /$pattern{authorPre}/ ) # get author
    {
      my $line;

      1 until not defined( $line = <$fh> ) or $line =~ /$pattern{author}/;

      $comic->author( $1 );
    }
    if( my ( $path, $index ) = /$pattern{chapter}/ ) # get chapters
    {
      my $chapters  = $comic->books( -1 )->chapters();
      my $url       = $self->url();

      next if $index < scalar @$chapters;

      $url =~ s/\d+\.html/$path/;

      push @$chapters, $url;
    }
  }
  return $comic;
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

  return decode( 'big5', $content );
}
# end private member functions

no Moose;
1;
