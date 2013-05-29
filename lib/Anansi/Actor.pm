package Anansi::Actor;


=head1 NAME

Anansi::Actor - A dynamic usage module definition

=head1 SYNOPSIS

 use Anansi::Actor;
 my $object = Anansi::Actor->new(
     PACKAGE => 'Anansi::Example',
 );
 $object->someSubroutine() if(defined($object));

 use Anansi::Actor;
 use Data::Dumper qw(Dumper);
 my %modules = Anansi::Actor->modules();
 if(defined($modules{DBI})) {
     Anansi::Actor->new(
         PACKAGE => 'DBI',
     );
     print Data::Dumper::Dumper(DBI->available_drivers());
 }

=head1 DESCRIPTION

This is a dynamic usage module definition that manages the loading of a required
namespace and blessing of an object of the namespace as required.  See
I<Anansi::Singleton> for inherited methods.  Makes uses of I<base>, I<Fcntl>
I<File::Find>, I<File::Spec::Functions> and I<FileHandle>.

=cut


our $VERSION = '0.07';

use base qw(Anansi::Singleton);

use Fcntl ':flock';
use File::Find;
use File::Spec::Functions;
use FileHandle;


my $ACTOR = Anansi::Actor->SUPER::new();

use constant {
    ACTOR_VARIABLE => 'example',
};


=head1 METHODS

=cut


=head2 implicate

 use constant {
     ACTOR_VARIABLE => 'some value',
 };

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

=head3 PARAMETERS

=over 4

=item self

(I<BLESSED HASH>, I<REQUIRED>)
An object of this namespace.

=item caller

(I<ARRAY>, I<REQUIRED>)
An ARRAY containing the I<package>, I<file name> and I<line number> of the caller.

=item parameter

(I<STRING>, I<REQUIRED>)
A STRING containing the name to import.

=back

Performs one module instance name import.  Called for each name to import.

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

=head3 PARAMETERS

=over 4

=item self

(I<BLESSED HASH>, I<REQUIRED>)
An object of this namespace.

=item parameters

(I<ARRAY>, I<OPTIONAL>)
An ARRAY containing all of the names to import.

=back

Performs all required module name imports.  Indirectly called via an extending
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

 my %MODULES = $object->modules();

 use Anansi::Actor;
 my %MODULES = Anansi::Actor->modules();

=head3 PARAMETERS

=over 4

=item self

(I<BLESSED HASH>, I<REQUIRED>)
An object of this namespace.

=back

Builds and returns a HASH of all the modules and their paths that are available
on the operating system.  A temporary file "Anansi-Actor.#" will be created if
at all possible to improve the speed of this subroutine by storing the module
HASH.  The temporary file will automatically be updated when this subroutine is
run once a full day has passed.  Deleting the temporary will also cause an
update to occur.

=cut


sub modules {
    my ($self) = @_;
    my $filename;
    if(opendir(DIRECTORY, File::Spec->tmpdir())) {
        my @files = reverse(sort(grep(/^Anansi-Actor\.\d+$/, readdir(DIRECTORY))));
        closedir(DIRECTORY);
        if(0 < scalar(@files)) {
            my $timestamp = (split(/\./, $files[0]))[1];
            if(86400 + $timestamp < time()) {
                unlink(@files);
                $filename = 'Anansi-Actor.'.time();
            } else {
                $filename = $files[0];
            }
        } else {
            $filename = 'Anansi-Actor.'.time();
        }
    }
    my $filepath;
    if(defined($filename)) {
        $filepath = File::Spec->catfile(File::Spec->splitdir(File::Spec->tmpdir()), $filename);
        if(!defined($ACTOR->{MODULES})) {
            if(open(FILE_HANDLE, '<'.$filepath)) {
                flock(FILE_HANDLE, LOCK_EX);
                my @contents = <FILE_HANDLE>;
                my $content = join(',', @contents);
                flock(FILE_HANDLE, LOCK_UN);
                close(FILE_HANDLE);
                %{$ACTOR->{MODULES}} = split(',', $content);
            }
        }
    }
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
                    return if(defined(${$ACTOR->{MODULES}}{$package}));
                    ${$ACTOR->{MODULES}}{$package} = $path;
                },
                follow => 1,
                follow_skip => 2,
                no_chdir => 1,
            },
            @INC
        );
    }
    if(defined($filepath)) {
        if(open(FILE_HANDLE, '<'.$filepath)) {
            close(FILE_HANDLE);
        } else {
            my $content = join(',', @{[%{$ACTOR->{MODULES}}]});
            if(open(FILE_HANDLE, '+>'.$filepath)) {
                FILE_HANDLE->autoflush(1);
                flock(FILE_HANDLE, LOCK_EX);
                print FILE_HANDLE $content;
                flock(FILE_HANDLE, LOCK_UN);
                close(FILE_HANDLE);
            }
        }
    }
    return %{$ACTOR->{MODULES}};
}


=head2 new

 my $object = Anansi::Actor->new(
     PACKAGE => 'Anansi::Example',
 );

=head3 PARAMETERS

=over 4

=item class

(I<REQUIRED>)

(I<BLESSED HASH>)
An object of this namespace.

(I<STRING>)
A STRING of the namespace.

=item parameters

(I<HASH>)
Named parameters.

=over 4

=item BLESS

(I<STRING>, I<OPTIONAL>)
The name of the subroutine within the namespace that creates a blessed object of
the namespace.

=item IMPORT

(I<ARRAY>, I<OPTIONAL>)
An ARRAY of the names to import from the loading module.

=item PACKAGE

(I<STRING>, I<REQUIRED>)
The namespace of the module to load.

=item PARAMETERS

(I<OPTIONAL>)

(I<ARRAY>)
An ARRAY of the parameters to pass to the blessing subroutine.

(I<HASH>)
A HASH of the parameters to pass to the blessing subroutine.

=back

=back

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
