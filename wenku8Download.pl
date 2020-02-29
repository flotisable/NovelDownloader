#!/usr/bin/perl
# pragmas
use strict;
use warnings;
# end pragmas

# packages
use Getopt::Long;
use Pod::Usage;

use Downloader::Wenku8Downloader;
use Exporter::Wenku8Exporter;
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

  my $exporter  = Exporter::Wenku8Exporter->new(
                    downloader      => Downloader::Wenku8Downloader->new(),
                    outputFileName  => $outputFileName,
                  );

  $exporter->export( $_, $outputFormat ) for @indexUrls;
}

# end function definitions
