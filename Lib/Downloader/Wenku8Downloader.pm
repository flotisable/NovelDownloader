#!/usr/bin/perl
package Downloader::Wenku8Downloader;

# pragmas
use strict;
use warnings;
use utf8;
# end pragmas

# packages
use HTTP::Tiny;
use File::Temp;
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
sub new;
sub parseIndex;
sub parseContent;
# end public member functions

# private member functions
sub fetchUrlToTempFile;
# end private member functions

# public member functions
sub new
{
  my $class   = shift;
  my $object  = {
                  http => HTTP::Tiny->new(),
                };

  return bless $object, $class;
}

sub parseIndex
{
  my ( $self, $url ) = @_;

  my $fh    = $self->fetchUrlToTempFile( $url );
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

sub parseContent
{
  my ( $self, $url ) = @_;

  my $fh        = $self->fetchUrlToTempFile( $url );
  my @contents;

  while( <$fh> )
  {
    push @contents, $1 if /$patterns{plaintext}/;
  }
  return @contents;
}
# end public member functions

# private member functions
sub fetchUrlToTempFile
{
  my ( $self, $url ) = @_;

  my $response = $self->{http}->get( $url );

  die "$url Fail!\n" unless $response->{success};

  gb_to_trad( $response->{content} );

  my $file  = File::Temp->new();
  my $pos   = $file->getpos();

  binmode $file, ":encoding(utf8)";
  print $file $response->{content};
  $file->setpos($pos);

  return $file;
}
# end private member functions

1;
