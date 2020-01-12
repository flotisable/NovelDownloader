#!/usr/bin/perl
use strict;
use warnings;

# packages
use HTTP::Tiny;
use Encode          qw/from_to/;
use File::Temp      qw/tempfile/;
use Class::Struct;
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

# command line arguments
my @indexUrls = @ARGV;
# end command line arguments

# main procedure
my $http = HTTP::Tiny->new();

for my $indexUrl (@indexUrls)
{
  my $response = $http->get( $indexUrl );

  die "$indexUrl Fail!\n" unless $response->{success};

  from_to( $response->{content}, 'cp936', 'utf8' );

  my $fileT = File::Temp->new();

  print $fileT $response->{content};

  my $novel = parseIndex( $fileT->filename() );

  print "標題: ", $novel->title(), "\n";
  print "作者: ", $novel->author(), "\n";

  for my $book (@{$novel->books()})
  {
    print $book->name(), "\n";

    for my $chapter (@{$book->chapters()})
    {
       print $chapter->name(), ": ", $chapter->url(), "\n";
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

  my $filename = shift;

  my $novel = Novel->new();
  my $book;

  open my $fh, '<', $filename;

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
  close $fh;

  return $novel;
}
# end function definitions
