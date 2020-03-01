#!/usr/bin/perl
package NovelDownloader::Downloader::Wenku8Downloader;

use Moose;

with 'NovelDownloader::Downloader';

# pragmas
use utf8;
# end pragmas

# packages
use Class::Struct;

use Encode::HanConvert;
# end packages

# structure declarations
struct( Novel =>  {
                    title   => '$',
                    author  => '$',
                    books   => '@',
                  } );
struct( Book => {
                  name      => '$',
                  chapters  => '@',
                } );
struct( Chapter =>  {
                      name  => '$',
                      url   => '$',
                    } );
# end structure declarations

# global variables
my %patterns =  (
                  title     => qr/<div id="title">(.+)<\/div>/,
                  author    => qr/<div id="info">作者：(.+)<\/div>/,
                  book      => qr/<td class="vcss" colspan="4">(.+)<\/td>/,
                  chapter   => qr/<td class="ccss"><a href="(.+)">(.+)<\/a><\/td>/,
                  plaintext => qr/&nbsp;&nbsp;&nbsp;&nbsp;(.+)<br \/>/,
                );
# end global variables

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

  my $novel = Novel->new();
  my $book;

  while( <$fh> )
  {
    if( my ( $title ) = /$patterns{title}/ )
    {
      $novel->title( $title );
      last;
    }
  }
  while( <$fh> )
  {
    if( my ( $author ) = /$patterns{author}/ )
    {
      $novel->author( $author );
      last;
    }
  }
  while( <$fh> )
  {
    if( my ( $bookname ) = /$patterns{book}/ )
    {
      $book = Book->new( name => $bookname );
      push @{$novel->books()}, $book;
      next;
    }
    if( my ( $url, $chapter ) = /$patterns{chapter}/ )
    {
      my $chapter = Chapter->new(
                      name  => $chapter,
                      url   => $url,
                    );
      push @{$book->chapters()}, $chapter;
      next;
    }
  }
  return $novel;
}

sub parseContentCore
{
  my ( $self, $fh ) = @_;

  my @contents;

  while( <$fh> )
  {
    push @contents, $1 if /$patterns{plaintext}/;
  }
  return @contents;
}
# end public member functions

# private member functions
sub processfetchedContent
{
  my ( $self, $content ) = @_;

  return gb_to_trad( $content );
}
# end private member functions

no Moose;
1;
