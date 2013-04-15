package Anansi::Actor;


=head1 NAME

Anansi::Actor - A dynamic usage module definition

=head1 SYNOPSIS

 use Anansi::Actor;

 my $object = Anansi::Actor->new(
  PACKAGE => 'Anansi::Example',
 );

=head1 DESCRIPTION

This is a dynamic usage module definition that manages the loading of a required
namespace and blessing of an object of said namespace as required.

=cut


our $VERSION = '0.04';

use base qw(Anansi::Singleton);

use File::Find;
use File::Spec::Functions;


my $ACTOR = Anansi::Actor->SUPER::new();


=head1 CONSTANTS

=cut


=head2 ACTOR_VARIABLE

N/A

=cut


use constant {
    ACTOR_VARIABLE => 'example',
};


=head1 METHODS

=cut


=head2 implicate

 sub implicate {
     my ($self, $caller, $parameter) = @_;
     if('ACTOR_VARIABLE' eq $parameter) {
         return \ACTOR_VARIABLE;
     }
     try {
         return $self->SUPER::implicate($caller, $parameter);
     }
     return if($@);
 }

Performs module instance object variable imports.

=cut


sub implicate {
    my ($self, $caller, $parameter) = @_;
    if('ACTOR_VARIABLE' eq $parameter) {
        return \ACTOR_VARIABLE;
    }
    try {
        return $self->SUPER::implicate($caller, $parameter);
    }
    return if($@);
}


=head2 import

 use Anansi::Actor qw(ACTOR_VARIABLE);

Performs all required module imports.  Indirectly called via an extending
module.

=cut


sub import {
    my ($self, @parameters) = @_;
    my $caller = caller();
    foreach my $parameter (@parameters) {
        my $value = $self->implicate($caller, $parameter);
        *{$caller.'::'.$parameter} = $value if(defined($value));
    }
}


=head2 modules

 my $MODULES = $object->modules();

 # OR

 use Anansi::Actor;

 my $MODULES = Anansi::Actor->modules();

Builds and returns a HASH of all the modules and their paths that are available
on the operating system.  Indirectly called via an extending module.

=cut


sub modules {
    my ($self, %parameters) = @_;
    if(!defined($ACTOR->{MODULES})) {
        $ACTOR->{MODULES} = {};
        File::Find::find(
            {
                wanted => sub {
                    my $path = File::Spec->canonpath($_);
                    return if($path !~ /\.pm$/);
                    return if(!open(FILE, $path));
                    my $package;
                    my $pod = 0;
                    while(<FILE>) {
                        chomp;
                        if(/^=cut.*$/) {
                            $pod = 0;
                            next;
                        }
                        $pod = 1 if(/^=[a-zA-Z]+.*$/);
                        next if($pod);
                        next if($_ !~ /^\s*package\s+[a-zA-Z0-9_:]+\s*;.*$/);
                        ($package = $_) =~ s/^\s*package\s+([a-zA-Z0-9_:]+)\s*;.*$/$1/;
                    }
                    close(FILE);
                    return if(!defined($package));
                    return if(defined(%{$ACTOR->{MODULES}}->{$package}));
                    %{$ACTOR->{MODULES}}->{$package} = $path;
                },
                follow => 1,
                follow_skip => 2,
                no_chdir => 1,
            },
            @INC
        );
    }
    return %{$ACTOR->{MODULES}};
}


=head2 new

 my $object = Anansi::Actor->new(
  PACKAGE => 'Anansi::Example',
 );

Instantiates an object instance of a dynamically loaded module.

=cut


sub new {
    my ($class, %parameters) = @_;
    return if(!defined($parameters{PACKAGE}));
    return if(ref($parameters{PACKAGE}) !~ /^$/);
    return if($parameters{PACKAGE} !~ /^[a-zA-Z]+[a-zA-Z0-9_]*(::[a-zA-Z]+[a-zA-Z0-9_]*)*$/);
    if(!defined($parameters{BLESS})) {
        $parameters{BLESS} = 'new';
    } else {
        return if(ref($parameters{BLESS}) !~ /^$/);
        return if($parameters{BLESS} !~ /^[a-zA-Z]+[a-zA-Z0-9_]*$/);
    }
    if(defined($parameters{PARAMETERS})) {
        $parameters{PARAMETERS} = [(%{$parameters{PARAMETERS}})] if(ref($parameters{PARAMETERS}) =~ /^HASH$/i);
        return if(ref($parameters{PARAMETERS}) !~ /^ARRAY$/i);
    }
    if(defined($parameters{IMPORT})) {
        return if(ref($parameters{IMPORT}) !~ /^ARRAY$/i);
        foreach my $import (@{$parameters{IMPORT}}) {
            return if(ref($import) !~ /^$/);
            return if($import !~ /^[a-zA-Z_]+[a-zA-Z0-9_]*$/);
        }
    }
    my $package = $parameters{PACKAGE};
    my $bless = $parameters{BLESS};
    my $self;
    eval {
        (my $file = $package) =~ s/::/\//g;
        require $file.'.pm';
        if(defined($parameters{IMPORT})) {
            $package->import(@{$parameters{IMPORT}});
        } else {
            $package->import();
        }
        if(defined($parameters{PARAMETERS})) {
            $self = $package->$bless(@{$parameters{PARAMETERS}});
        } else {
            $self = $package->$bless();
        }
        1;
    } or do {
        my $error = $@;
        return ;
    };
    return $self;
}


=head1 AUTHOR

Kevin Treleaven <kevin AT treleaven DOT net>

=cut


1;
