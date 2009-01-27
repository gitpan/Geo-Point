# Copyrights 2005-2009 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.06.

use strict;
use warnings;

package Geo::Surface;
use vars '$VERSION';
$VERSION = '0.90';

use base 'Geo::Shape';

use Math::Polygon::Surface ();
use Math::Polygon::Calc    qw/polygon_bbox/;
use List::Util             qw/sum first/;

use Carp;


sub new(@)
{   my $thing = shift;
    my @components;
    push @components, shift while ref $_[0];
    @components or return ();

    my %args  = @_;

    my $class;
    if(ref $thing)    # instance method
    {   $args{proj} ||= $thing->proj;
        $class = ref $thing;
    }
    else
    {   $class = $thing;
    }

    my $proj = $args{proj};
    unless($proj)
    {   my $s = first { UNIVERSAL::isa($_, 'Geo::Shape') } @components;
        $args{proj} = $proj = $s->proj if $s;
    }

    my @surfaces;
    foreach my $c (@components)
    {
        if(ref $c eq 'ARRAY')
        {   my $outer = Math::Polygon->new(points => $c);
            push @surfaces, Math::Polygon::Surface->new(outer => $outer);
        }
        elsif(UNIVERSAL::isa($c, 'Math::Polygon'))
        {   push @surfaces, Math::Polygon::Surface->new(outer => $c);
        }
        elsif(UNIVERSAL::isa($c, 'Math::Polygon::Surface'))
        {   push @surfaces, $c;
        }
        elsif(UNIVERSAL::isa($c, 'Geo::Line'))
        {   my $outer = $c->in($proj)->points;
            push @surfaces, Math::Polygon::Surface->new(outer => $outer);
        }
        elsif($c->isa('Geo::Surface'))
        {   push @surfaces, map {$c->in($proj)} $c->components;
        }
        else
        {   confess "ERROR: Do not known what to do with $c";
        }
    }

    $args{components} = \@surfaces;
    $thing->SUPER::new(%args);
}

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{GS_comp} = $args->{components};
    $self;
}


sub components() { @{shift->{GS_comp}} }


sub component(@)
{   my $self = shift;
    wantarray ? $self->{GS_comp}[shift] : @{$self->{GS_comp}}[@_];
}


sub nrComponents() { scalar @{shift->{GS_comp}} }


sub in($)
{   my ($self, $projnew) = @_;
    return $self if ! defined $projnew || $projnew eq $self->proj;

    my @surfaces;
    foreach my $old ($self->components)
    {   my @newrings;
        foreach my $ring ($old->outer, $old->inner)
        {   ($projnew, my @points) = $self->projectOn($projnew, $ring->points);
            push @newrings, @points
             ? (ref $ring)->new(proj => $projnew, points => \@points) : $ring;
        }
        push @surfaces, (ref $old)->new(@newrings, proj => $projnew);
    }
  
    $self->new(@surfaces, proj => $projnew);
}


sub equal($;$)
{   my ($self, $other, $tolerance) = @_;

    my $nr   = $self->nrComponents;
    return 0 if $nr != $other->nrComponents;

    my $proj = $other->proj;
    for(my $compnr = 0; $compnr < $nr; $compnr++)
    {   my $own = $self->component($compnr);
        my @own = $self->projectOn($proj, $own->points);

        $other->component($compnr)->equal(\@own, $tolerance)
            or return 0;
    }

    1;
}


sub bbox() {  polygon_bbox map { $_->outer->points } shift->components }


sub area() { sum map { $_->area } shift->components }


sub perimeter() { sum map { $_->perimeter } shift->components }


sub toString(;$)
{   my ($self, $proj) = @_;
    my $surface;
    if(defined $proj)
    {   $surface = $self->in($proj);
    }
    else
    {   $proj    = $self->proj;
        $surface = $self;
    }

    my @polys;
    foreach my $c ($surface->components)
    {   push @polys, 'aap';
    }

    local $" = ")\n  (";
    "surface[$proj]\n  (@polys)\n";
}
*string = \&toString;

1;
