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
use EBook::EPUB;
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
sub main;
sub fetchUrlToTempFile;
sub parseIndex;
sub outputOrgFormat;
sub outputEpubFormat;
# end function declarations

# global variables
my $plaintextPattern = qr/&nbsp;&nbsp;&nbsp;&nbsp;(.+)<br \/>/;

my $http = HTTP::Tiny->new();
# end global variables

main();

# function definitions
sub main()
{
  # command line arguments
  my @indexUrls = @ARGV;
  # end command line arguments

  for my $indexUrl (@indexUrls)
  {
    my $novel = parseIndex( fetchUrlToTempFile( $indexUrl ) );

    #outputOrgFormat( $novel );
    outputEpubFormat( $novel );
  }
}

sub fetchUrlToTempFile
{
  my $url = shift;

  my $response  = $http->get( $url );

  die "$url Fail!\n" unless $response->{success};

  gb_to_trad( $response->{content} );

  my $fileT = File::Temp->new();
  my $pos   = $fileT->getpos();

  binmode $fileT, ":encoding(utf8)";
  print $fileT $response->{content};
  $fileT->setpos($pos);

  return $fileT;
}

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

sub outputOrgFormat
{
  my $novel = shift;

  print "#+TITLE: ", $novel->title(), "\n";
  print "#+AUTHOR: ", $novel->author(), "\n";
  print "#+OPTIONS: toc:nil num:nil\n";

  for my $book (@{$novel->books()})
  {
    print "* ", $book->name(), "\n";

    for my $chapter (@{$book->chapters()})
    {
       my $fileT = fetchUrlToTempFile( $chapter->url() );

       print "** ", $chapter->name(), "\n";

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

sub outputEpubFormat
{
  my $novel = shift;

  my $epub      = EBook::EPUB->new();
  my $filename  = "index.xhtml";
  my $order     = 1;

  # setup meta data
  $epub->add_title    ( $novel->title ()  );
  $epub->add_author   ( $novel->author()  );
  $epub->add_language ( 'zh_TW'           );
  # end setup meta data

  my $rootContent =
    '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">' . "\n" .
    '<html xmlns="http://www.w3.org/1999/xhtml">' . "\n" .
    '<head><title></title></head>' . "\n" .
    '<body><h1>' . $novel->title() . '</h1></body></html>';
  my $root        =  $epub->add_navpoint(
                                           label       => $novel->title(),
                                           id          => $epub->add_xhtml( $filename, $rootContent ),
                                           content     => $filename,
                                           play_order  => $order++,
                     );

  while( my ($i, $book) = each @{$novel->books()} )
  {
     $filename = "book" . ( $i + 1 ) . ".xhtml";

     my $bookContent  =
        '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">' . "\n" .
        '<html xmlns="http://www.w3.org/1999/xhtml">' . "\n" .
        '<head><title></title></head>' . "\n" .
        '<body><h2>' . $book->name() . '</h2></body></html>';
     my $bookNavPoint = $root->add_navpoint(
                                              label       => $book->name(),
                                              id          => $epub->add_xhtml( $filename, $bookContent ),
                                              content     => $filename,
                                              play_order  => $order++,
                        );

     while( my ($j, $chapter) = each @{$book->chapters()} )
     {
        my $fileT   = fetchUrlToTempFile( $chapter->url() );
        my $content =
            '<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">' . "\n" .
            '<html xmlns="http://www.w3.org/1999/xhtml">' . "\n" .
            '<head><title></title></head>' . "\n" .
            "<body>\n" .
            '<h3>' . $chapter->name() . '</h3>' . "\n" .
            '<p><br />' . "\n";

        $filename = "chapter" . ( $i + 1 ) . "_" . ( $j + 1 ) . ".xhtml";

        while( <$fileT> )
        {
          if( my ($text) = /$plaintextPattern/ )
          {
            $content .= '&nbsp;' x 4 . "$text<br />\n" .
                        "<br />\n";
          }
        }
        $content .= '</p></body></html>';

        my $chapterNavPoint = $bookNavPoint->add_navpoint(
                                                            label       => $chapter->name(),
                                                            id          => $epub->add_xhtml( $filename, $content ),
                                                            content     => $filename,
                                                            play_order  => $order++,
                              );
     }
  }
  $epub->pack_zip( "test.epub" );
}
# end function definitions
