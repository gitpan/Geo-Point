# Copyrights 2005-2008 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.03.

use strict;
use warnings;

package Geo::Surface;
use vars '$VERSION';
$VERSION = '0.07';
use base 'Geo::Shape';

use Math::Polygon::Surface ();
use Math::Polygon::Calc    qw/polygon_bbox/;
use List::Util             qw/sum/;

use Carp;


sub new(@)
{   my $thing = shift;
    my @components;
    push @components, shift while ref $_[0];
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

    return () unless @components;

    my @surfaces;
    foreach my $component (@components)
    {
        if(ref $component eq 'ARRAY')
        {   $component = $class->new(@$component);
        }
        elsif(ref $component eq 'Math::Polygon')
        {   $component = Geo::Line->filled($component->points);
        }
        elsif(ref $component eq 'Math::Polygon::Surface')
        {   bless $component, $class;
        }

        if($component->isa('Geo::Point'))
        {   push @surfaces, $component;
        }   
        elsif($component->isa('Geo::Line'))
        {   carp "Warning: Geo::Line is should be filled."
                unless $component->isFilled;
            push @surfaces, defined $proj ? $component->in($proj) : $component;
        }
        elsif($component->isa('Geo::Surface'))
        {   if(defined $proj)
            {   push @surfaces,
                    map {$component->in($proj)} $component->components;
            }
            else
            {   push @surfaces, $component->components;
            }
        }
        else
        {   confess "ERROR: Do not known what to do with $component";
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

      "surface[$proj]\n  ("
    . join(")\n  (", map {$_->toString} $surface->components)
    . ")\n";
}
*string = \&toString;

1;
