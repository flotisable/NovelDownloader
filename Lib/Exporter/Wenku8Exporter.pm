#!/usr/bin/perl
package Exporter::Wenku8Exporter;

use Moose;

# pragmas
binmode STDOUT, ":encoding(utf8)";
# end pragmas

# packages
use EBook::EPUB;

use XHTML::Writer;
# end packages

# global variables
my %formats = (
                org   =>  {
                            name            =>  'org',
                            exportFunction  =>  \&Exporter::Wenku8Exporter::exportOrg,
                          },
                epub  =>  {
                            name            =>  'epub',
                            exportFunction  =>  \&Exporter::Wenku8Exporter::exportEpub,
                          },
              );
# end global variables

# public member functions
sub export;
sub exportOrg;
sub exportEpub;
# end public member functions

# attributes
has 'downloader' =>
(
  is  => 'rw',
  isa => 'Downloader::Wenku8Downloader',
);

has 'outputFileName' =>
(
  is  => 'rw',
  isa => 'Str',
);

# end attributes

# public member functions
sub export
{
  my ( $self, $url, $formatName ) = @_;

  defined $self->downloader() or die "No downloader being set!\n";

  my $novel = $self->downloader()->parseIndex( $url );

  for my $format ( values %formats )
  {
    if( $formatName eq $format->{name} )
    {
      $self->${ \$format->{exportFunction} }( $novel );
      last;
    }
  }
}

sub exportOrg
{
  my ( $self, $novel ) = @_;

  my $fh;

  if( defined $self->outputFileName() )
  {
    open $fh, ">", $self->outputFileName();

    binmode $fh, ":encoding(utf8)";
    select $fh;
  }

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
  close $fh;
}

sub exportEpub
{
  my ( $self, $novel ) = @_;

  defined $self->outputFileName() or die "Forget to specify output file name!";

  my $xhtml     = XHTML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2 );
  my $epub      = EBook::EPUB->new();
  my $filename  = "index.xhtml";
  my $order     = 1;

  # setup meta data
  $epub->add_title    ( $novel->title ()  );
  $epub->add_author   ( $novel->author()  );
  $epub->add_language ( 'zh_TW'           );
  # end setup meta data

  $xhtml->dataElement( 'h1', $novel->title() );
  $xhtml->end();

  my $root  = $epub->add_navpoint(
                                    label       => $novel->title(),
                                    id          => $epub->add_xhtml( $filename, $xhtml ),
                                    content     => $filename,
                                    play_order  => $order++,
              );

  while( my ($i, $book) = each @{$novel->books()} )
  {
    $filename = "book" . ( $i + 1 ) . ".xhtml";
    $xhtml    = XHTML::Writer->new( OUTPUT => 'self', DATA_MODE => 1, DATA_INDENT => 2 );
    $xhtml->dataElement( 'h2', $book->name() );
    $xhtml->end();

    my $bookNavPoint  = $root->add_navpoint(
                                              label       => $book->name(),
                                              id          => $epub->add_xhtml( $filename, $xhtml ),
                                              content     => $filename,
                                              play_order  => $order++,
                        );

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

      $bookNavPoint->add_navpoint (
                                    label       => $chapter->name(),
                                    id          => $epub->add_xhtml( $filename, $xhtml ),
                                    content     => $filename,
                                    play_order  => $order++,
                                  );
    }
  }
  $epub->pack_zip( $self->outputFileName() );
}
# end public member functions

no Moose;
1;
