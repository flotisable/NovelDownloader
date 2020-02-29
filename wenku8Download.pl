#!/usr/bin/perl
# pragmas
use strict;
use warnings;

binmode STDOUT, ":encoding(utf8)";
# end pragmas

# packages
use Getopt::Long;
use Pod::Usage;

use EBook::EPUB;

use Downloader::Wenku8Downloader;
use XHTML::Writer;
# end packages

# documents
=head1 NAME

B<wenku8Download.pl> - download novel from www.wenku8.net

=head1 SYNOPSIS

B<wenku8Download.pl> [options] <url>

=head1 OPTIONS

=over

=item B<-o>, B<--output> I<<output file name>>

set the output file name of dowloaded novel.
Must be specified when output B<epub> format.

=item B<-f>, B<--format> I<<format name>>

set the output format of downloaded novel.
The supported format are shown below:

=over

=item B<org>

=item B<epub>

=back

=back

=item B<-h>, B<--help>

print help message.

=cut
# end documents

# function declarations
sub main;
sub outputOrgFormat;
sub outputEpubFormat;
# end function declarations

main();

# function definitions
sub main
{
  my $outputFileName;
  my $outputFormat    = "org";

  GetOptions(
              'output|o=s'  => \$outputFileName,
              'format|f=s'  => \$outputFormat,
              'h'           => sub { pod2usage();   },
              'help'        => sub { pod2usage(1);  },
  ) or die "Invalid Option!";

  # command line arguments
  my @indexUrls = @ARGV;
  # end command line arguments

  my $downloader = Downloader::Wenku8Downloader->new();

  for my $indexUrl ( @indexUrls )
  {
    my $novel = $downloader->parseIndex( $indexUrl );

    if( $outputFormat eq "org" )
    {
      outputOrgFormat( $downloader, $novel, $outputFileName );
      next;
    }

    if( $outputFormat eq "epub" )
    {
      die "Forget to specify output file name!" unless defined $outputFileName;

      outputEpubFormat( $downloader, $novel, $outputFileName );
    }
  }
}

sub outputOrgFormat
{
  my ( $downloader, $novel, $outputFileName ) = @_;

  my $fh;

  if( defined $outputFileName )
  {
    open $fh, ">", $outputFileName;

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
       my @contents = $downloader->parseContent( $chapter->url() );

       print "** ", $chapter->name(), "\n";
       print "$_\n\n" for @contents;
    }
  }
  close $fh;
}

sub outputEpubFormat
{
  my ( $downloader, $novel, $outputFileName ) = @_;

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
      my @contents = $downloader->parseContent( $chapter->url() );

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
  $epub->pack_zip( $outputFileName );
}
# end function definitions
