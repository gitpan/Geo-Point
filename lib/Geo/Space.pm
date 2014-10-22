# Copyrights 2005-2007 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.00.

use strict;
use warnings;

package Geo::Space;
use vars '$VERSION';
$VERSION = '0.06';
use base 'Geo::Shape';

use Math::Polygon::Calc    qw/polygon_bbox/;
use List::Util             qw/sum first/;


sub new(@)
{   my $thing = shift;
    my @components;
    push @components, shift while ref $_[0];
    my %args  = @_;

    if(ref $thing)    # instance method
    {   $args{proj} ||= $thing->proj;
    }

    my $proj = $args{proj};
    return () unless @components;

    $thing->SUPER::new(components => \@components);
}

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);

    $self->{GS_comp} = $args->{components} || [];
    $self;
}


sub components() { @{shift->{GS_comp}} }


sub component(@)
{   my $self = shift;
    wantarray ? $self->{GS_comp}[shift] : @{$self->{GS_comp}}[@_];
}


sub nrComponents() { scalar @{shift->{GS_comp}} }


sub points()     { grep {$_->isa('Geo::Points')} shift->components }


sub onlyPoints() { not first {! $_->isa('Geo::Points')} shift->components }


sub lines()      { grep {$_->isa('Geo::Line')} shift->components }


sub onlyLines()  { not first {! $_->isa('Geo::Line')} shift->components }


sub onlyRings()  { not first {! $_->isa('Geo::Line') || ! $_->isRing}
                         shift->components }


sub in($)
{   my ($self, $projnew) = @_;
    return $self if ! defined $projnew || $projnew eq $self->proj;

    my @t;

    foreach my $component ($self->components)
    {   ($projnew, my $t) = $component->in($projnew);
        push @t, $t;
    }

    (ref $self)->new(@t, proj => $projnew);
}


sub equal($;$)
{   my ($self, $other, $tolerance) = @_;

    my $nr   = $self->nrComponents;
    return 0 if $nr != $other->nrComponents;

    my $proj = $other->proj;
    for(my $compnr = 0; $compnr < $nr; $compnr++)
    {   my $own = $self->component($compnr);
        my $his = $other->component($compnr);

        $own->equal($his, $tolerance)
            or return 0;
    }

    1;
}

sub bbox()
{   my $self = shift;
    my @bboxes = map { [$_->bbox] } $self->components;
    polygon_bbox(map { ([$_->[0], $_->[1]], [$_->[2], $_->[3]]) } @bboxes);
}


sub area() { sum map { $_->area } shift->components }


sub perimeter() { sum map { $_->perimeter } shift->components }


sub string(;$)
{   my ($self, $proj) = @_;
    my $space;
    if(defined $proj)
    {   $space = $self->in($proj);
    }
    else
    {   $proj  = $self->proj;
        $space = $self;
    }

      "space[$proj]\n  ("
    . join(")\n  (", map {$_->string} $space->components)
    . ")\n";
}

1;
