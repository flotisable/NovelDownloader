#!/usr/bin/perl
package NovelDownloader::Downloader::ComicBusDownloader;

use Moose;

with 'NovelDownloader::Downloader';

# pragmas
use utf8;
# end pragmas

# packages
use Class::Struct;

use Encode qw/decode/;
# end packages

# structure declarations
struct( Comic =>  {
                    title   => '$',
                    author  => '$',
                    cover   => '$',
                    books   => '@',
                  } );
struct( Book  =>  {
                    chapters  => '@',
                  } );
# end structure declarations

# public member functions
sub parseIndexCore;
sub parseContentCore;
# end public member functions

# private member functions
sub processfetchedContent;
sub getView;
sub decodeCodeString;
sub getPageNum;
sub getImageUrl;
# end private member functions

# public member functions
sub parseIndexCore
{
  my ( $self, $fh ) = @_;

  my %pattern = (
                  title     => qr/<img src="..\/images\/bon_1.gif" width="4" height="11" hspace="6" \/><font color="#FFFFFF" style="font-size:10pt; letter-spacing:1px">(.+)<\/font>/,
                  cover     => qr/<img src='\/(pics\/0\/\d+.jpg)' hspace="10" vspace="10" border="0" style="border:#CCCCCC solid 1px;width:240px;" \/>/,
                  authorPre => qr/作者：/,
                  author    => qr/<td nowrap="nowrap">(.+)<\/td>/,
                  chapter   => qr/<a href='#' onclick="cview\('(\d+-(\d+)\.html)',(\d+),(\d+)\);return false;" id="c\d+" class="Ch">/,
                  book      => qr/<a href='#' onclick="cview\('(\d+-(\d+)\.html)',(\d+),(\d+)\);return false;" id="c\d+" class="Vol">/,
                );

  my %bookReg;
  my %chapterReg;
  my $comic       = Comic->new( books => [ Book->new() ] );

  while( <$fh> )
  {
    $comic->title( $1 ) if /$pattern{title}/; # get title

    if( my ( $path ) = /$pattern{cover}/ ) # get cover image
    {
      my $url = ( $self->url() =~ s/html\/\d+\.html/$path/r );

      $comic->cover( $url );
    }
    if( /$pattern{authorPre}/ ) # get author
    {
      my $line;

      1 until not defined( $line = <$fh> ) or $line =~ /$pattern{author}/;

      $comic->author( $1 );
    }
    if( my ( $path, $index, $catid, $copyright ) = /$pattern{chapter}/ ) # get chapters
    {
      my $chapters  = $comic->books( -1 )->chapters();
      my ( $id )    = ( $self->url() =~ /(\d+)\.html/ );

      next if exists $chapterReg{$index};

      my $url = "https://comicbus.live/online/${ \( $self->getView( $catid, $copyright ) ) }$id.html?ch=$index";

      push @$chapters, $url;
      $chapterReg{$index} = 1;
    }
    if( my ( $path, $index, $catid, $copyright ) = /$pattern{book}/ ) # get books
    {
      my $book      = Book->new();
      my $chapters  = $book->chapters();

      my ( $id )    = ( $self->url() =~ /(\d+)\.html/ );

      next if exists $bookReg{$index};

      my $url = "https://comicbus.live/online/${ \( $self->getView( $catid, $copyright ) ) }$id.html?ch=$index";

      push @$chapters, $url;
      push @{ $comic->books() }, $book;

      $bookReg{$index}            = 1;
      @{ $comic->books() }[-1,-2] = @{ $comic->books() }[-2,-1];
    }
  }
  return $comic;
}

sub parseContentCore
{
  my ( $self, $fh ) = @_;

  my %pattern = (
                  coreScript        => qr/<script src="\/(js\/nview\.js\?\d+)"/,
                  magicNum          => qr/var y=(\d+);/,
                  codeString        => qr/var cs='(\w+)'/,
                  chapter           => qr/(\d+)\.html\?ch=(\d+)(?:-(\d+))?/,
                  magicVar          => qr/var (\w+)\s*=\s*lc\(su\(cs,i\*y/,
                  magicVarOffset    => qr/var \w+\s*=\s*lc\(su\(cs,i\*y\+(\d+)/,
                  magicVarLength    => qr/var \w+\s*=\s*lc\(su\(cs,i\*y\+\d+,(\d+)/,
                  pageNumMagicVar   => qr/ps=(\w+)/,
                  imageUrlMagicVars => qr/'\/\/img'\+su\((\w+), 0, 1\)\+'\.8comic\.com\/'\+su\((\w+),1,1\)\+'\/'\+ti\+'\/'\+(\w+)\+'\/'\+ nn\(p\)\+'_'\+su\((\w+),mm\(p\),3\)\+'\.jpg';/,
                );

  my $magicNum;
  my ( $comicIndex, $chapter, $pageIndex ) = ( $self->url() =~ /$pattern{chapter}/ );
  my %magicVars;
  my @magicVars;
  my @magicVarOffsets;
  my @magicVarLengths;
  my $pageNumMagicVar;
  my @imageUrlMagicVars;
  my @imageUrls;

  $pageIndex //= 1;

  while( <$fh> )
  {
    if( my ( $path ) = /$pattern{coreScript}/ )
    {
      my    $url  = ( $self->url() =~ s/online\/.+$/$path/r );
      my    $fh   = $self->fetchUrlToTempFile( $url );
      local $_;

      1 until not defined( $_ = <$fh> ) or /$pattern{magicNum}/;

      $magicNum = $1;
    }
    if( my ( $codeString ) = /$pattern{codeString}/ )
    {
      @magicVars            = /$pattern{magicVar}/g;
      @magicVarOffsets      = /$pattern{magicVarOffset}/g;
      @magicVarLengths      = /$pattern{magicVarLength}/g;
      ( $pageNumMagicVar )  = /$pattern{pageNumMagicVar}/;
      @imageUrlMagicVars    = /$pattern{imageUrlMagicVars}/;

      while( my ( $i, $magicVar ) = each @magicVars )
      {
        $magicVars{$magicVar} = $self->decodeCodeString(
                                  $codeString,
                                  ( $chapter - 1 ) * $magicNum + $magicVarOffsets[$i],
                                  $magicVarLengths[$i] );
      }
      last;
    }
  }

  my $pageNum = $self->getPageNum(  $pageNumMagicVar, %magicVars );

  push @imageUrls, $self->getImageUrl( $comicIndex, $pageIndex, \@imageUrlMagicVars, %magicVars );

  for( $pageIndex = 2 ; $pageIndex <= $pageNum ; ++$pageIndex )
  {
     my $url  = $self->url() . "-$pageIndex";
     my $fh   = $self->fetchUrlToTempFile( $url );

     while( <$fh> )
     {
       if( my ( $path ) = /$pattern{coreScript}/ )
       {
         my    $url = ( $self->url() =~ s/online\/.+$/$path/r );
         my    $fh  = $self->fetchUrlToTempFile( $url );
         local $_;

         1 until not defined( $_ = <$fh> ) or /$pattern{magicNum}/;

         $magicNum = $1;
       }
       if( my ( $codeString ) = /$pattern{codeString}/ )
       {
         @magicVars         = /$pattern{magicVar}/g;
         @magicVarOffsets   = /$pattern{magicVarOffset}/g;
         @magicVarLengths   = /$pattern{magicVarLength}/g;
         @imageUrlMagicVars = /$pattern{imageUrlMagicVars}/;

         while( my ( $i, $magicVar ) = each @magicVars )
         {
           $magicVars{$magicVar} = $self->decodeCodeString(
                                     $codeString,
                                     ( $chapter - 1 ) * $magicNum + $magicVarOffsets[$i],
                                     $magicVarLengths[$i] );
         }
         last;
       }
     }
     push @imageUrls, $self->getImageUrl( $comicIndex, $pageIndex, \@imageUrlMagicVars, %magicVars );
  }
  return @imageUrls;
}
# end public member functions

# private member functions
sub processfetchedContent
{
  my ( $self, $content ) = @_;

  return decode( 'big5', $content );
}

sub getView
{
  my ( undef, $catid, $copyright ) = @_;

  return "comic-";
  return ( $copyright == 1 && 1 <= $catid && $catid <= 22 ) ? "comic-" : "manga_";
}

sub decodeCodeString
{
  my ( undef, $codeString, $offset, $length ) = @_;

  my $map   = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ';
  my $code  = substr $codeString, $offset, $length;

  return $code if $length != 2;

  my ( $front, $back ) = split //, $code;

  return 8000 + index $map, $back if $front eq 'Z';
  return ( index $map, $front ) * 52 + index $map, $back;
}

sub getPageNum
{
  my ( undef, $pageNumMagicVar, %magicVars ) = @_;

  return $magicVars{$pageNumMagicVar};
}

sub getImageUrl
{
  my ( $self, $comicIndex, $pageIndex, $imageUrlMagicVarsRef, %magicVars ) = @_;

  my $url = 'https://img'
          . ( substr $magicVars{$$imageUrlMagicVarsRef[0]}, 0, 1 )
          . '.8comic.com/'
          . ( substr $magicVars{$$imageUrlMagicVarsRef[1]}, 1, 1 )
          . "/$comicIndex/"
          . $magicVars{$$imageUrlMagicVarsRef[2]} . '/'
          . ( '0' x ( 2 - int ( log ( $pageIndex ) / log 10 ) ) ) . $pageIndex
          . '_'
          . ( substr  $magicVars{$$imageUrlMagicVarsRef[3]},
                      int ( ( $pageIndex - 1 ) / 10 % 10  ) + ( $pageIndex - 1 ) % 10 * 3,
                      3 )
          . '.jpg';

  return $url;
}
# end private member functions

no Moose;
1;
