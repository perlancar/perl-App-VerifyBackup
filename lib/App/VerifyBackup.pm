package App::VerifyBackup;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use File::chdir;

our %SPEC;

my $sqlspec = {
    latest_v => 1,
    install => [
        # files in the root of dir will have
        'CREATE TABLE IF NOT EXISTS file (name VARCHAR(255), pid INT NOT NULL, is_dir INT NOT NULL DEFAULT 0, size INT NOT NULL, hash_type VARCHAR(8) NOT NULL, hash TEXT)',
        'CREATE UNIQUE INDEX ix_file__pid__name ON file(pid, name)',
    ],
};

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

Then later and regularly, you verify the backup files in `dir` using:

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
        dir => {
            schema => 'str*',
            'x.completion' => ['dirname'],
            req => 1,
            pos => 1,
        },
    },
};
sub verify_backup {
    require DBI;
    require SQL::Schema::Versioned;

    my %args = @_;

    my $action = $args{action} // 'verify';
    my $db = $args{db};
    my $dir = $args{dir};

    if ($action eq 'verify') {
        return [412, "Checksum database must already exist"] unless -f $db;
    }

    my $dbh = DBI->connect("dbi:SQLite:dbname=$db", "", "");
    my $res = SQL::Schema::Versioned::create_or_update_db_schema(
        dbh=>$dbh, spec=>$sqlspec);
    return $res unless $res->[0] == 200;

    local $CWD = $dir;

    my $code_find = sub {
        my ($prefix, $pid) = @_;
        opendir my($dh), "." or do {
            $log->warnf("Can't chdir into %s, skipped", $prefix);
            return;
        };
        while (defined(my $e = readdir($dh))) {
            next if $e eq '.' || $e eq '..';
            $log->tracef("Processing %s/%s", $prefix, $e);

            # if symlink, stat the symlink itself
            my @st = stat($e);
            my @rst;
            if (-l _) {
                @rst = @st;
                @st = lstat($e);
            }

            my @rst;
            if (-l _) {

            my @st = lstat($e);

        }
    };

    $code_find->(".", 0);

    if ($action eq 'update_db') {
        # XXX
    } elsif ($action eq 'verify') {
        # XXX
    }

    [200];
}

1;
# ABSTRACT:

=head1 DESCRIPTION


=head1 SEE ALSO

Some backup tools: C<rsync>, L<File::RsyBak>
