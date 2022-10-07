#!/usr/bin/awk -f

BEGIN {
	FS = "\t";
	PROCINFO["sorted_in"] = "@ind_str_asc";
}

{
	peps[$1] = $2;
}

END {
	maxLen = 0;

	for (pep in peps) {
		if (length(pep) > maxLen) {
			maxLen = length(pep);
		}
	}

  if (maxLen > 30) {
		maxLen = 30;
	}
	
	fmtStr = "%-" maxLen "s (%s)\n";

	for (pep in peps) {
		printf fmtStr, pep, peps[pep];
	}
}
