#!/usr/bin/perl
package Exporter::Wenku8Exporter;

use Moose;

with 'ExporterTemp';

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
  my ( $self, $novel ) = @_;

  print "#+TITLE: ", $novel->title(), "\n";
  print "#+AUTHOR: ", $novel->author(), "\n";
  print "#+OPTIONS: toc:nil num:nil\n";

  for my $book ( @{$novel->books()} )
  {
    print "* ", $book->name(), "\n";

    for my $chapter (@{$book->chapters()})
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

  my $xhtml           = XHTML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2 );
  my $epub            = EBook::EPUB->new();
  my $filename        = "index.xhtml";
  my $order           = 1;
  my %navPointParams;

  # setup meta data
  $epub->add_title    ( $novel->title ()  );
  $epub->add_author   ( $novel->author()  );
  $epub->add_language ( 'zh_TW'           );
  # end setup meta data

  $xhtml->dataElement( 'h1', $novel->title() );
  $xhtml->end();

  $navPointParams{label}      = $novel->title(),
  $navPointParams{id}         = $epub->add_xhtml( $filename, $xhtml ),
  $navPointParams{content}    = $filename,
  $navPointParams{play_order} = $order++,

  my $root = $epub->add_navpoint( %navPointParams );

  while( my ($i, $book) = each @{$novel->books()} )
  {
    $filename = "book" . ( $i + 1 ) . ".xhtml";
    $xhtml    = XHTML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2 );
    $xhtml->dataElement( 'h2', $book->name() );
    $xhtml->end();

    $navPointParams{label}      = $book->name(),
    $navPointParams{id}         = $epub->add_xhtml( $filename, $xhtml ),
    $navPointParams{content}    = $filename,
    $navPointParams{play_order} = $order++,

    my $bookNavPoint = $root->add_navpoint( %navPointParams );

    while( my ($j, $chapter) = each @{$book->chapters()} )
    {
      my @contents = $self->downloader()->parseContent( $chapter->url() );

      $filename = "chapter" . ( $i + 1 ) . "_" . ( $j + 1 ) . ".xhtml";
      $xhtml    = XHTML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2, UNSAFE => 1 );
      $xhtml->dataElement( 'h3', $chapter->name() );
      $xhtml->startTag( 'p' );
      $xhtml->emptyTag( 'br'  );

      for my $text ( @contents )
      {
         $xhtml->raw( '&nbsp;' x 4 . "$text" );
         $xhtml->emptyTag( 'br' );
         $xhtml->emptyTag( 'br' );
      }
      $xhtml->endTag( 'p' );
      $xhtml->end   ();

      $navPointParams{label}      = $chapter->name(),
      $navPointParams{id}         = $epub->add_xhtml( $filename, $xhtml ),
      $navPointParams{content}    = $filename,
      $navPointParams{play_order} = $order++,

      $bookNavPoint->add_navpoint( %navPointParams );
    }
  }
  $epub->pack_zip( $self->outputFileName() );
}
# end public member functions

no Moose;
1;
