use hyperize:ver<0.0.2>:auth<zef:lizmat>;
use paths:ver<10.0.6>:auth<zef:lizmat>;
use Lines::Containing:ver<0.0.8>:auth<zef:lizmat>;

my sub is-simple-Callable($needle) {
    Callable.ACCEPTS($needle) && !Regex.ACCEPTS($needle)
}

my proto sub files-containing(|) {*}
my multi sub files-containing(
  Any:D   $needle,
          $root?,
  List() :$extensions,
         :$include-dot-files,
         :$file is copy,
         :$dir,
         :$follow-symlinks,
         :$sort,
         *%_
) {
    without $file {
        my @exts := $extensions // ();
        my $ext  := @exts[0];

        $file = $include-dot-files
          ?? $ext
            ?? @exts == 1
              ?? *.ends-with($ext)
              !! *.ends-with(any(@exts))
            !! True
          !! $ext
            ?? @exts == 1
              ?? { .ends-with($ext)       && !.starts-with(".") }
              !! { .ends-with(any(@exts)) && !.starts-with(".") }
            !! !*.starts-with(".")
    }
    my $seq := paths($root, :$file, :$dir, :$follow-symlinks);
    files-containing(
      $needle,
      $sort
        ?? Callable.ACCEPTS($sort)
          ?? $seq.sort($sort)
          !! $seq.sort
        !! $seq,
      |%_
    )
}
my multi sub files-containing(
  Any:D  $needle,
         @files,
        :ignorecase(:$i),
        :ignoremark(:$m),
        :$offset = 0,
        :$files-only,
        :$batch,
        :$degree,
        :$max-count,
        :$invert-match,
        :$count-only,
) {
    @files.&hyperize($batch, @files == 1 ?? 1 !! $degree)
      .map: $files-only
        ?? is-simple-Callable($needle)
          ?? -> IO() $io {
                 my $slurped := try $io.slurp(:enc<utf8-c8>);
                 $io if $slurped.defined && $needle($slurped)
             }
          !! -> IO() $io {
                 my $slurped := try $io.slurp(:enc<utf8-c8>);
                 $io if $slurped && $slurped.contains($needle, :$i, :$m)
             }
        !! is-simple-Callable($needle)
          ?? -> IO() $io {
                 with lines-containing(
                   $io, $needle, :$i, :$m, :p, :$max-count,
                   :$offset, :$invert-match, :$count-only,
                 ) -> \result {
                     $io => ($count-only ?? result !! result.Slip)
                       if result.elems;
                 }
             }
          !! -> IO() $io {
                 my $slurped := try $io.slurp(:enc<utf8-c8>);
                 if $slurped && $slurped.contains($needle, :$i, :$m) {
                     with lines-containing(
                       $slurped, $needle, :$i, :$m, :p, :$max-count,
                       :$offset, :$invert-match, :$count-only,
                     ) -> \result {
                         $io => ($count-only ?? result !! result.Slip)
                           if result.elems;
                     }
                 }
             }
}

my sub EXPORT() {
    BEGIN Map.new:
      '&paths'            => &paths,
      '&lines-containing' => &lines-containing,
      '&files-containing' => &files-containing,
      '&hyperize'         => &hyperize,
}

=begin pod

=head1 NAME

Files-Containing - Search for strings in files

=head1 SYNOPSIS

=begin code :lang<raku>

use Files-Containing;

.say for files-containing("foo", :files-only)

for files-containing("foo") {
    say .key.relative;
    for .value {
        say .key ~ ': ' ~ .value;  # linenr: line
    }
}

for files-containing("foo", :count-only) {
    say .key.relative ~ ': ' ~  .value;
}

=end code

=head1 DESCRIPTION

Files-Containing exports a single subroutine C<files-containing> which
produces a list of files and/or locations in those files given a certain
path specification and needle.

=head1 EXPORTED SUBROUTINES

=head2 files-containing

The C<files-containing> subroutine returns either a list of filenames
(when the C<:files-only> named argument is specified) or a list of pairs,
of which the key is the filename, and the value is a list of pairs, in
which the key is the linenumber and the value is the line in which the
needle was found.

=head1 RE-EXPORTED SUBROUTINES

=head1 hyperize

As provided by the C<hyperize> module that is used by this module.

=head1 lines-containing

As provided by the C<Lines::Containing> module that is used by this module.

=head1 paths

As provided by the C<paths> module that is used by this module.

=head3 Positional Arguments

=head4 needle

The first positional argument is the needle to search for.  This can either
be a C<Str>, a C<Regex> or a C<Callable>.  See the documentation of the
L<Lines::Containing|https://raku.land/zef:lizmat/Lines::Containing> module
for the exact semantics of each possible needle.

=head4 files or directory

The second positional argument is optional.  If not specified, or specified
with an undefined value, then it will assume to search from the current
directory.

It can be specified with a list of files to be searched.  Or it can be a
scalar value indicating the directory that should be searched for recursively.
If it is a scalar value and it is an existing file, then only that file will
be searched.

=head3 Named Arguments

=head4 :batch

The C<:batch> named argument to be passed to the hypering logic for
parallel searching.  It determines the number of files that will be
processed per thread at a time.  Defaults to whatever the default of
C<hyper> is.

=head4 :count-only

The C<count-only> named argument to be passed to the
C<lines-containing|https://raku.land/zef:lizmat/lines-containing>
subroutine, which will only return a count of matched lines if
specified with a C<True> value.  C<False> by default.

=head4 :degree

The C<:degree> named argument to be passed to the hypering logic for
parallel searching.  It determines the maximum number of threads that
will be used to do the processing.  Defaults to whatever the default of
C<hyper> is.

=head4 :dir

The C<:dir> named argument to be passed to the
L<paths|https://raku.land/zef:lizmat/paths> subroutine.  By default will
look in all directories, except the ones that start with a period.

Ignored if a list of files was specified as the second positional argument.

=head4 :extensions

The C<:extensions> named argument indicates the extensions of the files that
should be searched.

Ignored if a C<:file> named argument was specified.  Defaults to all
extensions.

=head4 :file

The C<:file> named argument to be passed to the
L<paths|https://raku.land/zef:lizmat/paths> subroutine.  Ignored if a list
of files was specified as the second positional argument.

=head4 :files-only

The C<:files-only> named argument determines whether only the filename
should be returned, rather than a list of pairs, in which the key is the
filename, and the value is a list of filenumber / line pairs.

=head4 :follow-symlinks

The C<:follow-symlinks> named argument to be passed to the
L<paths|https://raku.land/zef:lizmat/paths> subroutine.  Ignored if a list
of files was specified as the second positional argument.

=head4 :i or :ignorecase

The C<:i> (or C<:ignorecase>) named argument indicates whether searches
should be done without regard to case.  Ignored if the needle is B<not>
a C<Str>.

=head4 :include-dot-files

The C<:include-dot-files> named argument is a boolean indicating whether
filenames that start with a period should be included.

Ignored if a C<:file> named argument was specified.  Defaults to C<False>,
indicating to B<not> include filenames that start with a period.

=head4 :invert-match

The C<:invert-match> named argument is a boolean indicating whether to
produce files / lines that did B<NOT> match (if a true value is specified).
Default is C<False>, so that only matching files / lines will be produced.

=head4 :m or :ignoremark

The C<:m> (or C<:ignoremark>) named argument indicates whether searches
should be done by only looking at the base characters, without regard to
any additional accents.  Ignored if the needle is B<not> a C<Str>.

=head4 :max-count

The C<:max-count> named argument indicates the maximum number of lines
that should be reported per file.  Defaults to C<Any>, indicating that
all possible lines will be produced.  Ignored if C<:files-only> is specified
with a true value.

=head4 :offset

The C<:offset> named argument indicates the value of the first line number
in a file.  It defaults to B<0>.  Ignored if the C<:files-only> named argument
has been specified with a true value.

=head4 :sort

The C<:sort> named argument indicates whether the list of files obtained
from the L<paths|https://raku.land/zef:lizmat/paths> subroutine should be
sorted.  Ignored if a list of files was specified as the second positional
argument.  Can either be a C<Bool>, or a C<Callable> to be used by the
sort routine to sort.

=head2 paths

The C<paths> subroutine, as provided by the version of
L<paths|https://raku.land/zef:lizmat/paths> that is used.

=head2 lines-containing

The C<lines-containing> subroutine, as provided by the version of
L<lines-containing|https://raku.land/zef:lizmat/Lines::Containing> that
is used.

=head1 AUTHOR

Elizabeth Mattijsen <liz@raku.rocks>

Source can be located at: https://github.com/lizmat/Files-Containing .
Comments and Pull Requests are welcome.

If you like this module, or what I’m doing more generally, committing to a
L<small sponsorship|https://github.com/sponsors/lizmat/>  would mean a great
deal to me!

=head1 COPYRIGHT AND LICENSE

Copyright 2022 Elizabeth Mattijsen

This library is free software; you can redistribute it and/or modify it under the Artistic License 2.0.

=end pod

# vim: expandtab shiftwidth=4
