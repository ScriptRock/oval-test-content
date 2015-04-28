#!/usr/bin/env perl
use warnings;
use strict;

# the OVAL IDs in the test case files aren't unique. So when I aggregate them in a DB somewhere, things start to break...
# Script to loop over files and uniquify offending IDs based on the non-first lexicographic file with the id.

my $global_id_files;
my $must_uniquify_files;
my %used_ids;

for (my $i = 0; $i <= $#ARGV; $i++) {
	my $filepath = $ARGV[$i];

	my $contents = `cat $filepath`;

	while ( $contents =~ /\bid="(.*?)"/g ) {
		my $found_id = $1;
		$global_id_files->{$found_id}->{$filepath} = 1;
		$used_ids{$found_id} = 1;
	}
}

foreach my $id (sort keys %{$global_id_files}) {
	my @files_with_id = sort keys %{$global_id_files->{$id}};
	if ($#files_with_id > 0) {
		for (my $i = 1; $i <= $#files_with_id; $i++) {
			$must_uniquify_files->{$files_with_id[$i]}->{$id} = 1;
		}
	}
}

foreach my $filepath (sort keys %{$must_uniquify_files}) {
	my @ids_to_uniquify = sort keys %{$must_uniquify_files->{$filepath}};
	uniquify($filepath, @ids_to_uniquify);
}


sub replacement_id {
	my $id = shift;
	while (defined($used_ids{$id})) {
		# add nines to the start of the ID until it doesn't clash
		$id =~ s/(\d+)$/9$1/g;
	}
	$used_ids{$id} = 1;
	return $id;
}

sub uniquify {
	my ($filepath, @ids_to_uniquify) = @_;

	my %replacements;
	print "file '$filepath' has duplicate ids from elsewhere\n";
	foreach my $id (@ids_to_uniquify) {
		my $rid = replacement_id($id);
		$replacements{$id} = $rid;
		print "\t$id -> $rid\n";
	}

	my $contents = `cat $filepath`;
	foreach my $from (sort keys %replacements) {
		my $to = $replacements{$from};
		my $from_re = quotemeta($from);
		$contents =~ s/\b$from_re\b/$to/ge;

		open(my $fh, '>', $filepath) or die "Could not open file '$filepath': $!";
		print $fh $contents;
		close $fh;
	}
}

