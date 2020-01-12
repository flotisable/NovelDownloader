#!/usr/bin/perl
use strict;
use warnings;

# packages
use HTTP::Tiny;
use Encode      qw/from_to/;
use File::Temp  qw/tempfile/;
# end packages

# function declarations
sub parseIndex;
# end function declarations

# command line arguments
my @indexUrls = @ARGV;
# end command line arguments

# main procedure
my $http = HTTP::Tiny->new();

for my $indexUrl (@indexUrls)
{
  my $response = $http->get( $indexUrl );

  die "$indexUrl Fail!\n" unless $response->{success};

  from_to( $response->{content}, 'cp936', 'utf8' );

  my $fileT = File::Temp->new();

  print $fileT $response->{content};

  parseIndex( $fileT->filename() );
}
# end main procedure

# function definitions
sub parseIndex
{
  my $titlePattern    = qr/<div id="title">(.+)<\/div>/;
  my $authorPattern   = qr/<div id="info">作者：(.+)<\/div>/;
  my $bookPattern     = qr/<td class="vcss" colspan="4">(.+)<\/td>/;
  my $chapterPattern  = qr/<td class="ccss"><a href="(.+)">(.+)<\/a><\/td>/;

  my $filename = shift;

  open my $fh, '<', $filename;

  while( <$fh> )
  {
    if( my ($title) = /$titlePattern/ )
    {
      print "標題: $title\n";
      last;
    }
  }
  while( <$fh> )
  {
    if( my ($author) = /$authorPattern/ )
    {
      print "作者: $author\n";
      last;
    }
  }
  while( <$fh> )
  {
    if( my ($book) = /$bookPattern/ )
    {
      print "$book\n";
      next;
    }
    if( my ($url, $chapter) = /$chapterPattern/ )
    {
      print "$chapter: $url\n";
      next;
    }
  }
  close $fh;
}
# end function definitions
