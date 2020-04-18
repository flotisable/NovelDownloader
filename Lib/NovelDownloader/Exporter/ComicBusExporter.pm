#!/usr/bin/perl
package NovelDownloader::Exporter::ComicBusExporter;

use Moose;

with 'NovelDownloader::Exporter';

# pragmas
use constant MAX_TRY_TIMES => 10;
# end pragmas

# packages
use IO::Pipe;
use HTTP::Tiny;
use File::Temp;
use File::Path  qw/remove_tree/;

use EBook::EPUB;

use XHTML::Writer;
use MultiTask::ProcessFactory;
use MultiTask::ProcessSchedulizer;
# end packages

# public member functions
sub exportOrgCore;
sub exportEpubCore;
# end public member functions

# private member functions
sub fetchBookWithProcess;
sub fetchChapterWithProcess;
sub fetchImageWithProcess;
# end private member functions

# attributes
has processFactory =>
(
  is      =>  'ro',
  isa     =>  'MultiTask::ProcessFactory',
  default =>  sub
              {
                MultiTask::ProcessFactory->new(
                                                maxProcessNum => 8,
                                                ipcToParent   => 1,
                                              );
              },
);
# end attributes

# public member functions
sub exportOrgCore
{
  my ( $self, $comic ) = @_;

  print "#+TITLE: ",      $comic->title (), "\n";
  print "#+AUTHOR: ",     $comic->author(), "\n";
  print "#+EPUBCOVER: ",  $comic->cover (), "\n";
  print "#+OPTIONS: toc:nil num:nil\n";
    print "[[", $comic->cover(), "]]\n";

  while( my ( $i, $book ) = each @{ $comic->books() } )
  {
    print "* ", ( $i == $#{ $comic->books() } ) ? "Other" : "Volume ${ \( $i + 1 ) }", "\n";

    while( my ( $j, $chapter ) = each @{ $book->chapters() } )
    {
      print "** Chapter ${ \( $j + 1 ) }\n";
      print "   [[$_]]\n" for $self->downloader()->parseContent( $chapter );
      last;
    }
  }
}

sub exportEpubCore
{
  my ( $self, $comic ) = @_;

  my $epub      = EBook::EPUB->new();
  my $coverUrl  = $comic->cover();

  # setup meta datas
  $epub->add_title    ( $comic->title () );
  $epub->add_author   ( $comic->author() );
  $epub->add_language ( 'zh_TW' );

  my $response = $self->downloader()->http()->get( $coverUrl );

  die "$coverUrl Fail!" unless $response->{success};

  my $coverId = $epub->add_image( 'cover.jpg', $response->{content}, 'image/jpeg' );

  $epub->add_meta_item( 'cover', $coverId );
  # end setup meta datas

  my $root;
  my $order = 1;
  my $id    = 1;
  my @books;

  MultiTask::ProcessSchedulizer->new( ipcToParent => 1 )->schedule(
      $comic->books(),
      generate    =>  sub
                      {
                        my ( $i, $book ) = @_;

                        return $self->fetchBookWithProcess( $epub, $i, $book );
                      },
      getFailArgs =>  sub
                      {
                        my $processInfo = shift;

                        return @{ $processInfo }{qw/bookIndex book/};
                      },
      ipcToParent =>  sub
                      {
                        my ( $bookIndex, @chapters ) = split;

                        $books[$bookIndex] = [@chapters];
                      },
    );

  while( my ( $i, $book ) = each @books )
  {
    my $bookNavPoint;

    while( my ( $j, $chapterFileName ) = each @$book )
    {
      next unless defined $chapterFileName;

      my $filename = "chapter${ \( $i + 1 ) }_${ \( $j + 1 ) }.xhtml";

      $epub->copy_xhtml( $chapterFileName, $filename );

      remove_tree( $chapterFileName );

      if( $j == 0 )
      {
        if( $i == 0 )
        {
          $root = $epub->add_navpoint (
                                        label       => 'Root',
                                        id          => "id_${ \( $id++ )}",
                                        content     => $filename,
                                        play_order  => $order,
                                      );
        }
        $bookNavPoint = $root->add_navpoint (
                                              label       => ( $i == $#{ $comic->books() } ) ? "Other" : "Volume ${ \( $i + 1 ) }",
                                              id          => "id_${ \( $id++ ) }",
                                              content     => $filename,
                                              play_order  => $order,
                                            );
      }
      $bookNavPoint->add_navpoint (
                                    label       => "Chapter ${ \( $j + 1 ) }",
                                    id          => "id_${ \( $id++ ) }",
                                    content     => $filename,
                                    play_order  => $order,
                                  );
      ++$order;
    }
  }
  $epub->pack_zip( $self->outputFileName() );
}
# end public member functions

# private member functions
sub fetchBookWithProcess
{
  my ( $self, $epub, $bookIndex, $book ) = @_;

  return $self->processFactory()->generate(
      fail  =>  sub
                {
                  return  {
                            bookIndex => $bookIndex,
                            book      => $book,
                          };
                },
      run   =>  sub
                {
                  my $c2p = shift;

                  my @chapters;

                  MultiTask::ProcessSchedulizer->new( ipcToParent => 1 )->schedule(
                      $book->chapters(),
                      generate    =>  sub
                                      {
                                        my ( $j, $chapter ) = @_;

                                        return $self->fetchChapterWithProcess( $epub, $bookIndex, $j, $chapter );
                                      },
                      getFailArgs =>  sub
                                      {
                                        my $processInfo = shift;

                                        return @{ $processInfo }{qw/chapterIndex url/};
                                      },
                      ipcToParent =>  sub
                                      {
                                        my ( $chapterIndex, $chapterFileName ) = split;

                                        $chapters[$chapterIndex] = $chapterFileName;
                                      },
                    );

                  print $c2p "$bookIndex @chapters";
                },
    );
}

sub fetchChapterWithProcess
{
  my ( $self, $epub, $bookIndex, $chapterIndex, $url ) = @_;

  return $self->processFactory()->generate(
      fail  =>  sub
                {
                  return  {
                            bookIndex     => $bookIndex,
                            chapterIndex  => $chapterIndex,
                            url           => $url,
                          };
                },
      run   =>  sub
                {
                  my $c2p = shift;

                  my @images;

                  MultiTask::ProcessSchedulizer->new( ipcToParent => 1 )->schedule(
                      [ ${ \( ref $self->downloader() ) }->new()->parseContent( $url ) ],
                      generate    =>  sub
                                      {
                                        my ( $i, $page ) = @_;

                                        return $self->fetchImageWithProcess( $i, $page );
                                      },
                      getFailArgs =>  sub
                                      {
                                        my $processInfo = shift;

                                        return @{ $processInfo }{qw/pageIndex url/};
                                      },
                      ipcToParent =>  sub
                                      {
                                        my ( $pageIndex, $imageFilename ) = split;

                                        $images[$pageIndex] = $imageFilename;
                                      },
                    );

                  while( my ( $k, $imageFilename ) = each @images )
                  {
                    next unless defined $imageFilename;

                    my $filename = "image${ \( $bookIndex + 1 )}_${ \( $chapterIndex + 1 ) }_${ \( $k + 1 ) }.jpg";

                    $epub->copy_image( $imageFilename, $filename, 'image/jpeg' );
                    $images[$k] = $filename;

                    remove_tree( $imageFilename );
                  }

                  my $fh    = File::Temp->new( UNLINK => 0 );
                  my $xhtml = XHTML::Writer->new( OUTPUT => $fh, DATA_MODE => 1, DATA_INDENT => 2 );

                  $xhtml->startTag( 'p' );
                  for my $image ( @images )
                  {
                     next unless defined $image;

                     $xhtml->emptyTag( 'img', src => $image, alt => $image, height => "100%" );
                  }
                  $xhtml->endTag  ( 'p' );
                  $xhtml->end();

                  print $c2p "$chapterIndex $fh";
                },
    );
}

sub fetchImageWithProcess
{
  my ( $self, $pageIndex, $url ) = @_;

  return $self->processFactory()->generate(
      fail  =>  sub
                {
                  return  {
                            pageIndex => $pageIndex,
                            url       => $url,
                          };
                },
      run   =>  sub
                {
                  my $c2p = shift;

                  local $@;

                  my $http      = HTTP::Tiny->new();
                  my $response;

                  for my $i ( 1 .. MAX_TRY_TIMES )
                  {
                     eval
                     {
                       $response = $http->get( $url );

                       die "$url Fail!\n" unless $response->{success};
                     };
                     last unless $@;
                  }
                  die $@ if $@;

                  my $fh = File::Temp->new( UNLINK => 0 );

                  binmode $fh;
                  print $fh   $response->{content};
                  print $c2p  "$pageIndex $fh";
                },
    );
}
# end private member functions

no Moose;
1;
