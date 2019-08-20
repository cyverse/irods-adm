# iRODS auto completions for the fish shell
#
# This script is derived from i-commands-auto.bash,
# https://github.com/irods/irods-legacy/blob/master/iRODS/irods_completion.bash,
# by Bruno Bzeznik.

# NOTE: USE /usr/share/fish/completions/*.fish as examples, especially scp.fish

# The commands in reverse order of popularity Implement completions in order of
# popularity, deferring the implementation of those marked with - to the end.
#
#   2837 ils
#   1322 iquest
# - 1065 iadmin
#    997 irm
#    948 icd
#    748 imeta
#    600 iput
#    561 ichmod
#    394 ips
#    352 iphymv
#    349 iget
#    300 isysmeta
#    289 ichksum
#    283 imv
#    273 ilsresc
#    262 irepl
#    211 irule
#    187 imkdir
#    126 iswitch
#    109 itrim
#    103 irmtrash
#     94 iqstat
#     60 iscan
#     59 ierror
#     51 ibun
#     50 icp
#     48 iquota
#     39 iqdel
#     32 iticket
# ✓   23 ihelp
#     22 imcoll
#     17 irsync
#     17 iinit
#     11 igroupadmin
#     10 ilocate
#      8 igetwild
#      5 iuserinfo
#      5 imiscsvrinfo
#      5 ienv
#      3 iexit
#      3 idbug
#      2 iqmod
#      2 ipwd
#      2 ipasswd
#      2 ilresc
#      2 ifsck
#      2 iexecmd
#      2 ichown
# -    1 izonereport
#      1 ixmsg
#      1 ichecksum
#      0 ireg
#      0 iphybun


function __remote_path_suggestions
  if [ (count $argv) -ge 1 ]
    set prefix $argv[1]
  else
    set prefix ''
  end
  set curArg (string replace --regex "^$prefix" '' (commandline --current-token))
  if not string match --quiet --regex / $curArg
    set dirName ''
  else
    set pathParts (string split --right --max 1 / $curArg)
    set dirName $pathParts[1]/
  end
  # Consider replacing sed with shell only string manipulations
  ils $dirName | sed '1d;s|^  \(C- \)\?||;s|^.*/\(.*\)|\1/|;s|^|'$prefix$dirName'|'
end


#
# iget
#

function __iget_first_arg
  set cmd (commandline --cut-at-cursor --tokenize)
  test (count $cmd) -eq 1
end

complete --command iget \
  --condition '__iget_first_arg' --no-files --arguments "(__remote_path_suggestions)"


#
# ihelp
#

function __ihelp_argument_suggestions
  set cmd (commandline --cut-at-cursor --tokenize)
  if [ (count $cmd) -eq 1 ]
    set args \
      iadmin ibun icd ichksum ichmod icp idbug ienv ierror iexecmd iexit ifsck iget igetwild \
      igroupadmin ihelp iinit ilocate ils ilsresc imcoll imeta imiscsvrinfo imkdir imv ipasswd \
      iphybun iphymv ips iput ipwd iqdel iqmod iqstat iquest iquota ireg irepl irm irmtrash irsync \
      irule iscan isysmeta iticket itrim iuserinfo ixmsg izonereport
    for arg in $args
      printf '%s\n' "$arg"
    end
  else
    printf ''
  end
end

complete --command ihelp --short-option h --exclusive --description 'shows help'
complete --command ihelp --short-option a --exclusive \
  --description 'prints the help text for all the iCommands'
complete --command ihelp --no-files --arguments "(__ihelp_argument_suggestions)"


#
# iput
#
# TODO extend to cover options
# TODO make suggest appropriate arguments
# TODO make suggest multiple local paths
# TODO make suggest at most one remote path

function __iput_after_first_arg
  set cmd (commandline --cut-at-cursor --tokenize)
  test (count $cmd) -gt 1
end

complete --command iput \
  --condition '__iput_after_first_arg' --no-files --arguments "(__remote_path_suggestions)"


#
# irsync
#

function __irsync_suggest_remote
  string match --quiet --regex '^i:' (commandline --current-token)
end

complete --command irsync \
  --condition '__irsync_suggest_remote' --no-files --arguments "(__remote_path_suggestions i:)"


#
# ibun, icd, ichksum, icp, ils, imeta, imkdir, imv, iphybun, iphymv, irm,
# irmtrash, and itrim
#
# TODO extend to cover options
# TODO make suggest appropriate arguments
# TODO make suggest multiple arguments, if applicable

for cmd in ibun icd ichksum icp ils imeta imkdir imv iphybun iphymv irm irmtrash itrim
  complete --command $cmd --no-files --arguments "(__remote_path_suggestions)"
end
