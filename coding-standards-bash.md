# CyVerse Coding Standards for Bash

This document provides coding standards for developing Bash scripts.

## Table of Contents

[Introduction](#introduction)  
[Clarity, the Most Important Standard](#clarity-the-most-important-standard)  
[File Extensions](#file-extensions)  
[SUID/SGID](#suidsgid)  
[stdout vs. stderr](#stdout-vs-stderr)  
[Comments](#comments)  
[Formatting](#formatting)  
[Feature Usage](#feature-usage)  
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
logic, the obfuscating standard should not be followed._

## File Extensions

An executable Bash script should not have an extension. A Bash file acting as a library for other
Bash files should have the customary `.sh` extension. This makes it easy to differentiate between
libraries and scripts.

## SUID/SGID

SUID and SGID are not allowed in Bash scripts for security reasons. `sudo` or `gosu` should be used
instead.

## stdout vs. stderr

Scripts should always write error and warning messages to stderr. Typically, they should write
informational messages, like ones about progress, to stdout. The exception is scripts meant to be
part of a data processing pipeline, i.e., those that write data to stdout so that other scripts
can read the data from their stdin through a pipe, `|`. These scripts should write informational
messages to stderr.

## Comments

All comments should have enough detail so that the someone can learn how to use what is being
described without having to study the code in detail. However, since an incorrect comment is usually
worse than no comment, comments should be minimal to reduce the risk of them growing out of date. If
a quick glace at the code being documented is enough to understand an aspect of the code, that aspect
should not be documented.

### File Header

Every file must start with an overview of its contents. Ordinarily, this should be in the form of a
comment block. For executables that can display help information, a function that generates the help
text may be placed at the top of the script instead. For consistency's sake, this function should be
named `help`.  The header doesn't need author and maintainer information.

For a publicly available file, the header must include a copyright notice and a link to the CyVerse
license, https://cyverse.org/license. This isn't necessary if the file is in a repository that
includes a license file.

For an executable, the header should describe possible command line arguments as well as any
environment variables used. If the executable reads stdin, the header should describe what the
executable expects to read. If it writes anything other than informational messages to stdout, the
header should describe the output. If the executable writes anything to stderr other than
informational, warning, and error messages, the header should describe this output as well. If there
is any side effects that isn't obvious, the header should document this too. Finally, if the script
uses different exit statuses for different types of failures, the header should describe them. If
standard zero for success and non-zero for failure, the header need not document this.

__TODO review the following in a browser__

The formatting used in the following header examples is not required. Only the content is the
important.

Here's an example header comment for a published file.

```bash
#!/bin/bash
#
# check_irods version 2
#
# Usage:
#  check_irods [options] HOST
#
# Checks to see is if an iRODS service is online. It is ...
#
# Parameters:
#  HOST  The FQDN or IP address of the server hosting the
#        service
#
# Options:
#  -h, --help       show help and exit
#  -P, --port PORT  the TCP port the iRODS server listens to on
#                   HOST (default 1247)
#  ...
#
# Environment Variables:
#  PGHOST  the FQDN or IP address of the DBMS hosting the ICAT
#          DB
#
# Input:
#  It expects to read the output of `repl` from stdin.
#
# Output:
#  Unless otherwise indicated, it writes the status of the iRODS
#  service on HOST to stdout in a form understood by nagios.
#
#  It writes progress messages to stderr.
#
# Side Effects:
#  The rodsLog on HOST will show a connection from the host ...
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

Checks to see is if an iRODS service is online. It is ...

Parameters:
 HOST  the FQDN or IP address of the server hosting the
       service

Options:
 -h, --help       show help and exit
 -P, --port PORT  the TCP port the iRODS server listens to on
                  HOST (default 1247)
 ...

Environment Variables:
 PGHOST  the FQDN or IP address of the DBMS hosting the ICAT
         DB

Input:
 It expects to read the output of \`repl\` from stdin.

Output:
 Unless otherwise indicated, it writes the status of the
 iRODS service on HOST to stdout in form interpretable by
 nagios.

 It writes progress messages to stderr.

Side Effects:
 The rodsLog on HOST will show a connection from the ...

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

Any function whose purpose isn't obvious or is part of a library should be documented with a
comment immediately preceeding it's definition. A function comment should describe its function's
behavior and not its implementation. In addition to its purpose, the following should be described.

* any global or exported variables read or modified
* usage of stdin, stdout, and stderr
* any special return statuses other than zero for success and the default non-zero for failure

```bash
# Decodes a serialized iRODS protocol packet header length
# Input:
#  the serialized length
# Output:
#  the decimal value to stdout.
decode_header_len() {
	...
}
```

### Implementation Comments

The implementation should be self documenting as much as reasonably possible. Implementation
comments can reduce the understandability. When reading code, a comment causes a mental context
switch, interrupting the reader. All comments run the risk of become out of date. A comment that is
inconsistent with the code is worse than useless. With this said, sometimes the implementation is
non-obvious, and a short, explanatory comment should be provided immediately before this code.

## Formatting

New files should use the following style guidelines. When modifying existing files, the existing
style should be used. As a separate, refactoring task, an existing file's style can be adapted to
meet the following guidelines.

### Indentation

The primary purpose of indentation is readability. To make it easier for the visually impaired who
use code readers to understand the layout of the file, use tabs for indentation. A study has shown
that a tab length of 2-4 characters provides optimal readability. See ["Program Indentation and
Comprehensibility" by Miaria et. al, Communications of the ACM 26, (Nov. 1983)
p.861-867](https://www.cs.umd.edu/~ben/papers/Miara1983Program.pdf).

Separate blocks with blank lines to improve readability.

### Line Length

There is no mandated maximum line length. The length of each line should be governed by readability.
The optimal line length is considered to be 50-60 characters. See "Typographie" by E. Ruder. This is
not an absolute length, but a relative length measured from the first character after indentation.

```bash
# This is a 60 character line. This is a 60 character line.
			# This is a 60 character line. This is a 60 character line.
```

### Pipelines and Other Chained Expressions

If a pipeline fits on a single line, it should be on one. Otherwise, it should be split with each
pipe segement being on its own line with all but the first line being indented and beginning with
the `|` operator.

The same policy applies to outher chained expressions like logical compounds using `||` and `&&`.

```bash
od --address-radix n --read-bytes 4 | tr --delete ' '

"$ExecDir"/gather-logs --password "$password" "$ies" \
	| filter_msgs \
	| tee >(mk_downloads > downloads) >(mk_uploads > uploads)

```

### Conditionals and Loops

For conditionals and loops, put the `; then` and `; do` on the same line as the corresponding `if`,
`elif`, `for`, `until`, or `while`. The ending `fi` and `done` should be on their own line with the
same level of indentation as the corresponding `then` or `done`. This makes them conditionals and
loops consistent with `case` statements.

```bash
if [[ "$resp" =~ size\.$ ]]; then
	reason=size
elif [[ "$resp" =~ checksum\.$ ]]; then
	reason=checksum
else
	...
fi

while true; do
	...
done

for size in ${sizes//,/ }; do
	...
done | gen_report > "$ReportLog"

```

### Case Statement

For case statements, `esac` should have the same level of indentation as `case`. Each alternative
should be indented one additional level. The pattern should be on its own line, and the action logic
should be indented one more level. The action terminator, `;;`, `;&`, or `;;&` should be placed on
its own line.

```bash
case "$1" in
	-h|--help)
		help
		exit 0
		;;
	-P|--port)
		...
		;;
	...
	*)
		help >&2
		exit 1
		;;
esac
```

### Variable Expansion

All variables storing non-integer values should be quoted when expanded. Also during expansion, the
variable name shouldn't be brace-delimited unless necessary or to avoid confusion.

```bash
# Preferred style for ordinary variables
readonly ExecName="$(basename "$ExecAbsPath")"

# Preferred style for special variables
echo Positional: "$1" ... "${10}" ...
echo Special: "$0" $# "$*" "$@" "$_" "$-" $? $$ $!

# Brace-delimiting required
header="$(mk_header "$msgType" ${#msg})"

# Brace-delimited to avoid confusion
set -- a b
echo "${1}0${2}"
# Outputs "a0b"
```

### Quoting

Variables that haven't been declared as integer type and command substitutions should be quoted
unless unquoted expansion is required.

Literal integers should not be quoted.

```bash
readonly ExecAbsPath="$(readlink --canonicalize "$0")"
readonly Version=2

if [[ $# -lt 1 ]]; then
	exit_with_help
fi
```

### Functions

For any non-trivial script, it is preferred to decompose the logic into functions. This allows
for variables to be localized to the body of a function, making debugging easier.

To be consistent with `case` statements, the `{` should be placed on the same line as the
declaration, while the `}` should be placed on its own line with the same level of indentation as
the declaration.

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

If an executable has at least one other function, an entry point function that encapsulates the
remaining logic excluding includes, `set` statements, and environment variable and constant
declarations is required. This makes the start of the program easy to find allows more variables to
be made local.

This function should be named `main` and should take the command line arguments as its own. Since
the executable's header or `help` function describes the script, `main` should not have its own
comment.

The last non-comment line in the file should be a call to `main`.

``bash
main "$@"
```

### Use Local Variables

A function-specific variable should be declared using `local` to this restricts the variable to the
name space fo the function and its children, avoiding inadertently overriding the value of variable
with the same name used elsewhere.

Since `local` doesn't propagate the exit code from a command substitution, assignment of the output
of an command substitution should be in a separate statement from the variable's declaration.  

```bash
# ...
map_args() {
	local mapVar="$1"
	shift

	local opts
	if ! opts="$(format_opts "$@")"; then
		return 1
	fi

	...
}
```

### Read-Only Variables

A global variables that is not intended to be modified after first assignment, should be made into a
constant using `readonly` or `declare -r`. This will catch important errors when working with them.

```bash
readonly EXEC_NAME="$(realpath --canonicalize-missing "$0")"
```

### Executable File Organization

If there is a `help` function, it should go at the top of the file just below the shebang line.
Below this should come any includes, `set` statements, and environmentvariable and constant
declarations. If the logic has been decomposed into functions, the functions other than `help`
should be come next, followed by the invocation of `main`.

```bash
#!/bin/bash

help() {
	...
}


set -o errexit -o nounset -o pipefail

source library.sh

declare -r -x IRODS_SVC_ACNT=irods

export PGUSER

readonly DEFAULT_PORT=1247


main() {
	...
}



# ...
map_args() {
	local mapVar="$1"

	...
}


main "$@"

```

## Feature Usage

This section makes recommendations on bash feature usage.

### Command Substitution

Use `$(...)` instead of `` `...` `` for command substitution. The `$(...)` form can be nested
without escaping, so it is easier to read.

```bash
# This is preferred
ExecName="$(basename "$(realpath -m "$0")")"

# This is not
ExecName="`basename \"\`readpath -m \\\"$0\\\"\`\"`"
```

### `test`, `[ ... ]`, `[[ ... ]]`, and `((...))`

Use `[[ ... ]]` for testing conditions instead of `test` or `[ ... ]`, because it can prevent many
logic errors. `[[ ... ]]` doesn't perform filename expansion or word splitting, and the `&&`, `||`,
`<`, and `>` operators can be used without having to be escaped.

```bash
# This performs pattern matching of filename versus f*, so it would write "Match" to stdout.
if [[ filename == f* ]]; then
  echo Match
fi

# This would like generate an error, since f* is expanded within the contents of the current
# directory.
if [ filename == f* ]; then
	echo Match
fi
```

It is recommended to use `((...))` to test numerical conditions. The operators `<`, `<=`, `==`,
`>=`, and `>` are more readable than the operators `-lt`, `-le`, `-eq`, `-ge`, and `-gt` that would
be used in the other test constructs. Also, the `((...))` handles variable expansion, so the `$`
operator isn't needed.

```bash
if ((a > b)); then
	echo greater than
fi

if [[ "$a" -gt "$b" ]]; then
	echo greater than
fi
```

### Testing Strings

To make code easier to read by making it explicit what is being tested, use the `-z` test for
checking if a string is empty, and use the `-n` test for checking if a string is non-empty.

```bash
# Do this
if [[ -z "$var" ]]; then
	echo Empty
fi

# not this
if [[ "$var" == '' ]]; then
	echo Empty
fi
```

To avoid accidental assignment, use `==` instead of `=` for testing equality.

### Wildcard Expansion of Filenames

Since file names may begin with a `-`, use an explicit path when doing wildcard expansions of them.
This avoids the risk of having a name being interpretted as a flag. It's safer to expand wildcards
of the form `./*` than `*`.

In the following examples, assume the contents of the currect directory are as follows.

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

Using `rm -v ./*` would correctly delete the files `-r` and `some-file`, leaving the directory
`SomeDirectory` alone.

```bash
prompt> rm -v ./*
removed './-r'
rm: cannot remove './SomeDirectory': Is a directory
removed './some-file'
prompt> ls
SomeDirectory
```

### Eval

`eval` is dangerous and should usually be avoided. It obfiscates the code. In some situations, it
makes it impossible to trap run-time errors.

```bash
# What happens if `func` writes a value to stdout with a
# space in it?
var="$(eval func)"
```

### Arrays

An array should be used to store a list of elements to avoid quoting complications like nesting. Do
not use them to implement more complex data structures. Instead, consider using another scripting
language such as awk or python.

### Iterating over Command Output

Use `readarray` plus a `for` loop instead of a `while` to iterate over the output of a command. This
makes the flow of the script text reflect the flow of the execution, improving understandability.

In this example, the flow of the source code has the output of `get_resources` being iterated over
before the command is called. The reader of the code needs to go to the bottom of the loop to see
what is being iterated over. For all but the smallest while loops this is disruptive to the reader.

```bash
while read -r resc; do
	...
done < <(get_resources "$srcColl")
```

In this example, the flow of the code has `get_resources` called before its output is iterated over,
so the reader doesn't need to go to the bottom of the loop to know what is being interated over.

```bash
readarray -t resources < <(get_resources "$srcColl")
for resc in "${resources[@]}"; do
  ...
done
```

### Arithmetic

Use `((...))` or `$((...))` instead of `expr`, `let`, or `$[...]` when doing arthimetic.

Since `expr` is a utility program instead of a shell builtin, quoting can be error prone.

```bash
prompt> echo "$(expr 2 * 3)"
expr: syntax error: unexpected argument ‘bin’
prompt> echo "$(expr '2 * 3')"
2 * 3
prompt> echo "$(expr 2 '*' 3)"
6
prompt> echo $((2 * 3))
6
```

Also, `expr` is takes many times longer to execute than the shell's builtin arithmetic.

`let` isn't a declarative keyword in bash, so assignments must be quoted to avoid globbing and word
splitting. It is simpler to avoid using `let`.

```bash
prompt> let var=2 * 3
bash: let: examples.desktop: syntax error: invalid arithmetic operator (error token is ".desktop")
prompt> let var=2*3
prompt> var=$((2 * 3))
```

The form `$[...]` is deprecated and isn't portable.

Avoid using standalone `((...))`` statements. In bash, any arithmetic expression that evaluates to
`0` has an exit status of `1`. If exit on error is enable, e.g., `set -o errexit`, then standalone
`((...))` statements risk causing a script to abruptly exit.

```bash
set -o errexit

cnt=0

while ((cnt < 10)); do
	# Since cnt is 0 on the first pass through the while loop,
	# the next statement's exit code is 1, causing the shell script to exit.
	((cnt++))

	echo "$cnt"
done
```

The `$((...))` and `((...))` automatically expand variables, so the the `$` operator isn't required.
It is recommended to omit the `$` operator to improve readability.

## Naming Conventions

This section describes the conventions that should be followed when naming source files, functions,
constants, and variables.

### Constant and Variable Names

The name of a constant or environmental variable should be upper case with each pair of adjacent
words separated by an underscore (`_`). The name of any other variable should be camel case with a
global having the first letter upper case and a local having the first letter lower case.

```bash
# constant
readonly A_CONST=const

# environment variable
export ENV_VAR

# environment constant
declare -r -x ENV_CONST=env-const

# global variable
declare GlobalVar


# ...
main() {
	# local variable
	local localVar
}
```

### Function Names

For a function that is local to an executable script, use lower case with each pair of adjacent
words separated by an underscore (`_`).

```bash
#!/bin/bash
#
# a program that demonstrates how to name a local function

...


# ...
map_args() {
	...
}


...
```

For a function that is part of library, its name should begin the library name followed by a `::`
and a descriptive name. If the library nested within another library, both library names should be
part of the function name with the library names being separated by a `::`. The library and
descriptive names should be lower case with each pair of adjacent words separated by an `_`.

```bash
# a nested library that demonstrations how to name a
# function that is meant to be included in a program


# ...
chunk_transfer::chunk::get_resources() {
	...
}
```

For a function that is exported, its name should be all upper case.

```bash
#!/bin/bash

# ...
FIX_FILE_SIZE() {
	...
}
export -f FIX_FILE_SIZE


parallel --eta --no-notice --delimiter '\n' FIX_FILE_SIZE
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
	...
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
common bugs and weaknesses in bash scripts. It is recommended to check all scripts with this
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
