#!/usr/bin/perl
# pragmas
use strict;
use warnings;

use constant
{
  TEST_URL        => 'https://www.wenku8.net/modules/article/reader.php?aid=112',
  TEST_ORG_FILE   => 'test.org',
  TEST_EPUB_FILE  => 'test.epub',
};
# end pragmas

# packages
use File::Temp;
use File::Compare         qw/compare_text/;
use IO::Uncompress::Unzip qw/unzip $UnzipError/;
# end packages

# function declirations
sub main;
sub testOrgExport;
sub testEpubExport;
sub compareExportFile;
# end function declirations

main();

# function definitions
sub main()
{
  my ( $testProgram, $testcaseDir ) = @ARGV; # command line arguments

  my $orgTestFile   = "$testcaseDir/" . TEST_ORG_FILE;
  my $epubTestFile  = "$testcaseDir/" . TEST_EPUB_FILE;

  testOrgExport(  $testProgram, $orgTestFile  );
  testEpubExport( $testProgram, $epubTestFile );
}

sub testOrgExport()
{
  my ( $testProgram, $orgTestFile ) = @_;

  my $file = File::Temp->new();

  # test org format
  system "$testProgram -o " . $file->filename() . " " . TEST_URL;

  compareExportFile( $orgTestFile, $file->filename(), 'Org' );
}

sub testEpubExport()
{
  my ( $testProgram, $epubTestFile ) = @_;

  my $file      = File::Temp->new();
  my $refBuffer = File::Temp->new();
  my $tmpBuffer = File::Temp->new();

  system "$testProgram -f epub -o " . $file->filename() . " " . TEST_URL;

  unzip( $file->filename()  => $tmpBuffer->filename() ) or die "Unzip Fail: $UnzipError\n";
  unzip( $epubTestFile      => $refBuffer->filename() ) or die "Unzip Fail: $UnzipError\n";

  compareExportFile( $refBuffer->filename(), $tmpBuffer->filename(), 'Epub' );
}

sub compareExportFile()
{
  my ( $refFile, $testFile, $format ) = @_;

  if( compare_text( $refFile, $testFile ) )
  {
    die times . "s: $format Format Test Fail!\n";
  }
  print times . "s: $format Format Test Pass!\n";
}
# end function definitions
