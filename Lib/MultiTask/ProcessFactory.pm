#!/usr/bin/perl
package MultiTask::ProcessFactory;

use Moose;

# packages
use IO::Pipe;
use Data::Dumper;

use MultiTask::ProcessPool;
# end packages

# public member functions
sub generate;
# end public member functions

# attributes
has processPool =>
(
  is      => 'ro',
  isa     => 'MultiTask::ProcessPool',
  default => sub { return MultiTask::ProcessPool->new(); },
);

has maxProcessNum =>
(
  is  => 'rw',
  isa => 'Int',
);

has returnToParent =>
(
  is      =>  'rw',
  isa     =>  'CodeRef',
  default =>  sub
              {
                return sub
                {
                  my ( $pid, $c2p, $p2c ) = @_;

                  return {
                            pid => $pid,
                            c2p => $c2p,
                            p2c => $p2c,
                         };
                }
              },
);

has ipcToParent =>
(
  is      => 'rw',
  isa     => 'Bool',
  default => 0,
);

has ipcFromParent =>
(
  is      => 'rw',
  isa     => 'Bool',
  default => 0,
);
# end attributes

# public member functions
sub generate
{
  my ( $self, %args ) = @_;

  my $c2p;
  my $p2c;
  my $pid;

  $c2p = IO::Pipe->new() if $self->ipcToParent  ();
  $p2c = IO::Pipe->new() if $self->ipcFromParent();
  $pid = $self->processPool()->fork();

  return $args{fail}->( @{ $args{args} } ) unless defined $pid; # fail to create process

  if( $pid == 0 ) # child process
  {
    $c2p->writer() if defined $c2p;
    $p2c->reader() if defined $p2c;

    $args{run}->( $c2p, $p2c, @{ $args{args} } );

    exit;
  }

  # main process
  $c2p->reader() if defined $c2p;
  $p2c->writer() if defined $p2c;

  return $self->returnToParent()->( $pid, $c2p, $p2c );
}
# end public member functions

# private member functions
after 'maxProcessNum' => sub
{
  my $self = shift;

  $self->processPool( $self->maxProcessNum() );
};
# end private member functions

no Moose;

1;
