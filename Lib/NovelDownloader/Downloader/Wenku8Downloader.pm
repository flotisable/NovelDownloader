#!/usr/bin/perl
package NovelDownloader::Downloader::Wenku8Downloader;

use Moose;

with 'NovelDownloader::Downloader';

# pragmas
use utf8;

use constant
{
  TITLE_PATTERN     => qr/<div id="title">(.+)<\/div>/,
  AUTHOR_PATTERN    => qr/<div id="info">作者：(.+)<\/div>/,
  BOOK_PATTERN      => qr/<td class="vcss" colspan="4">(.+)<\/td>/,
  CHAPTER_PATTERN   => qr/<td class="ccss"><a href="(.+)">(.+)<\/a><\/td>/,
  PLAINTEXT_PATTERN => qr/&nbsp;&nbsp;&nbsp;&nbsp;(.+)<br \/>/,
};
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
    if( my ( $title ) = /${ \TITLE_PATTERN }/ )
    {
      $novel->title( $title );
      last;
    }
  }
  while( <$fh> )
  {
    if( my ( $author ) = /${ \AUTHOR_PATTERN }/ )
    {
      $novel->author( $author );
      last;
    }
  }
  while( <$fh> )
  {
    if( my ( $bookname ) = /${ \BOOK_PATTERN }/ )
    {
      $book = Book->new( name => $bookname );
      push @{$novel->books()}, $book;
      next;
    }
    if( my ( $url, $chapter ) = /${ \CHAPTER_PATTERN }/ )
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

  return map /${ \PLAINTEXT_PATTERN }/, <$fh>;
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
