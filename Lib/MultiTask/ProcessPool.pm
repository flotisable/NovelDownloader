#!/usr/bin/perl
package MultiTask::ProcessPool;

use Moose;

# pacakges
use POSIX qw/WNOHANG/;
# end pacakges

# public member functions
sub fork;
# end public member functions

# attributes
has maxProcessNum =>
(
  is      => 'rw',
  isa     => 'Int',
  default => 4,
);

has pids =>
(
  is      => 'rw',
  isa     => 'HashRef[Int]',
  default => sub { return {}; },
);
# end attributes

# public member functions
sub fork
{
  my $self = shift;

  my @pids = keys %{ $self->pids() };

  # cleanup terminated child processes
  for my $pid ( @pids )
  {
     delete $self->pids()->{$pid} if waitpid( $pid, WNOHANG ) == -1;
  }
  # end cleanup terminated child processes

  return undef if scalar keys %{ $self->pids() } >= $self->maxProcessNum(); # fail to fork

  my $pid = CORE::fork;

  $self->pids()->{$pid} = 1;

  return $pid;
}
# end public member functions

no Moose;

1;
