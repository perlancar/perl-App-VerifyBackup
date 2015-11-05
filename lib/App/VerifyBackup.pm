package App::VerifyBackup;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;

our %SPEC;

$SPEC{':package'} = {
    v => 1.1,
    summary => 'Verify backup using checksums stored in a SQLite database',
    description => <<'_',

Backup files need to be verified regularly, so we can know that they are/will be
usable when needed. To verify, we either compare/re-sync with the original files
(e.g. using `diff -R` or `rsync`). Or, in the absence of the original data, we
store the checksum of the original files and then read the backup files and
compare the checksums with the originals'.

Newer filesystem like ZFS provides data integrity/block checksumming feature, so
all you need to do is something like ZFS's `zpool scrub` (e.g. weekly). It can
even repair data from a duplicate/parity when a block fails a checksum.

In older/simpler filesystem, this utility can help. This utility records the
checksums of files into a SQLite database. Then, later, you verify the backup
files using the checksum database.

_
};

$SPEC{verify_backup} = {
    v => 1.1,
    summary => 'Verify backup using checksums stored in a SQLite database',
    description => <<'_',

To use this utility, first, you create the checksum database:

    % verify-backup --update-db dir.db dir

Then later and regularly, you verify the backup files in `dir`:

    % verify-backup dir.db dir

The utility will report missing files, extraneous files, and files with
mismatching checksums.

_
    args => {
        action => {
            schema => ['str*', in => ['verify', 'update_db']],
            default => 'verify',
            cmdline_aliases => {
                update_db => {
                    summary => 'Shortcut for --action=update_db',
                    schema => ['bool', is=>1],
                    code => sub { $_[0]{action} = 'update_db' },
                },
            },
        },
        db => {
            schema => 'str*',
            'x.completion' => ['filename'],
            req => 1,
            pos => 0,
        },
        files => {
            schema => ['array*', of=>'str*', min_len=>1],
            'x.element_completion' => ['filename'],
            req => 1,
            pos => 1,
            greedy => 1,
        },
    },
};
sub verify_backup {
    require DBI;

    my %args = @_;

    my $action = $args{action};
    my $db = $args{db};
    my $files = $args{files};

    if ($action eq 'verify') {
        return [412, "Checksum database must already exist"] unless -f $db;
    }

    my $dbh = DBI->connect("dbi:SQLite:dbname=$db", "", "");

    if ($action eq 'update_db') {
        # XXX
    } elsif ($action eq 'verify') {
        # XXX
    }
}

1;
# ABSTRACT:

=head1 DESCRIPTION


=head1 SEE ALSO

Some backup tools: C<rsync>, L<File::RsyBak>
