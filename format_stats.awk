#! /usr/bin/awk -f


function sort(ARRAY, LEN, i, j, temp) {
  for (i = 2; i <= LEN; ++i) {
    for (j = i; (j - 1) in ARRAY && ARRAY[j - 1] > ARRAY[j]; --j) {
      temp = ARRAY[j];
      ARRAY[j] = ARRAY[j - 1];
      ARRAY[j - 1] = temp;
    }
  }
  return;
}


function sort_keys(ARRAY, SORTED_KEYS, keyCount, key) {
  keyCount = 0;
  for (key in ARRAY) {
    ++keyCount;
    SORTED_KEYS[keyCount] = key;
  }
  sort(SORTED_KEYS, keyCount);
  return keyCount;
}


/dumping logs/ {
  split($4, h, ".");
  currentHost = h[1]; 
  printf("\r%s\n", currentHost) > "/dev/stderr";
}


/  dumping/ { 
  printf("\r  %s\n", $3) > "/dev/stderr";
  gsub(/\/home\/irods\/iRODS[^\/]*\/server\/log\/rodsLog\./, "", $3);
  currentKey = currentHost ":" $3; 
  keys[currentKey] = 1;
}


/   / {
  split($1, n, "/");
  errorCount[currentKey] += n[1];
  sessionCount[currentKey] += n[2];
}


END {
  printf "%-10s  %-9s  %-13s  %-11s\n", "log_start", "server", "session_count", "error_count";
  keyCount = sort_keys(keys, sortedKeys);
  for (idx = 1; idx <= keyCount; ++idx) {
    key=sortedKeys[idx];
    split(key, ht, ":");
    printf "%-10s  %-9s  %13d  %11d\n", ht[2], ht[1], sessionCount[key], errorCount[key];
  } 
}
