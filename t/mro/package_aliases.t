#!./perl

BEGIN {
    unless (-d 'blib') {
        chdir 't' if -d 't';
        @INC = '../lib';
    }
    require q(./test.pl);
}

use strict;
use warnings;
plan(tests => 12);

{
    package New;
    use strict;
    use warnings;

    package Old;
    use strict;
    use warnings;

    {
      no strict 'refs';
      *{'Old::'} = *{'New::'};
    }
}

ok (Old->isa (New::), 'Old inherits from New');
ok (New->isa (Old::), 'New inherits from Old');

isa_ok (bless ({}, Old::), New::, 'Old object');
isa_ok (bless ({}, New::), Old::, 'New object');


no warnings; # temporary, until bug #77358 is fixed

# Test that replacing a package by assigning to an existing glob
# invalidates the isa caches
for(
 {
   name => 'assigning a glob to a glob',
   code => '$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}',
 },
 {
   name => 'assigning a string to a glob',
   code => '$life_raft = $::{"Left::"}; *Left:: = "Right::"',
 },
 {
   name => 'assigning a stashref to a glob',
   code => '$life_raft = \%Left::; *Left:: = \%Right::',
 },
) {
 fresh_perl_is
   q~
     @Subclass::ISA = "Left";
     @Left::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     # mro_package_moved needs to know to skip non-globs
     $Right::{"gleck::"} = 3;

     @Right::ISA = 'TopRight';
     my $life_raft;
    __code__;

     print $thing->speak, "\n";

     undef $life_raft;
     print $thing->speak, "\n";
   ~ =~ s\__code__\$$_{code}\r,
  "Bow-wow!\nBow-wow!\n",
   {},
  "replacing packages by $$_{name} updates isa caches";
}

# Similar test, but with nested packages
for(
 {
   name => 'assigning a glob to a glob',
   code => '$life_raft = $::{"Left::"}; *Left:: = $::{"Right::"}',
 },
 {
   name => 'assigning a string to a glob',
   code => '$life_raft = $::{"Left::"}; *Left:: = "Right::"',
 },
 {
   name => 'assigning a stashref to a glob',
   code => '$life_raft = \%Left::; *Left:: = \%Right::',
 },
) {
 fresh_perl_is
   q~
     @Subclass::ISA = "Left::Side";
     @Left::Side::ISA = "TopLeft";

     sub TopLeft::speak { "Woof!" }
     sub TopRight::speak { "Bow-wow!" }

     my $thing = bless [], "Subclass";

     @Right::Side::ISA = 'TopRight';
     my $life_raft;
    __code__;

     print $thing->speak, "\n";

     undef $life_raft;
     print $thing->speak, "\n";
   ~ =~ s\__code__\$$_{code}\r,
  "Bow-wow!\nBow-wow!\n",
   {},
  "replacing nested packages by $$_{name} updates isa caches";
}

# Test that deleting stash elements containing
# subpackages also invalidates the isa cache.
# Maybe this does not belong in package_aliases.t, but it is closely
# related to the tests immediately preceding.
{
 @Pet::ISA = ("Cur", "Hound");
 @Cur::ISA = "Hylactete";

 sub Hylactete::speak { "Arff!" }
 sub Hound::speak { "Woof!" }

 my $pet = bless [], "Pet";

 my $life_raft = delete $::{'Cur::'};

 is $pet->speak, 'Woof!',
  'deleting a stash from its parent stash invalidates the isa caches';

 undef $life_raft;
 is $pet->speak, 'Woof!',
  'the deleted stash is gone completely when freed';
}
