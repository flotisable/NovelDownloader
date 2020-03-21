#!/usr/bin/perl
package NovelDownloader::Exporter::Wenku8Exporter;

use Moose;

with 'NovelDownloader::Exporter';

# pragmas
use constant WRITER_DEFAULT_OPTIONS =>
{
  OUTPUT      => 'self',
  DATA_MODE   => 1,
  DATA_INDENT => 2,
};
# end pragmas

# packages
use EBook::EPUB;

use XHTML::Writer;
# end packages

# public member functions
sub exportOrgCore;
sub exportEpubCore;
# end public member functions

# private member functions
sub getNewEpub;
sub exportEpubNovelTitle;
sub exportEpubBookTitle;
sub exportEpubChapter;
# end private member functions

# public member functions
sub exportOrgCore
{
  my ( $self, $novel ) = @_;

  print "#+TITLE: ", $novel->title(), "\n";
  print "#+AUTHOR: ", $novel->author(), "\n";
  print "#+OPTIONS: toc:nil num:nil\n";

  for my $book ( @{ $novel->books() } )
  {
    print "* ", $book->name(), "\n";

    for my $chapter ( @{ $book->chapters() } )
    {
       my @contents = $self->downloader()->parseContent( $chapter->url() );

       print "** ", $chapter->name(), "\n";
       print "$_\n\n" for @contents;
    }
  }
}

sub exportEpubCore
{
  my ( $self, $novel ) = @_;

  my $epub      = $self->getNewEpub( $novel );
  my $filename  = "index.xhtml";
  my $order     = 1;
  my $root      = $self->exportEpubNovelTitle( $epub, $novel, $filename, $order++ );

  while( my ( $i, $book ) = each @{$novel->books()} )
  {
    my $filename      = "book${ \( $i + 1 ) }.xhtml";
    my $bookNavPoint  = $self->exportEpubBookTitle( $epub, $root, $book, $filename, $order++ );

    while( my ( $j, $chapter ) = each @{ $book->chapters() } )
    {
      my $filename = "chapter${ \( $i + 1 ) }_${ \( $j + 1 ) }.xhtml";

      $self->exportEpubChapter( $epub, $bookNavPoint, $chapter, $filename, $order++ );
    }
  }
  $epub->pack_zip( $self->outputFileName() );
}
# end public member functions

# private member functions
sub getNewEpub
{
  my ( $self, $novel ) = @_;

  my $epub = EBook::EPUB->new();

  $epub->add_title    ( $novel->title ()  );
  $epub->add_author   ( $novel->author()  );
  $epub->add_language ( 'zh_TW'           );

  return $epub;
}

sub exportEpubNovelTitle
{
  my ( $self, $epub, $novel, $filename, $order ) = @_;

  my $xhtml = XHTML::Writer->new( %${ \WRITER_DEFAULT_OPTIONS } );

  $xhtml->dataElement( 'h1', $novel->title() );
  $xhtml->end();

  return $epub->add_navpoint(
                              label       => $novel->title(),
                              id          => $epub->add_xhtml( $filename, $xhtml ),
                              content     => $filename,
                              play_order  => $order,
                            );
}

sub exportEpubBookTitle
{
  my ( $self, $epub, $novelNavPoint, $book, $filename, $order ) = @_;

  my $xhtml = XHTML::Writer->new( %${ \WRITER_DEFAULT_OPTIONS } );

  $xhtml->dataElement( 'h2', $book->name() );
  $xhtml->end();

  return $novelNavPoint->add_navpoint (
                                        label       => $book->name(),
                                        id          => $epub->add_xhtml( $filename, $xhtml ),
                                        content     => $filename,
                                        play_order  => $order,
                                      );
}

sub exportEpubChapter
{
  my ( $self, $epub, $bookNavPoint, $chapter, $filename, $order ) = @_;

  my $xhtml = XHTML::Writer->new( %${ \WRITER_DEFAULT_OPTIONS }, UNSAFE => 1 );

  $xhtml->dataElement( 'h3', $chapter->name() );
  $xhtml->startTag( 'p' );
  $xhtml->emptyTag( 'br'  );

  for my $text ( $self->downloader()->parseContent( $chapter->url() ) )
  {
     $xhtml->raw( '&nbsp;' x 4 . "$text" );
     $xhtml->emptyTag( 'br' );
     $xhtml->emptyTag( 'br' );
  }
  $xhtml->endTag( 'p' );
  $xhtml->end   ();

  $bookNavPoint->add_navpoint ( 
                                label       => $chapter->name(),
                                id          => $epub->add_xhtml( $filename, $xhtml ),
                                content     => $filename,
                                play_order  => $order,
                              );
}
# end private member functions

no Moose;
1;
