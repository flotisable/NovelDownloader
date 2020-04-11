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
use MultiTask::ProcessPool;
# end packages

# public member functions
sub exportOrgCore;
sub exportEpubCore;
# end public member functions

# private member functions
sub fetchImageWithProcess;
# end private member functions

# attributes
has processPool =>
(
  is      => 'ro',
  isa     => 'MultiTask::ProcessPool',
  default => sub { MultiTask::ProcessPool->new( maxProcessNum => 8 ); },
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

  while( my ( $i, $book ) = each @{ $comic->books() } )
  {
    my $bookNavPoint;

    while( my ( $j, $chapter ) = each @{ $book->chapters() } )
    {
      my $filename  = "chapter${ \( $i + 1 ) }_${ \( $j + 1 ) }.xhtml";
      my $xhtml     = XHTML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2 );
      my @pages     = $self->downloader()->parseContent( $chapter );
      my @images;
      my @processInfos;

      while( my ( $i, $page ) = each @pages )
      {
        push @processInfos, $self->fetchImageWithProcess( $i, $page );
      }

      while( my $processInfo = shift @processInfos )
      {
        unless( exists $processInfo->{pid} ) # recreate child process if it fails
        {
          push @processInfos, $self->fetchImageWithProcess( @{ $processInfo }{qw/pageIndex url/} );
          next;
        }
        my $c2p = $processInfo->{c2p};

        waitpid $processInfo->{pid}, 0;

        while( <$c2p> )
        {
          my ( $pageIndex, $imageFilename ) = split;

          $images[$pageIndex] = $imageFilename;
        }
      }

      while( my ( $k, $imageFilename ) = each @images )
      {
        next unless defined $imageFilename;

        my $filename = "image${ \( $i + 1 ) }_${ \( $j + 1 ) }_${ \( $k + 1 ) }.jpg";

        $epub->copy_image( $imageFilename, $filename, 'image/jpeg' );
        $images[$k] = $filename;

        remove_tree( $imageFilename );
      }

      $xhtml->startTag( 'p' );
      for my $image ( @images )
      {
         next unless defined $image;

         $xhtml->emptyTag( 'img', src => $image, alt => $image, height => "100%" );
      }
      $xhtml->endTag  ( 'p' );
      $xhtml->end();

      $epub->add_xhtml( $filename, $xhtml );

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
sub fetchImageWithProcess
{
  my ( $self, $pageIndex, $url ) = @_;

  my $c2p = IO::Pipe->new();
  my $pid = $self->processPool()->fork();

  return  {
            pageIndex => $pageIndex,
            url       => $url,
          } unless defined $pid; # fail to create process

  if( $pid == 0 ) # child process
  {
    local $@;

    my $http      = HTTP::Tiny->new();
    my $response;
    my $fh;

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

    $fh = File::Temp->new( UNLINK => 0 );

    binmode $fh;
    print $fh $response->{content};

    $c2p->writer();

    print $c2p "$pageIndex $fh";

    exit;
  }

  # main process
  $c2p->reader();

  return  {
            pid => $pid,
            c2p => $c2p,
          };
}
# end private member functions

no Moose;
1;
