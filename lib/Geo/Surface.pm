# Copyrights 2005-2009 by Mark Overmeer.
#  For other contributors see ChangeLog.
# See the manual pages for details on the licensing terms.
# Pod stripped from pm file by OODoc 1.06.

use strict;
use warnings;

package Geo::Surface;
use vars '$VERSION';
$VERSION = '0.92';

use base 'Geo::Shape';

use Math::Polygon::Surface ();
use Math::Polygon::Calc    qw/polygon_bbox/;
use List::Util             qw/sum first/;

use Carp;


sub new(@)
{   my $thing = shift;
    my @lines;
    push @lines, shift while ref $_[0];
    @lines or return ();

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
    {   my $s = first { UNIVERSAL::isa($_, 'Geo::Shape') } @lines;
        $args{proj} = $proj = $s->proj if $s;
    }

    my $mps;
    if(@lines==1 && UNIVERSAL::isa($_, 'Math::Polygon::Surface'))
    {   $mps = shift @lines;
    }
    else
    {   my @polys;
        foreach (@lines)
        {   push @polys
              , UNIVERSAL::isa($_, 'Geo::Line'    ) ? [$_->in($proj)->points]
              : UNIVERSAL::isa($_, 'Math::Polygon') ? $_
              : UNIVERSAL::isa($_, 'ARRAY'        ) ? Math::Polygon->new(@$_)
              : croak "ERROR: Do not known what to do with $_";
        }
        $mps = Math::Polygon::Surface->new(@polys);
    }

    $args{_mps} = $mps;
    $thing->SUPER::new(%args);
}

sub init($)
{   my ($self, $args) = @_;
    $self->SUPER::init($args);
    $self->{GS_mps} = $args->{_mps};
    $self;
}


sub outer() { shift->{GS_mps}->outer }
sub inner() { shift->{GS_mps}->inner }

sub geo_outer()
{   my $self = shift;
    Geo::Line->new(points => [$self->outer->points], proj => $self->proj);
}

sub geo_inner()
{   my $self = shift;
    my $proj = $self->proj;
    map { Geo::Line->new(points => [$_->points], proj => $proj) } $self->inner;
}


sub in($)
{   my ($self, $projnew) = @_;
    return $self if ! defined $projnew || $projnew eq $self->proj;

    my @newrings;
    foreach my $ring ($self->outer, $self->inner)
    {   (undef, my @points) = $self->projectOn($projnew, $ring->points);
        push @newrings, \@points;
    }
    my $mp = Math::Polygon::Surface->new(@newrings);
    (ref $self)->new($mp, proj => $projnew);
}


sub bbox() { polygon_bbox $_->outer->points }


sub area()
{   my $self = shift;
    my $area = $self->outer->area;
    $area   -= $_->area for $self->inner;
    $area;
}


sub perimeter() { shift->outer->perimeter }


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

    my $mps = $self->{GS_mps}->string;
    $mps    =~ s/\n-/)\n -(/;
    "surface[$proj]\n  ($mps)\n";
}
*string = \&toString;

1;
