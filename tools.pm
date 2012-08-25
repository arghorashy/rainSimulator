use strict;
use warnings;


package tools;

use PDL;
use PDL::NiceSlice;

################################################################################
# File: tools.pm
#
# A collection of custom tools that are used throughout the program to make
# repetitive, widely used tasks less cumbersome to perform.
#
################################################################################


################################################################################
# Function: array2hash()
#
# Parameters:
# $array - Reference to 1D array of scalars.
#
# Returns:
# \%hash - Reference to hash. For each of the array's values, there is a key
# with the same name pointing to that value within the hash table. 
#
################################################################################
sub array2hash
{
    my ($array) = @_;
    my %hash;
    foreach my $value (@$array)
    {
        $hash{$value} = $value;
    }
    return \%hash;  
    
}



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


################################################################################
# Function: haselement
#
# Parameters:
# $array - Reference to scalar array.
# $element - Element to find in array.
#
# Returns:
# 1 if the element is contained in the array, 0 if it isn't.
#
################################################################################
sub haselement
{
    my ($array, $element) = @_;
    my $arrayashash = array2hash($array);
    
    if (exists $$arrayashash{$element})
    {
        return 1;
    }
    else { return 0; }
    
    
}

################################################################################
# Function: nextkey
#
# Parameters:
# $hash - Reference to hash.
#
# Returns:
# Returns the first key in (keys %{$hash}) if there are any.
# Return -1 if there aren't any keys in %$hash.
#
################################################################################
sub nextkey
{
    my ($hash) = @_;
    

    
    my @keys = (keys %{$hash});
    

    
    if (exists $keys[0])
    {
        return $keys[0]; 
    }
    else
    {
        return -1;
    }
}

# Must be hashes with only scalars
sub cmpHashes
{
    my ($hash1, $hash2) = @_;
    
    my @contents1 = (sort keys %$hash1, sort values %$hash1);
    my @contents2 = (sort keys %$hash2, sort values %$hash2);
    
    my @xor1 = grep { ! haselement(\@contents2, $_) } @contents1;
    my @xor2 = grep { ! haselement(\@contents1, $_) } @contents2;
    
    my @xor = (@xor1, @xor2);
    
    ((scalar @xor) == 0) ? (return 1) : (return 0);

    
    
    
}

################################################################################
# Function: nextkey
#
# Parameters:
# @array - Array of numbers.
#
# Returns:
# $avg -  The statistical mode of the set of numbers (ignoring all zeros).
#
################################################################################
sub modeIgnoreZero
{
    my (@array) = @_;
    my %ctr;
    my %ctrInv;
    
    for my $element (@array)
    {
        if ($element != 0)
        {
            if (exists $ctr{$element})
            {
                $ctr{$element}++;
            }
            else
            {
                $ctr{$element} = 1;
            }
        }
    }
    
    my %invCtr = reverseHash(%ctr);
    
    foreach my $key (sort {$b <=> $a} keys %invCtr)
    {
        my $avg=0;
        for my $value (@{$invCtr{$key}})
        {
                $avg += $value;

        }
        $avg /= scalar @{$invCtr{$key}};
        
        return $avg;
    }


}


################################################################################
# Function: nextkey
#
# Parameters:
# %hash - Hash table containing only scalar values.
#
# a => 1
# b => 2
# c => 3
# d => 1
#
# Returns:
# %hashInv
#
# 1 => (a,d)
# 2 => (b)
# 3 => (c)
#
################################################################################
sub reverseHash
{
    my (%hash) = @_;
    
    my %hashInv;
    
    for my $key (keys %hash)
    {
        my $value = $hash{$key};
        
        push @{$hashInv{$value}}, int($key)
        
    }
    
    return %hashInv;
}


# If there is a key collision, the value from hash2 will clobber the value from hash 1.
sub unionHashes
{
    use Storable qw(dclone); 
    my ($hash1, $hash2) = @_;
    
    my $unionHash = dclone($hash1);
    
    foreach my $key (keys %$hash2)
    {
        $unionHash->{$key} = $$hash2{$key};
    }
    
    return %$unionHash;
}



################################################################################
# Function: GetConfig()
# Returns with a pointer to hash table containing a set of named configuration
# values that characterise the fontsize, drawing size and font geometry used by
# the drawing being decoded. One hash value is a set of valid relay name
# suffixes that are used to "spell-check" the relay name OCR process. All of
# these configuration values are kept in a separate configuration file called
# "OCRconfig.txt". (see DocCode/OCRconfig.html)
################################################################################

sub GetConfig
{
    my ($MW) = @_;
    use Config::Tiny;
    use FindBin qw($Bin);  # execution path
    

    my $path = $Bin . '/OCRconfig.txt';
    print "\nChecking for configuration file in $path...\n";
    
    my $Config  = Config::Tiny->read( $path );
    if (! defined $Config)
    {
        if (defined $MW)
        {
            $MW->messageBox(-message => "Fatal:\n\nCannot find configuration file (\"OCRconfig.txt\").");
            exit;
        }
        else
        {
            die "Fatal:\n\nCannot find configuration file (\"OCRconfig.txt\").";
        }
    }
        
    return $Config;
}

sub getContactTypeList
{
    my $Config = GetConfig();
    
    my @typeList;
    
    for my $type (keys %{$Config->{ObjOFFSET}})
    {
        push @typeList, $type;
    }
                      
    return @typeList;
    
}

sub newBiHashedLinkedList
{
    my ($list_ref) = @_;
    
    my @list = @$list_ref;
    my $bhll;
    
    # Add all items
    for my $ind (0 .. $#list)
    {
        $bhll->{$list[$ind]}->{VALUE} = $list[$ind];
    }
    
    # Add all connexions except from last and from first element
    for my $ind (1 .. ($#list-1))
    {
        $bhll->{$list[$ind]}->{NEXT} = $bhll->{$list[$ind+1]};
        $bhll->{$list[$ind]}->{PREV} = $bhll->{$list[$ind-1]};
    }
    
    # Add connexsions for first one
    $bhll->{$list[0]}->{NEXT} = $bhll->{$list[1]};
    $bhll->{$list[0]}->{PREV} = $bhll->{$list[-1]};
    
    # Add connexsions for last one
    $bhll->{$list[-1]}->{NEXT} = $bhll->{$list[0]};
    $bhll->{$list[-1]}->{PREV} = $bhll->{$list[-2]};
    
    # Add start
    $bhll->{START} = $bhll->{$list[0]};
    
    return $bhll;
    
    
}


1;

package File_Mgmt;

our $config_folder_name = "OCR_conf";

sub changeSuffix
{
    use File::Basename;
    
    my ($path, $newSuff, @oldSuff) = @_;
    
    my $oldSuffStr;
    for my $i (0 .. $#oldSuff)
    {
        $oldSuffStr .= $oldSuff[$i];
        if (defined $oldSuff[$i+1])
        {
            $oldSuffStr .= "|";
        }
    }
    
    $path =~ s/($oldSuffStr)/$newSuff/;

    
    return $path;
    
    
}

sub getLtrKernelMasksPath
{
    use File::Basename;
    
    my ($dwgpath) = @_;
    
    my $path = dirname($dwgpath);
    my $newPath = $path . "/" .  $config_folder_name;
    
    unless(-d $newPath)
    {
        mkdir $newPath or die;
    }
    
    my $LtrKernelMasksPath = $newPath . "/Ltr_Kernel_masks.txt";
    return $LtrKernelMasksPath;
    
}

sub getObjKernelMasksPath
{
    use File::Basename;
    
    my ($dwgpath) = @_;
    
    my $path = dirname($dwgpath);
    my $newPath = $path . "/" .  $config_folder_name;
    
    unless(-d $newPath)
    {
        mkdir $newPath or die;
    }

    
    my $ObjKernelMasksPath = $newPath . "/Obj_Kernel_masks.txt";
    return $ObjKernelMasksPath;
    
}

sub getDerivativeFilePath
{
    use File::Basename;
    
    my ($path, $newSuff, @oldSuff) = @_;
    
    my $newDir = changeSuffix($path,"", @oldSuff);
    my $basename = basename($newDir);
    my $newPath = $newDir . "/" . $basename . "$newSuff";
    
    
    
    unless(-d $newDir)
    {
        mkdir $newDir or die;
    }
    

    return $newPath;  
    
}

sub getDwgList
{
    my ($MW) = @_;
    

    #---------------- Get list of .png's -----------------#

    my $types = [ ['Relay Drawings', ['.png', ".PNG"]], ['All', ['.*']], ];
    my @Fname = $MW->getOpenFile( -title            => 'SPECIFY FILENAMES',
                                  -filetypes        => $types,
                                  -multiple         => 1,
                                  -defaultextension => '.png');
    if ( ! @Fname ) { return; }
    my $num = scalar @Fname;
    
    return @Fname;
    
    
}






1;

