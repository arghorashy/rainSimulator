use strict;

package rainSim;

use Tk;
use PDL::NiceSlice;


my $size = 500;

our $speed = 1;
our $grid = new rainGrid(int($size/8), 1.5);
$grid->init;

our $MW = MainWindow->new(-title => 'RainSim');
$MW->geometry("+500+500");

our $RC = $MW->Canvas(      -width      => 800,
                            -height     => $size,
                            -background => 'white',
                            -borderwidth  => '3',
                            -relief       => 'sunken',
                            -confine => 1
)->pack(-side => "top", -fill => 'x');
drawGrid($RC, $grid);
$RC->update();

our $CF = $MW->Frame(      -width      => 800,
                           -height     => 50,
                           -borderwidth  => '3',
    
)->pack(-side => "top", -fill => 'x');

$CF->Button(      -text     => "Start Simulation",
                  -command  => sub {startSim($grid, $RC, $speed, 1);}
)->pack(-padx => 15, -side => "left");

$CF->Button(      -text     => "Start Fast Simulation",
                  -command  => sub {startSim($grid, $RC, $speed, 0);}
)->pack(-padx => 15, -side => "left");


$CF->Button(      -text     => "Start Batch Simulation (1000x)",
                  -command  => sub {startSimBatch($grid, $RC, $speed);}
)->pack(-padx => 15, -side => "left");

our $Speed_fr = $CF->Frame->pack(-padx => 30, -side => "left");
                     
$Speed_fr->Label(-text => "Speed ratio (person:rainfall): ")->pack(-padx => 5, -side => "left");

$Speed_fr->Entry(   -textvariable => \$speed,
                    -width => 20
)->pack(-padx => 5, -side => "left");

our $Drops_fr = $CF->Frame->pack(-padx => 30, -side => "left");

our $hRain_fr = $Drops_fr->Frame()->pack(-side => "top", -fill => 'x');
$hRain_fr->Label(-text => "Rain drops on front: ")->pack(-side => "left");
our $hRain_var;
$hRain_fr->Entry(-textvariable => \$hRain_var,-width => 5, -state => "readonly")->pack(-side => "right");

our $vRain_fr = $Drops_fr->Frame->pack(-side => "top", -fill => 'x');
$vRain_fr->Label(-text => "Rain drops on top: ")->pack(-side => "left");
our $vRain_var;
$vRain_fr->Entry(-textvariable => \$vRain_var,-width => 5, -state => "readonly")->pack(-side => "right");

our $tRain_fr = $Drops_fr->Frame->pack(-side => "top", -fill => 'x');
$tRain_fr->Label(-text => "Total rain drops: ")->pack(-side => "left");
our $tRain_var;
$tRain_fr->Entry(-textvariable => \$tRain_var,-width => 5, -state => "readonly" )->pack(-side => "right");



MainLoop;


sub startSimBatch
{
    my ($grid, $RC, $speed) = @_;
    
    my @speeds = (1,2,4,8,16,32);
    for $speed (@speeds)
    {
        
        open my $OUT, '>', "$speed.txt";
        for my $iter (0..200)
        {
            print "$speed-$iter\n";
            $hRain_var = 0;
            $vRain_var = 0;
            $tRain_var = 0;
            
            $grid->init;

            my ($hRain, $vRain, $tRain) = startSim($grid, $RC, $speed, 0);
            
            print $OUT "$hRain, $vRain, $tRain\n"; 
        }
        close $OUT;
    }
    
}


sub startSim
{
    my ($grid, $RC, $speed, $visuals) = @_;

    $hRain_var = 0;
    $vRain_var = 0;
    $tRain_var = 0;
    
    $grid->init;
    
    if ($visuals)
    {
        drawGrid($RC, $grid);
        $RC->update();
    }
    
    my $t = 0;
    while ($t < 80)
    {
        my $localspeed = ($speed < 1)
            ? (1)
            : int($speed);
            
        $localspeed = ($t + $localspeed>80)
            ? (80 - $t)
            : ($localspeed);
            
        $t += $localspeed;
        
        my $maxIter = ($speed < 1) ? int(1/$speed -1) : (0);
        for my $i (0 .. $maxIter)
        {
            my $vRain = int(($grid->simulateRain)*$localspeed/$speed);
            $vRain_var +=$vRain;
            $tRain_var +=$vRain;
            #if ($visuals)
            #{
            #    drawGrid($RC, $grid);
            #    $RC->update();
            #}
            
        }
        
        my $hRain = $grid->simulatePerson($localspeed);
        $hRain_var +=$hRain;
        $tRain_var +=$hRain;
        
        if ($visuals)
        {
            drawGrid($RC, $grid);
            $RC->update();
        }
        $RC->update();
        
        print "$t\n"
    }
    
    return ($hRain_var, $vRain_var, $tRain_var);
    
}




sub drawGrid
{
    use Storable;
    use PDL::Image2D;
    use Data::Dumper;
    
    my ($RC, $grid) = @_;
    
    # Delete existing things
    my @items = $RC->find('all');
    for my $item (@items)
    {
        $RC->delete($item);
    }
    

    # Add person
    my $point1 = $grid->{PERSON_CORN}->[0]; 
    my $point2 = $grid->{PERSON_CORN}->[1]; 
    my $point3 = $grid->{PERSON_CORN}->[2]; 
    $RC->createLine(7*$point1->[0], 7*$point1->[1], 7*$point2->[0], 7*$point2->[1],
            -fill => "black", -width => 10);
    $RC->createLine(7*$point2->[0], 7*$point2->[1], 7*$point3->[0], 7*$point3->[1],
            -fill => "black", -width => 10);
    
    # Add rain
    for my $x (0 .. ($grid->{SIZE}-1))
    {
        for my $y (0 .. ($grid->{SIZE}-1))
        {
            if ($grid->{RAIN}->($x, $y) eq 1)
            {
                $RC->createOval($x*7, $y*7, $x*7, $y*7, -outline => 'blue');
            }
        }
    }
}






#############################################

package rainGrid;

use PDL;
use PDL::NiceSlice;
use Math::Random::MT::Perl;



# Setup of grid dimensions
#  (0,0)
#   +----------+
#   |          |
#   |          |
#   |          |
#   |          |
#   |          |
#   +----------+
#  


#our $person =pdl( [1,0,0,0,0,0,0,0,0,0],
#                  [1,0,0,0,0,0,0,0,0,0],
#                  [1,0,0,0,0,0,0,0,0,0],
#                  [1,0,0,0,0,0,0,0,0,0],
#                  [1,0,0,0,0,0,0,0,0,0],
#                  [1,0,0,0,0,0,0,0,0,0],
#                  [1,0,0,0,0,0,0,0,0,0],
#                  [1,0,0,0,0,0,0,0,0,0],
#                  [1,0,0,0,0,0,0,0,0,0],
#                  [1,1,1,1,1,1,1,1,1,1]);


sub new
{
    my $class   = shift;
    my $size    = shift;
    my $density = shift;
    
    my $self = {
        RAIN            =>  zeros($size,$size),
        PERSON          =>  zeros($size,$size),
        SIZE            =>  $size,
        DENSITY         =>  $density,
        PERSON_TMPLT    =>  pdl( [1,0,0,0,0,0,0,0,0,0],
                                [1,0,0,0,0,0,0,0,0,0],
                                [1,0,0,0,0,0,0,0,0,0],
                                [1,0,0,0,0,0,0,0,0,0],
                                [1,0,0,0,0,0,0,0,0,0],
                                [1,0,0,0,0,0,0,0,0,0],
                                [1,0,0,0,0,0,0,0,0,0],
                                [1,0,0,0,0,0,0,0,0,0],
                                [1,0,0,0,0,0,0,0,0,0],
                                [1,1,1,1,1,1,1,1,1,1])
    };
    
    bless $self, $class;
    return $self;
}

sub init
{
    my $self = shift;
    my $size = $self->{SIZE};
    
    $self->{RAIN}   = zeros($size,$size);
    $self->{PERSON} =  zeros($size,$size);
    
    $self->{PERSON_CORN} = [[1, ($size-1)-10], [1,($size-1)], [11,($size-1)]];
    
    for my $i (1 .. $size)
    {
        $self->simulateRain;
    }
    $self->placePerson;
    
    


    
}

sub simulatePerson
{
    my $self = shift;
    my $speed = shift;
    my $size = $self->{SIZE};
    
    # Shift person over in grid
    my $range = tools::range(($size -1), 1);
    for my $x (@$range)
    {
        $self->{PERSON}->(:, $x) .= $self->{PERSON}->(:, $x-1);
    }
    
    # What drops were hit by movement
    my $point1x = $self->{PERSON_CORN}->[0]->[0];
    my $point1y = $self->{PERSON_CORN}->[0]->[1];
    my $point2x = ($self->{PERSON_CORN}->[1]->[0]+$speed > ($size -1))
                    ? ($size -1)
                    : $self->{PERSON_CORN}->[1]->[0]+$speed;
    my $point2y = $self->{PERSON_CORN}->[1]->[1];
    
    #print "$point1x   $point2x   $point1y    $point2y\n";
    my $sumDrops = sum( $self->{RAIN}->($point1x:$point2x, $point1y:$point2y) );
    $self->{RAIN}->($point1x:$point2x, $point1y:$point2y) .=0;
    #print $sumDrops."\n";
    
    # Shift person points over
    $self->{PERSON_CORN}->[0]->[0] += $speed;
    $self->{PERSON_CORN}->[1]->[0] += $speed;
    $self->{PERSON_CORN}->[2]->[0] += $speed;
    
    return $sumDrops;
    
    
    
}


sub simulateRain
{
    use tools;
    

    my $self = shift;
    my $size = $self->{SIZE};
    my ($personX, $personY) = dims($self->{PERSON_TMPLT});
    
    # Shift rain down
    my $range = tools::range(($size -1), 1);
    for my $y (@$range)
    {
        $self->{RAIN}->(:, $y) .= $self->{RAIN}->(:, $y-1);
    }
    
    # Add new rain
    my $density = $self->{DENSITY};
    $density = 1/$density;
    for my $x ($personX +1.. ($size-1))
    {
        my $rand = rand(1);
        if ($density lt $rand)
        {
            $self->{RAIN}->($x, 0) .= 1;
        }
        else
        {
            $self->{RAIN}->($x, 0) .= 0;
        }
        
    }

    #What drops were hit by rainfall
    my $point1x = $self->{PERSON_CORN}->[1]->[0];
    my $point1y = $self->{PERSON_CORN}->[1]->[1];
    my $point2x = $self->{PERSON_CORN}->[2]->[0];
    my $point2y = $self->{PERSON_CORN}->[2]->[1];
    
    my $sumDrops = sum $self->{RAIN}->($point1x:$point2x, $point1y:$point2y);
    $self->{RAIN}->($point1x:$point2x, $point1y:$point2y) .= 0;
    return $sumDrops;
    
}



    





sub placePerson
{
    my $self = shift;
    my $size = $self->{SIZE};
    my ($personX, $personY) = dims($self->{PERSON_TMPLT});
    
    $self->{PERSON}->(1:($personX), (($size-1)-($personY-1)):($size-1)) .= $self->{PERSON_TMPLT};
    
    #print $self->{PERSON};
    #print "\n\n";
    #print $self->{PERSON_TMPLT};
    
}

package tools;

################################################################################
# Function: range()
#
# Parameters:
# $a - First integer defining the range.
# $b - Second integer defining the range.
#
# Returns:
# \@range - Reference to array containing all the integers between $a and $b.
# The range will run backwards if $b is smaller than $a.
#
################################################################################
sub range
{
    my ($a, $b) = @_;
    $a = int($a);
    $b = int($b);
    
    my @range;
    if ($b > $a)
    {
        my $curr = $a;
        while ($curr <= $b)
        {
            push @range, $curr;
            $curr++;
        }
    }
    elsif ($b < $a)
    {
        my $curr = $a;
        while ($curr >= $b)
        {
            push @range, $curr;
            $curr--;
        }        
    }
    else
    {
        push @range, $a;
    }
    
    return \@range;
    
}
