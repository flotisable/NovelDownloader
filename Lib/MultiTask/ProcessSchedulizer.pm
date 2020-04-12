#!/usr/bin/perl
package MultiTask::ProcessSchedulizer;

use Moose;

# public member functions
sub schedule;
# end public member functions

# attributes
has processInfos =>
(
  is      => 'ro',
  isa     => 'ArrayRef[Defined]',
  default => sub { return []; },
);

has ipcToParent =>
(
  is      => 'ro',
  isa     => 'Bool',
  default => 0,
);

has ipcFromParent =>
(
  is      => 'ro',
  isa     => 'Bool',
  default => 0,
);
# end attributes

# public member functions
sub schedule
{
  my ( $self, $datas, %args ) = @_;

  while( my ( $i, $data ) = each @{ $datas } )
  {
    push @{ $self->processInfos() }, $args{generate}->( $i, $data, @{ $args{args} } )
  }

  while( my $processInfo = shift @{ $self->processInfos() } )
  {
    unless( exists $processInfo->{pid} ) # recreate process if it fails
    {
      push @{ $self->processInfos() }, $args{generate}->( $args{getFailArgs}->( $processInfo ), @{ $args{args} } );
      next;
    }

    next unless $self->ipcToParent();

    my $c2p = $processInfo->{c2p};

    waitpid $processInfo->{pid}, 0;

    $args{ipcToParent}->() while <$c2p>;
  }
}
# end public member functions

no Moose;

1;
