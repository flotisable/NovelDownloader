#!/usr/bin/perl
package XHTML::Writer;

# pragmas
use strict;
use warnings;
# end pragmas

# packages
use XML::Writer;
use parent 'XML::Writer';
# end packages

# public memeber functions
sub new;
sub end;
# end public memeber functions

# public memeber functions
sub new()
{
  my ( $class, %params ) = @_;

  $params{TITLE} //= "";

  my $object = bless XML::Writer->new( %params ), $class;

  $object->doctype ( 'html', '-//W3C//DTD XHTML 1.1//EN', 'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd' );
  $object->startTag( 'html', xmlns => 'http://www.w3.org/1999/xhtml' );
    $object->startTag( 'head' );
      $object->startTag( 'title' );
        $object->characters( $params{TITLE} );
      $object->endTag  ( 'title' );
    $object->endTag  ( 'head' );
    $object->startTag( 'body' );

  return $object;
}

sub end()
{
  my $self = shift;

    $self->endTag  ( 'body' );
  $self->endTag  ( 'html' );

  $self->SUPER::end();
}
# end public memeber functions

1;
