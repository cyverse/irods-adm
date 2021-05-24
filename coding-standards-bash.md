# CyVerse Coding Standards for Bash

This document provides coding standards for developing Bash scripts.

## Table of Contents

[Introduction](#introduction)  
[Clarity, the Most Important Standard](#clarity-the-most-important-standard)  
[File Extensions](#file-extensions)  
[SUID/SGID](#suidsgid)  
[stdout vs. stderr](#stdout-vs-stderr)  
[Comments](#comments)  
[Feature Usage](#feature-usage)  
[Formatting](#formatting)  
[Naming Conventions](#naming-conventions)  
[Builtin vs. External Commands](#builtin-vs-external-commands)  
[ShellCheck](#shellcheck)  
[Conclusion](#conclusion)  
[Acknowledgement](#acknowledgement)

## Introduction

Along with allowing maintainers to concentrate on the meaning of coding, following a coding standard
improves a developer's ability to estimate the amount of effort a script will take create. Code
changes involving similar numbers of lines will likely take similar effort. This enables a developer
to use logical LOC (lines of code) counts of past scripts to estimate the amount of time it will
take to create a new script.

## Clarity, the Most Important Standard

Besides correctness, the most important standard is clarity when writing code. The code should be as
easy to understand as reasonably possible. _If following any of the other standards obfuscates the
logic, don't follow the obfuscating standard._

## File Extensions

An executable Bash script should not have an extension. A Bash file acting as a library for other
Bash files should have the customary `.sh` extension. This makes it easy to differentiate between
libraries and scripts.

## SUID/SGID

SUID and SGID are not allowed in Bash scripts for security reasons. Use `sudo` or `gosu` instead.

## stdout vs. stderr

Scripts should always write error and warning messages to stderr. Typically, they should write
informational messages, like ones about progress, to stdout. The exception is scripts meant to be
part of a data processing pipeline, i.e., those that write data to stdout so that other scripts
can read the data from their stdin through a pipe, `|`. These scripts should write informational
messages to stderr.

## Comments

All comments should have enough detail so that the someone can learn how to use the described logic
without having to study it in detail. Since an incorrect comment is usually worse than no comment,
comments should be minimal to reduce the risk of them growing out of date. If a quick glace at the
code is enough to understand an aspect of it, don't comment on that aspect.

### File Header

Every file must start with an overview of its contents. Ordinarily, this should be in the form of a
comment block. For an executable that can display help information, you may place a function that
generates command line help text at the top of the script instead. For consistency's sake, name this
function `help`.

The header doesn't need author and maintainer information.

For a publicly available file, the header must include a copyright notice and a link to the CyVerse
license, https://cyverse.org/license. This isn't necessary if the file is in a repository that
includes a license file.

For an executable, the header should describe possible command line arguments as well as any
environment variables used. If the executable reads from stdin, the header should describe what the
executable expects to read. If it writes anything other than informational messages to stdout, the
header should describe the output. If the executable writes anything to stderr other than
informational, warning, and error messages, the header should describe this output as well. If there
is any side effects that aren't obvious, the header should document this too. Finally, if the script
uses different exit statuses for different types of failures, the header should describe them. It
should not document the standard zero for success and non-zero for failure.

The formatting used in the following header examples is not required. The content is the important
part.

Here's an example header comment for a published file.

```bash
#!/bin/bash
#
# check_irods version 2
#
# Usage:
#  check_irods [options] HOST
#
# Nagios plugin that checks to see is if an iRODS server is
# online. It supports Nagios version 2 or later and iRODS
# version 4 or later.
#
# Parameters:
#  HOST  The FQDN or IP address of the server hosting the
#        service
#
# Options:
#  -h, --help             show help and exit
#  -S, --service SERVICE  the name of the service checking
#                         iRODS, identified as client user
#                         to iRODS
#  ...
#
# Environment Variables:
#  PGHOST  the FQDN or IP address of the DBMS hosting the
#          ICAT DB
#
# Input:
#  It expects to read the output of `repl` from stdin.
#
# Output:
#  Unless otherwise indicated, it writes the status of the
#  iRODS service running on HOST to stdout in a form
#  understood by Nagios.
#
#  It writes progress messages to stderr.
#
# Side Effects:
#  The rodsLog on HOST will show a connection from the host
#  running check_irods with the proxy user set to
#  "check_irods". If the call specifies SERVICE, check_irods
#  will set the client to SERVICE.
#
# Exit Status:
#  0  connected to iRODS
#  1  failed to connect to anything
#  2  connected to something other than iRODS
#
# © 2019, The Arizona Board of Regents on behalf of The
# University of Arizona. For license information, see
# https://cyverse.org/license.
```

Here's an alternate example where a help function provides the file header information.

```bash
#!/bin/bash

help() {
	cat <<EOF
$EXEC_NAME version $VERSION

Usage:
 $EXEC_NAME [options] HOST

Nagios plugin that checks to see is if an iRODS server is
online. It supports Nagios version 2 or later and iRODS
version 4 or later.

Parameters:
 HOST  the FQDN or IP address of the server hosting the
       service

Options:
 -h, --help             show help and exit
 -S, --service SERVICE  the name of the service checking
                        iRODS, identified as client user to
                        iRODS
 ...

Environment Variables:
 PGHOST  the FQDN or IP address of the DBMS hosting the ICAT
         DB

Input:
 It expects to read the output of \`repl\` from stdin.

Output:
 Unless otherwise indicated, it writes the status of the
 iRODS service running on HOST to stdout in form understood
 by Nagios.

 It writes progress messages to stderr.

Side Effects:
 The rodsLog on HOST will show a connection from the host
 running $EXEC_NAME with the proxy user set to "$EXEC_NAME".
 If the call specifies SERVICE, $EXEC_NAME will set the
 client user to SERVICE.

Exit Status:
 0  connected to iRODS
 1  failed to connect to anything
 2  connected to something other than iRODS

© 2019, The Arizona Board of Regents on behalf of The
University of Arizona. For license information, see
https://cyverse.org/license.
EOF
}
```

### Function Comments

Any function that is part of a library or whose purpose isn't obvious should have a leading comment
describing it. A function comment should describe its interface and behavior, not its
implementation. It should include the following.

* any arguments passed in
* any global or exported variables read or modified
* usage of stdin
* usage of stdout for something other than informational messages
* usage of stderr for something other than informational, warning, and error messages
* any special return statuses other than zero for success and non-zero for failure

```bash
# Decodes a serialized iRODS protocol packet header length
# Input:
#  the serialized length
# Output:
#  the decimal value to stdout.
decode_header_len() {
	# ...
}
```

### Implementation Comments

The implementation should be self documenting as much as reasonably possible. Implementation
comments can reduce understandability. When reading code, a comment causes a mental context
switch, interrupting the reader. Also, comments run the risk of become out of date as the code
evolves. A comment that is inconsistent with the code is worse than useless. With this said,
sometimes the implementation is not obvious, and a short, explanatory comment should precede the
difficult section of code.

## Feature Usage

This section makes recommendations on Bash feature usage.

### Local Variables

Declare a function-specific variable using `local`. This restricts the variable to the namespace of
the function and the functions it calls. This helps avoid overriding the value of a variable with
the same name used elsewhere.

Since `local` doesn't propagate the exit code from a command substitution, assignment of the output
of a command substitution should be in a separate statement from the variable's declaration.  

```bash
# ...
map_args() {
	local mapVar="$1"
	shift

	local opts
	if ! opts="$(format_opts "$@")"; then
		return 1
	fi

	# ...
}
```

### Read-Only Variables

If a global variable should not modified after first assignment, declare it using `readonly` or
`declare -r`. This will help prevent certain hard to catch errors.

```bash
readonly EXEC_NAME="$(realpath --canonicalize-missing "$0")"
```

### Command Substitution

Use `$( )` instead of `` ` ` `` for command substitution. You can nest the `$( )` form without
escaping it, making the code easier to read.

```bash
# preferred
ExecName="$(basename "$(realpath -m "$0")")"

# not preferred
ExecName="`basename \"\`readpath -m \\\"$0\\\"\`\"`"
```

### Arithmetic

Use `(( ))` or `$(( ))` instead of `expr`, `let`, or `$[ ]` when doing arithmetic.

Since `expr` is a utility program instead of a shell builtin, quoting can be error prone. Also, it
takes a lot longer to execute than the shell's builtin arithmetic.

```bash
prompt> echo $(expr 2 * 3)
expr: syntax error: unexpected argument ‘bin’
prompt> echo $(expr '2 * 3')
2 * 3
prompt> echo $(expr 2 \* 3)
6
prompt> echo $(( 2 * 3 ))
6
prompt> time echo $(expr 2 \* 3)
6

real	0m0.004s
user	0m0.004s
sys	0m0.000s

prompt> time echo $(( 2 * 3 ))
6

real	0m0.000s
user	0m0.000s
sys	0m0.000s
```

`let` isn't a declarative keyword in Bash, so you must take special care to avoid globbing and word
splitting.

```bash
prompt> let var=2 * 3
bash: let: examples.desktop: syntax error: invalid arithmetic operator (error token is ".desktop")
prompt> let var=2*3
prompt> var=$(( 2 * 3 ))
```

The Bash standard has deprecated the form `$[ ]`.

The forms `$(( ))` and `(( ))` automatically expand variables, so the `$` operator isn't required
inside. This standard recommends omitting the `$` operator to improve readability.

```bash
echo $(( $shrlCnt + $ssrCnt ))  # not recommended
# The `$` operator isn't needed to expand `shrlCnt` or
# `ssrCnt`, so you could write the above statement as the
# following one.
echo $(( shrlCnt + ssrCnt ))  # recommended
```

Avoid using standalone `(( ))` statements. In Bash, any arithmetic expression that evaluates to `0`
has an exit status of `1`. If the script enables exit on error, e.g., `set -o errexit`, then
standalone `(( ))` statements risk causing a script to exit prematurely.

```bash
set -o errexit

cnt=0
while (( cnt < 10 )); do
	# Since cnt is 0 on the first pass through the while loop,
	# the next statement's exit code is 1, causing the shell
	# script to exit. Using `$(( cnt++ ))` would have prevented
	# this.
	(( cnt++ ))
	echo "$cnt"
done
```

### Testing Conditions, `test`, `[ ]`, `[[ ]]`, and `(( ))`

Use `[[ ]]` for testing conditions instead of `test` or `[ ]`, because it can prevent certain types
of logic errors. `[[ ]]` doesn't perform filename expansion or word splitting, and you don't have to
escape the `&&`, `||`, `<`, and `>` operators.

```bash
# This performs pattern matching of filename based on f*, so
# it would write "Match" to stdout.
if [[ filename == f* ]]; then
	echo Match
fi

# This would likely generate an error, since Bash expands f*
# within the context of the current directory.
if [ filename == f* ]; then
	echo Match
fi
```

This standard recommends using `(( ))` to test numeric conditions. The operators `<`, `<=`, `==`,
`>=`, and `>` are the common operators for numeric comparisons in other languages, so their intent
is easier to understand for beginning Bash users than the operators `-lt`, `-le`, `-eq`, `-ge`, and
`-gt` required by the other test constructs. As mentioned before, `(( ))` handles variable
expansion, so the `$` operator isn't needed.

```bash
if [[ "$a" -gt "$b" ]]; then
	echo greater than
fi

if (( a > b )); then
	echo greater than
fi
```

### Testing Strings

To avoid accidental assignment, use `==` instead of `=` for testing equality.

This standard suggests using the `-z` operator for checking if a string is empty and `-n` for
checking if a string is non-empty. This makes it slightly more clear what the code is testing.

```bash
if [[ "$var" == '' ]]; then
	echo Empty
fi

if [[ -z "$var" ]]; then
	echo Empty
fi
```

### Wildcard Expansion of Filenames

Since file names may begin with a `-`, use an explicit path when doing wildcard expansions. This
avoids the risk of Bash interpreting a name as a flag. It's safer to expand wildcards of the form
`./*` than `*`.

In the following examples, assume the contents of the current directory are as follows.

```bash
prompt> ls
-r  SomeDirectory  some-file
```

Using `rm -v *` would incorrectly delete the directory `SomeDirectory` leaving the file `-r` alone.

```bash
prompt> rm -v *
removed directory 'SomeDirectory'
removed 'some-file'
prompt> ls
-r
```

Using `rm -v ./*` would delete the files `-r` and `some-file`, leaving the directory `SomeDirectory`
alone.

```bash
prompt> rm -v ./*
removed './-r'
rm: cannot remove './SomeDirectory': Is a directory
removed './some-file'
prompt> ls
SomeDirectory
```

### `eval`

`eval` is dangerous, so you should generally avoid using it. It obfuscates the code, and in some
situations, it makes trapping run-time errors impossible.

```bash
# What happens if `func` writes a value to stdout with a
# space in it?
var="$(eval func)"
```

### Arrays

Use a Bash array for an array or list of integers or strings, and use an associative array for a map
of strings to integers or strings, but do not use either of them to mimic more complex data
structures. Instead consider using another scripting language such as Awk or Python.

### Iterating over Command Output

Use `readarray` plus a `for` loop instead of an `until` or `while` loop to iterate over the output
of a command. This makes the flow of the script reflect the flow of its execution, improving its
understandability.

In this example, the flow of the script shows an iteration. When the reader scans to the bottom,
they learn the iteration is over the output of `get_resources`. For all but the smallest `until` and
`while` loops, this delay is disruptive to the reader.

```bash
while read -r resc; do
	# ...
done < <(get_resources "$srcColl")
```

In this example, the flow of the code has `get_resources` called before the iteration, so the reader
doesn't need to go to the bottom of the loop to understand the logic.

```bash
readarray -t resources < <(get_resources "$srcColl")

for resc in "${resources[@]}"; do
  # ...
done
```

## Formatting

A developer should use the following formatting guidelines when creating a new source file. When
modifying an existing one, the developer should follow the file's current style. If the file has
poor style, the developer could adapt its style as a separate, refactoring task.

### Whitespace Usage

The primary purpose of indentation is readability. To make it easier for the visually impaired (who
often use code readers) to understand the logic, a developer should use tabs for indentation. This
standard does not specify the length of tab. However, a study has shown that a tab length of 2 - 4
characters provides optimal readability. See ["Program Indentation and Comprehensibility" by Miaria
et. al, Communications of the ACM 26, (Nov. 1983)
p.861-867](https://www.cs.umd.edu/~ben/papers/Miara1983Program.pdf).

A developer should use blank lines to separate code blocks. This will also improve readability.

### Line Length

This standard doe not mandate a maximum line length. Readability should govern the length of each
line. One study shows that the optimal line length is 50 - 60 characters. This is not an absolute
length, but a relative length measured from the first character after indentation. See "Typographie"
by E. Ruder.

```bash
# This is a 60 character line. This is a 60 character line.
		# This is a 60 character line. This is a 60 character line.
```

### Pipelines and Other Chained Expressions

If a pipeline fits on a single line, it should be on one. Otherwise, it should split before each `|`
operator with each segment being on its own line and with all but the first line indented. The same
recommendation applies to other chained expressions like a logical compound using `||` or `&&`
operators.

```bash
od --address-radix n --read-bytes 4 | tr --delete ' '

"$EXEC_DIR"/gather-logs --password "$password" "$ies" \
	| filter_msgs \
	| tee >(mk_downloads > downloads) >(mk_uploads > uploads)

mv --no-clobber "$file" "$TmpFile" \
	&& touch "$file" \
	&& irsync -K -s -v -R "$resc" "$TmpFile" i:"$obj"
```

### Case Statement

For case statements, the terminator `esac` should have the same level of indentation as the
initiator `case`. The alternatives should have one more level of indentation. Within each
alternative, the pattern should be on its own line with the action logic further indented. The
action terminator, `;;`, `;&`, or `;;&`, should also be on its own line.

```bash
case "$1" in
	-h|--help)
		help
		exit 0
		;;
	-P|--port)
		# ...
		;;
	# ...
	*)
		# ...
		;;
esac
```

### Conditionals and Loops

For a conditional or loop, the block initiator `then` or `do` should be on the same line as the
corresponding condition initiator `if`, `elif`,`for`, `until`, or `while`. The condition initiator
`elif`, block initiator `else`, and the terminator `fi` or `done` should be on its own line with the
same level of indentation as the corresponding `fi`, `until`, or `while`. This makes conditionals
and loops consistent with `case` statements.

```bash
if [[ "$resp" =~ size\.$ ]]; then
	reason=size
elif [[ "$resp" =~ checksum\.$ ]]; then
	reason=checksum
else
	# ...
fi

while true; do
	# ...
done

for size in ${sizes//,/ }; do
	# ...
done | gen_report > "$ReportLog"
```

### Variable Expansion

Quote all non-integer variables when expanding. This prevents accidental word splitting. When the
variable name isn't obvious in an expression, delimit the variable in braces.

```bash
# Preferred style for ordinary variables
readonly EXEC_NAME="$(basename "$EXEC_ABS_PATH")"

# Preferred style for special variables
echo Positional: "$1" "$2" '...' "$9" "${10}" "${11}" '...'
echo Special: "$0" $# "$*" "$@" "$_" "$-" $? $$ $!

# Brace-delimiting required
header="$(mk_header "$msgType" ${#msg})"

# Brace-delimited to avoid confusion
set -- a b
echo "${1}0${2}"
# Outputs "a0b"
```

### Functions

For any non-trivial script, decompose the logic into functions. This allows for the localization of
a variable to the scope of a function, making debugging easier.

To be consistent with `case` statements, place the function body initiator `{` on the declaration
line and the terminator `}` on its own line with the same level of indentation as the declaration.

```bash
display_resp() {
	local verbose="$1"

	if [[ -n "$verbose" ]]; then
		cat
		printf '\n'
	fi
}
```

### `main` function

If an executable has at least one other function, the script should have an entry point function
that encapsulates the remaining logic excluding includes, `set` statements, and environment
variable and constant declarations. This makes the start of the program easy to find, and it allows
you to make more variables local.

This standard recommends naming this function `main`. This function should take the command line
arguments as its own. Since the executable's header or `help` function describes the script, `main`
should not have its own function comment.

The last non-comment line in the file should be a call to `main` with the command line arguments
passed in as separate values. This ensures that Bash knows about all function definitions before
entering `main`, allowing you to define the other functions in any order you desire.

```bash
main "$@"
```

### Executable File Organization

If there is a `help` function, it's definition should go at the top of the file below the shebang
line. Below this should come any includes, `set` statements, and environment variable and constant
declarations. If there is a `main` function, it should come next, followed by any remaining
functions and the invocation of `main` as the last non-comment statement at the bottom of the file.

```bash
#!/bin/bash

help() {
	# ...
}


set -o errexit -o nounset -o pipefail

source library.sh

export PGUSER

readonly DEFAULT_PORT=1247


main() {
	# ...
}


# ...
map_args() {
	# ...
}


main "$@"
```

## Naming Conventions

This section describes the recommended conventions for naming constants, variables, functions, and
source files.

### Constant and Variable Names

The name of a constant or environmental variable should be upper case with each pair of adjacent
words separated by an underscore (`_`). The name of any other variable should be camel case with a
global having the first letter upper case and a local having the first letter lower case.

```bash
# environment variable
export ENV_VAR

# constant
readonly A_CONST=const

# environment constant
declare -r -x ENV_CONST=env-const

# global variable
declare GlobalVar


main() {
	# local variable
	local localVar
}
```

### Function Names

__TODO review the following in a browser__

When naming a function, separate each pair of adjacent words with a underscore (`_`). An exported
function should have an all upper case name. Any other function name should be all lower case.

```bash
#!/bin/bash

# ...

# ...
map_args() {
	# ...
}


# ...
FIX_FILE_SIZE() {
	# ...
}
export -f FIX_FILE_SIZE

# ...
```

If a function is part of a library, use the library name to provide a namespace for the function by
beginning the function's name with the library name followed by two colons (`::`). Likewise, if the
library is part of a package, begin library's name with the package names followed by two colons,
and separate each pair of adjacent package names with two colons.

```bash
# a nested library that demonstrations how to name a
# function shared with other shell scripts.

# ...
package::inner_package::library::a_function() {
	# ...
}
```


### Source File Names

For an executable script, the file name should not have a file extension. It is suggested to use all
lower case as well. For a library, the file name should have the `.sh` or `.bash` extension. The
base name should be all lower case with an underscore (`_`) separating each pair of adjacent words.
This allows the library prefix on the functions defined within to be the same as the file name.

```bash
prompt> cat project_storage.sh
# ...

# ...
project_storage::report() {
	# ...
}
```

## Builtin vs. External Commands

It is preferred to use a shell builtin command or operation instead of an external command that
invokes a separate process. For example, builtin parameter expansion operations are more robust and
portable than `sed`.

```bash
# builtin
msgLen="${header#*<msgLen>}"
msgLen="${msgLen%%<*}"

# external
msgLen="$(sed 's/^.*<msgLen>\(.*\)<.*$/\1/' <<< "$header")"
```

## ShellCheck

The `shellcheck` program created by the [ShellCheck project](https://www.shellcheck.net) finds
common bugs and weaknesses in Bash scripts. It is recommended to check all scripts with this
program.

## Conclusion

The point of having a coding standard is to have a common vocabulary of coding, allowing maintainers
to concentrate on the meaning of the code rather than on how it is written. This document defines a
global vocabulary, but local standards are also important. If code newly added to a file looks
drastically different from the existing code around it, the discontinuity can throw readers out of
their rhythm when they read it. This should be avoided.

Before editing code, the style of the code should be understood. If spaces are used around
conditional clauses, any added clauses should have spaces around them too. If comments have little
boxes of stars around them, any added comments should too.

Other than focusing on clarity, these standards are merely recommendations, not requirements. It is
best to use common sense when chosing to violate a standard in a script, though inconsistently
following a standard can itself obfuscate the code.

## Acknowledgement

This standard is an adaptation of Google's
[Shell Style Guide](https://google.github.io/styleguide/shellguide.html).

<!-- vim: set tabstop=2: -->
