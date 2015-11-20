package App::VerifyBackup;

# DATE
# VERSION

use 5.010001;
use strict;
use warnings;
use Log::Any::IfLOG '$log';

use Digest::SHA qw(sha512_base64);

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

    my @errs_unreadable;

    my $code_find;
    $code_find = sub {
        my %cfargs = @_;
        my $prefix = $cfargs{prefix};

        opendir my($dh), "." or do {
            $log->warnf("Can't chdir into %s, skipped", $prefix);
            return;
        };

      FILE:
        for my $e (sort readdir($dh)) {
            next FILE if $e eq '.' || $e eq '..';
            my $path = "$prefix/$e";
            $log->tracef("Processing %s ...", $path);
            my @lstat = lstat($e);
            if (!@lstat) {
                my $err = "Can't lstat: $!";
                push @errs_unreadable, [$path, $err];
                $log->errorf("[%s] %s", $path, $err);
                next FILE;
            }
            if (-l _) {
                my $readlink = readlink($e);
                if (!defined($readlink)) {
                    my $err = "Can't read symlink: $!";
                    push @errs_unreadable, $err;
                    next FILE;
                }
                $cfargs{on_file}->(
                    is_symlink => 1,
                    name => $e,
                    prefix => $prefix,
                    target => $readlink,
                );
            } elsif (-d _) {
                if (!chdir($e)) {
                    my $err = "Can't chdir: $!";
                    $log->errorf("[%s] %s", $path, $err);
                    # XXX report errors for all files under it
                    next FILE;
                }
                $code_find->(%cfargs, prefix=>$path); # XXX pid
                chdir "..";
            } elsif (!(-f _)) {
                # skip special files
                next FILE;
            } else {
                # XXX verify link against digest
            }
        }
    };

    if ($action eq 'update_db') {
        $code_find->(
            prefix => ".",
            # XXX pid
        );
    } elsif ($action eq 'verify') {
        $code_find->(
            prefix => ".",
            on_file => sub {
                my %hargs = @_;
                if ($hargs{is_symlink}) {
                    say "$hargs{name}: ", sha512_base64($hargs{target});
                } else {
                }
            },
        );
    }

    [200];
}

1;
# ABSTRACT:

=head1 DESCRIPTION


=head1 SEE ALSO

Some backup tools: C<rsync>, L<File::RsyBak>
