# iRODS auto completions for the fish shell
#
# This script is derived from i-commands-auto.bash,
# https://github.com/irods/irods-legacy/blob/master/iRODS/irods_completion.bash,
# by Bruno Bzeznik.


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
# iput
#

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

for cmd in ibun icd ichksum icp ils imeta imkdir imv iphybun iphymv irm irmtrash itrim
  complete --command $cmd --no-files --arguments "(__remote_path_suggestions)"
end
