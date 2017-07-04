#!perl

use strict;
use warnings;
use Test::More;
use Test::LeakTrace;

my @correct = ( "3 2 1", "2 3 1", "2 1 3", "3 1 2", "1 3 2", "1 2 3" );

BEGIN {
    use_ok( 'Algorithm::Permute', qw(permute) );
}

######################### End of black magic.

# Insert your test code below (better if it prints "ok 13"
# (correspondingly "not ok 13") depending on the success of chunk 13
# of the test code):

my $perm = Algorithm::Permute->new( [ 1 .. 3 ] );
ok( $perm, 'new' );

# peek..
my @peek = $perm->peek;
is( "@peek", $correct[0], "peek" );

# next..
my $cnt = 0;
while ( my @res = $perm->next ) {
    is( "@res", $correct[ $cnt++ ], "next" );
}

# reset..
$cnt = 0;
$perm->reset;
while ( my @res = $perm->next ) {
    is( "@res", $correct[ $cnt++ ], "after reset" );
}

is( $cnt, scalar(@correct), "number of permutions" );

# Tests for the callback interface by Robin Houston <robin@kitsite.com>

my @array = ( 1 .. 9 );
my $i     = 0;
permute { ++$i } @array;

is( $i,        9 * 8 * 7 * 6 * 5 * 4 * 3 * 2 * 1 );
is( $array[0], 1 );

@array = ();
$i     = 0;
permute { ++$i } @array;
is( $i, 0 );

@array = ( 'A' .. 'E' );
my @foo;
permute { @foo = @array; } @array;

my $ok = ( join( "", @foo ) eq join( "", reverse @array ) );
ok($ok);

#{
#   tie @array, 'TieTest';
#   permute { $_ = "@array" } @array;
#   print (TieTest->c() == 600 ? "ok 21\n" : "not ok 21\t# ".TieTest->c()."\n");
#   untie @array;
#}

##########################################
# test eval block outside of permute block
{
    @array = ( 1 .. 2 );
    $i     = 0;
    eval {
        permute {
            die if ( ++$i > 1 )
        }
        @array;
    };
    pass("permute block in eval block");
    eval { @array = ( 1 .. 2 ); };    # try to change the array after die()
    ok( !$@, "try to change the array after die()" );
}

######################################
# test eval block inside permute block
my @array = qw/a r s e/;
my $i     = 0;
permute {
    eval { goto foo };
    ++$i
}
@array;
if ( $@ =~ /^Can't "goto" out/ ) {
    pass();
}
else {
  foo:
    diag($@);
    fail();
}
is( $i, 24 );

{
    # test r of n permutation
    my %expected = map { $_ => 1 } qw/2_1 1_2 3_2 2_3 3_1 1_3/;
    my $p = Algorithm::Permute->new( [ 1 .. 3 ], 2 );
    ok($p);

    my $found;
    while ( my @r = $p->next ) {
        my $key = join( '_', @r );

        # print "key: $key\n";
        $found = delete $expected{$key};
        last unless $found;
    }
    if ( not $found or keys(%expected) ) {
        fail();
    }
    else {
        pass();
    }
}

######################
# test for memory leak

SKIP: {
    if ( $^O !~ /linux/ || !$ENV{MEMORY_TEST} ) {
        skip( "memory leak test disabled", 5 );
    }

    # OO interface memory leak test
    no_leaks_ok {
        for ( $i = 0 ; $i < 10000 ; $i++ ) {
            $perm->reset;
            while ( my @res = $perm->next ) { }
        }
    } 'OO interfae memory leak test';

    no_leaks_ok {
        for ( $i = 0 ; $i < 10000 ; $i++ ) {
            @array = ( 'A' .. 'E' );
            permute {} @array;
        }
    };

    no_leaks_ok {
        for ( $i = 0 ; $i < 10000 ; $i++ ) {
            @array = ( 'A' .. 'E' );
            eval {
                permute { die } @array;
            };
        }
    };

    # test A::P destructor
    no_leaks_ok {
        for ( $i = 0 ; $i < 10000 ; $i++ ) {
            my $p = Algorithm::Permute->new( [ 1 .. 4 ] );
            while ( my @res = $p->next ) { }
        }
    } 'A::P destructor memory leak test';

    no_leaks_ok {
        # test A::P destructor, r of n permutation
        for ( $i = 0 ; $i < 10000 ; $i++ ) {
            my $p = Algorithm::Permute->new( [ 1 .. 4 ], 3 );
            while ( my @res = $p->next ) { }
        }
    } 'A::P destructor memory leak test, r of n permutation';
}

done_testing;

my $c;

package TieTest;
sub TIEARRAY { bless [] }
sub FETCHSIZE { 5 }
sub FETCH     { ++$c; $_[1] }
sub c         { $c }
