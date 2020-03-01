#!/usr/bin/perl
package XHTML::Writer;

use Moose;
use MooseX::NonMoose;

extends 'XML::Writer';

# public memeber functions
sub BUILD;
override 'end', sub
{
  my $self = shift;

    $self->endTag  ( 'body' );
  $self->endTag  ( 'html' );

  super();
};
# end public memeber functions

# public memeber functions
sub BUILD
{
  my ( $self, $params ) = @_;

  $params->{TITLE} //= "";

  $self->doctype ( 'html', '-//W3C//DTD XHTML 1.1//EN', 'http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd' );
  $self->startTag( 'html', xmlns => 'http://www.w3.org/1999/xhtml' );
    $self->startTag( 'head' );
      $self->startTag( 'title' );
        $self->characters( $params->{TITLE} );
      $self->endTag  ( 'title' );
    $self->endTag  ( 'head' );
    $self->startTag( 'body' );
}
# end public memeber functions

no Moose;
1;
