#!/usr/bin/perl
# pragmas
use strict;
use warnings;
# end pragmas

# packages
use Getopt::Long;
use Pod::Usage;

use NovelDownloader::ProcessorFactory;
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

  my $factory = NovelDownloader::ProcessorFactory->new();

  for my $indexUrl ( @indexUrls )
  {
     my ( $downloader, $exporter ) = $factory->generate( $indexUrl );
    
     $exporter->downloader    ( $downloader                   );
     $exporter->outputFileName( $outputFileName               );
     $exporter->export        ( $indexUrl,      $outputFormat );
  }
}

# end function definitions
