#!/usr/bin/perl
package NovelDownloader::Exporter::ComicBusExporter;

use Moose;

with 'NovelDownloader::Exporter';

# packages
use EBook::EPUB;

use XHTML::Writer;
# end packages

# public member functions
sub exportOrgCore;
sub exportEpubCore;
# end public member functions

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

      while( my ( $k, $page ) = each @pages )
      {
        my $filename = "image${ \( $i + 1 ) }_${ \( $j + 1 ) }_${ \( $k + 1 ) }.jpg";
        my $response = $self->downloader()->http()->get( $page );

        die "$page Fail!" unless $response->{success};

        $epub->add_image( $filename, $response->{content}, 'image/jpeg' );

        push @images, $filename;
      }

      $xhtml->startTag( 'p' );
      $xhtml->emptyTag( 'img', src => $_, alt => $_, height => "100%" ) for @images;
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
      last;
    }
  }
  $epub->pack_zip( $self->outputFileName() );
}
# end public member functions

no Moose;
1;
