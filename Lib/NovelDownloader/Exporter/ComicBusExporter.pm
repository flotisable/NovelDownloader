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
use File::Path      qw/remove_tree/;
use File::Basename;

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

  my $coverUrl = $comic->cover();
  my $response = $self->downloader()->http()->get( $coverUrl );

  die "$coverUrl Fail!" unless $response->{success};

  my $fh = File::Temp->new( UNLINK => 0 );

  binmode $fh;
  print $fh $response->{content};

  MultiTask::ProcessSchedulizer->new()->schedule(
      $comic->books(),
      generate    =>  sub
                      {
                        my ( $i, $book ) = @_;

                        return $self->fetchBookWithProcess( $comic->title (),
                                                            $comic->author(),
                                                            "$fh",
                                                            scalar @{ $comic->books() },
                                                            $i,
                                                            $book );
                      },
      getFailArgs =>  sub
                      {
                        my $processInfo = shift;

                        return @{ $processInfo }{qw/bookIndex book/};
                      },
    );

  remove_tree( "$fh" );

  sleep 1 until wait == -1;
}
# end public member functions

# private member functions
sub fetchBookWithProcess
{
  my ( $self, $title, $author, $cover, $bookNum, $bookIndex, $book ) = @_;

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
                  srand $bookIndex; # set seed of rand to make tempfile generation successful

                  return if scalar $book->chapters() == 0; # do not generate epub file for empty book

                  my $epub = EBook::EPUB->new();

                  # setup meta datas
                  $epub->add_title    ( $title  );
                  $epub->add_author   ( $author );
                  $epub->add_language ( 'zh_TW' );

                  my $coverId = $epub->copy_image( $cover, 'cover.jpg', 'image/jpeg' );

                  $epub->add_meta_item( 'cover', $coverId );
                  # end setup meta datas

                  my $root;
                  my $order     = 1;
                  my $id        = 1;
                  my @chapters;

                  MultiTask::ProcessSchedulizer->new( ipcToParent => 1 )->schedule(
                      $book->chapters(),
                      generate    =>  sub
                                      {
                                        my ( $j, $chapter ) = @_;

                                        return $self->fetchChapterWithProcess( $epub, $j, $chapter );
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

                  while( my ( $j, $chapterFileName ) = each @chapters )
                  {
                    next unless defined $chapterFileName;

                    my $filename = "chapter${ \( $j + 1 ) }.xhtml";

                    $epub->copy_xhtml( $chapterFileName, $filename );

                    remove_tree( $chapterFileName );

                    if( $j == 0 )
                    {
                      $root = $epub->add_navpoint (
                                                    label       => 'Root',
                                                    id          => "id_${ \( $id++ )}",
                                                    content     => $filename,
                                                    play_order  => $order,
                                                  );
                    }
                    $root->add_navpoint (
                                          label       => "Chapter ${ \( $j + 1 ) }",
                                          id          => "id_${ \( $id++ ) }",
                                          content     => $filename,
                                          play_order  => $order,
                                        );
                    ++$order;
                  }

                  my ( $filename, $dir, $suffix ) = fileparse( $self->outputFileName(), qr/\.\w+/ );
                  my $outputFileNameSuffix        = "";

                  if( $bookNum > 1 )
                  {
                    $outputFileNameSuffix = ( $bookIndex == $bookNum - 1 ) ?  "Other":
                                                                              "${ \( $bookIndex + 1 ) }";
                  }
                  $epub->pack_zip( "${dir}${filename}${outputFileNameSuffix}${suffix}" );
                },
    );
}

sub fetchChapterWithProcess
{
  my ( $self, $epub, $chapterIndex, $url ) = @_;

  return $self->processFactory()->generate(
      fail  =>  sub
                {
                  return  {
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

                    my $filename = "image${ \( $chapterIndex + 1 ) }_${ \( $k + 1 ) }.jpg";

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
