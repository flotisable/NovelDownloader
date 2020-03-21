#!/usr/bin/perl
# pragmas
use strict;
use warnings;
# end pragmas

# packages
use Getopt::Long qw/VersionMessage/;
use Pod::Usage;

use NovelDownloader::ProcessorFactory;
# end packages

# documents
=head1 NAME

novelDownloader.pl - download novel from website

=head1 SYNOPSIS

B<novelDownloader.pl> [options] <url>

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

=item B<-h>

print simplest help message.

=item B<--help>

print detailed help message.

=back

=head1 DESCRIPTION

This program is written to download the novel from the website,
currently only support the www.wenku8.net.

=head1 EXAMPLES

  novelDownloader.pl -o output.epub -f epub 'https://www.wenku8.net/modules/article/reader.php?aid=112'

This will download the novel whose index is at 'https://www.wenku8.net/modules/article/reader.php?aid=112',
and the output file will be named B<output.epub> with format B<epub>.

=head1 FILES

=over

=item F<processors.txt>

The configuration file of perl modules to be used to download and export the novel.
Each line contains 3 fields delimited by ',', ex.

  <pattern>,<downloader>,<exporter>

The meaning of each field is described below:

=over

=item B<pattern>

The regular expression used to match the website url,
if the url is matched,
the corresponding B<downloader> and B<exporter> will be used to download and export the novel.

=item B<downloader>

The perl module used to download the novel.
It should satisfy the interface defined by B<NovelDownloader::Downloader> role.

=item B<exporter>

The perl module used to export the novel.
It should satisfy the interface defined by B<NovelDownloader::Exporter> role.

=back

=back

=head1 AUTHOR

Flotisable <s09930698@gmail.com>

=cut
# end documents

# global variables
our $VERSION = '0.01';
# end global variables

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
              'h'           => sub { pod2usage();       },
              'help'        => sub { pod2usage(1);      },
              'version|v'   => sub { VersionMessage();  },
  ) or die "Invalid Option!\n";

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
