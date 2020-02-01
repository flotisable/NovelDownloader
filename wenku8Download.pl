#!/usr/bin/perl
# pragmas
use strict;
use warnings;
use utf8;

binmode STDOUT, ":encoding(utf8)";
# end pragmas

# packages
use HTTP::Tiny;
use File::Temp      qw/tempfile/;
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

# function declarations
sub parseIndex;
# end function declarations

my $plaintextPattern = qr/&nbsp;&nbsp;&nbsp;&nbsp;(.+)<br \/>/;

# command line arguments
my @indexUrls = @ARGV;
# end command line arguments

# main procedure
my $http = HTTP::Tiny->new();

for my $indexUrl (@indexUrls)
{
  my $response = $http->get( $indexUrl );

  die "$indexUrl Fail!\n" unless $response->{success};

  gb_to_trad( $response->{content} );

  my $fileT = File::Temp->new();
  my $pos   = $fileT->getpos();

  binmode $fileT, ":encoding(utf8)";
  print $fileT $response->{content};
  $fileT->setpos($pos);

  my $novel = parseIndex( $fileT );

  print "#+TITLE: ", $novel->title(), "\n";
  print "#+AUTHOR: ", $novel->author(), "\n";
  print "#+OPTIONS: toc:nil num:nil\n";

  for my $book (@{$novel->books()})
  {
    print "* ", $book->name(), "\n";

    for my $chapter (@{$book->chapters()})
    {
       $response = $http->get( $chapter->url() );

       die "$indexUrl Fail!\n" unless $response->{success};

       gb_to_trad( $response->{content} );

       print "** ", $chapter->name(), "\n";

       $fileT = File::Temp->new();
       $pos   = $fileT->getpos();

       binmode $fileT, ":encoding(utf8)";
       print $fileT $response->{content};
       $fileT->setpos($pos);

       while( <$fileT> )
       {
          if( my ($content) = /$plaintextPattern/ )
          {
            print "$content\n\n";
          }
       }
    }
  }
}
# end main procedure

# function definitions
sub parseIndex
{
  my $titlePattern    = qr/<div id="title">(.+)<\/div>/;
  my $authorPattern   = qr/<div id="info">作者：(.+)<\/div>/;
  my $bookPattern     = qr/<td class="vcss" colspan="4">(.+)<\/td>/;
  my $chapterPattern  = qr/<td class="ccss"><a href="(.+)">(.+)<\/a><\/td>/;

  my $fh = shift;

  my $novel = Novel->new();
  my $book;

  while( <$fh> )
  {
    if( my ($title) = /$titlePattern/ )
    {
      $novel->title( $title );
      last;
    }
  }
  while( <$fh> )
  {
    if( my ($author) = /$authorPattern/ )
    {
      $novel->author( $author );
      last;
    }
  }
  while( <$fh> )
  {
    if( my ($bookname) = /$bookPattern/ )
    {
      $book = Book->new( name => $bookname );
      push @{$novel->books()}, $book;
      next;
    }
    if( my ($url, $chapter) = /$chapterPattern/ )
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
# end function definitions
