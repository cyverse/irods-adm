#!/usr/bin/tcc -run

#include <stdio.h>

static void
show_help( FILE * const stream, char const * const execName, int const version ) {
  char const * const help =
"\n"
"%s version %d\n"
"\n"
"Usage:\n"
" %s [OPTIONS] INTERVALS_FILE\n"
" \n"
" Generates a report on the number of concurrent sessions during each second.\n"
" \n"
"Parameters:\n"
" INTERVALS_FILE  the file containing session intervals\n"
" \n"
"Options:\n"
" -h, --help     show help and exit\n"
" -v, --version  show version and exit\n"
" \n"
"Summary:\n"
" Generates a report on the number of concurrent sessions during each second. It\n"
" reads an interval report with the following format.\n"
" \n"
" START_TIME STOP_TIME ...\n"
" \n"
" START_TIME is the time when a session started in seconds since the POSIX epoch.\n"
" STOP_TIME is the time when the same session ended in seconds since the POSIX\n"
" epoch. The rest of the line is ignored.\n"
" \n"
" The generate report is written to standard output where each line has the\n"
" following format.\n"
" \n"
" TIME OPEN_SESSION_COUNT\n"
" \n"
" TIME is in seconds since the POSIX epoch. OPEN_SESSION_COUNT is the number of\n"
" open sessions at TIME.\n"
" \n"
" The report is sorted by time with the first time being the earliest start time\n"
" and the last time being the latest stop time.\n";

  fprintf( stream, help, execName, version, execName );
}


#include <limits.h>
#include <stdbool.h>
#include <stdlib.h>
#include <string.h>

#include <getopt.h>
#include <libgen.h>
#include <unistd.h>

// If PATH_MAX isn't defined in limits.h, give it a default value
#ifndef PATH_MAX
#define PATH_MAX 4096
#endif


typedef struct {
  unsigned int begin;
  unsigned int end;
} Interval;

typedef struct {
  Interval span;
  size_t numBins;
  size_t * bin;
} Bins;

typedef bool (* ConsumeFunction)( void *, Interval const * );


static bool bin_sessions( Bins *, Interval const * );
static bool count_sessions( char const * const );
static bool parse_intervals( FILE *, ConsumeFunction, void * );
static bool update_time_bounds( Interval *, Interval const * );
static void write_counts( Bins const * );

static int const Version = 1;


int
main( int const argc, char * const argv [] ) {
  char execPath [ PATH_MAX + 1 ] = "\0";

  ssize_t len = 0;
  if( (len = readlink( argv[ 0 ], execPath, sizeof( execPath ) - 1 )) != -1 ) {
    execPath[ len ] = '\0';
  } else {
    strncpy( execPath, argv[ 0 ], sizeof( execPath ) );
  }

  char const * const execName = basename( execPath );

  bool showVersion = false;

  while( true ) {
    struct option const longOpts [] = {
      { "help", no_argument, NULL, 'h' },
      { "verbose", no_argument, NULL, 'v' }
    };

    int const shortOpt = getopt_long( argc, argv, "hv", longOpts, NULL );

    if( shortOpt == -1 ) {
      break;
    }

    switch( shortOpt ) {
      case 'h':
        show_help( stdout, execName, Version );
        return EXIT_SUCCESS;

      case 'v':
        showVersion = true;
        break;

      case '?':
      default:
        show_help( stderr, execName, Version );
        return EXIT_FAILURE;
    }
  }

  if( showVersion ) {
    printf( "%d\n", Version );
    return EXIT_SUCCESS;
  }

  if( argc - optind < 1 ) {
    show_help( stderr, execName, Version );
    return EXIT_FAILURE;
  }

  char const * const intervalsFile = argv[ optind ];

  return count_sessions( intervalsFile ) ? EXIT_SUCCESS : EXIT_FAILURE;
}


static bool
count_sessions( char const * const intervalsFile ) {
  FILE * const stream = fopen( intervalsFile, "r" );

  if( stream == NULL ) {
    fprintf( stderr, "Fatal: cannot open %s\n", intervalsFile );
    return false;
  }

  Interval timeSpan = { UINT_MAX, 0 };

  if( !parse_intervals( stream, ( ConsumeFunction )&update_time_bounds, &timeSpan ) ) {
    fclose( stream );
    return false;
  }

  fprintf( stderr, "Info: lb = %u, ub = %u\n", timeSpan.begin, timeSpan.end );

  size_t const numBins = ( size_t )(timeSpan.end - timeSpan.begin + 1);
  fprintf( stderr, "Info: numBins = %lu\n", numBins );

  Bins counts = {
    timeSpan,
    numBins,
    ( size_t * )calloc( numBins, sizeof( size_t ) )
  };

  if( counts.bin == NULL ) {
    fprintf( stderr, "Fatal: couldn't allocate binning array\n" );
    fclose( stream );
    return false;
  }

  rewind( stream );

  if( !parse_intervals( stream, ( ConsumeFunction )&bin_sessions, &counts ) ) {
    free( counts.bin );
    fclose( stream );
    return false;
  }

  fclose( stream );
  write_counts( &counts );
  free( counts.bin );
  return true;
}


static bool
bin_sessions( Bins * const counts, Interval const * const interval ) {
  for( size_t binIdx = ( size_t )(interval->begin - counts->span.begin);
       binIdx <= ( size_t )(interval->end - counts->span.begin);
       ++binIdx ) {
    if( binIdx >= counts->numBins ) {
      fprintf( stderr, "Warning: not enough bins\n" );
      break;
    }

    ++counts->bin[ binIdx ];
  }

  return true;
}


static bool
parse_intervals(
    FILE * const stream,
    ConsumeFunction const consume_interval,
    void * const consumerState ) {
  size_t lineLen = 22;
  char * line = (char *)calloc( lineLen, 1 );

  if( line == NULL ) {
    fprintf( stderr, "Fatal: out of memory\n" );
    return false;
  }

  size_t intervalNum = 0;
  ssize_t nread = 0;

  while( (nread = getline( &line, &lineLen, stream )) >= 0 ) {
    if( line[ 0 ] == '\n' ) {
      continue;
    }

    ++intervalNum;

    if( nread < 21 ) {
      fprintf( stderr, "Error: interval %lu is too short, skipping\n", intervalNum );
      continue;
    }

    Interval interval = { UINT_MAX, 0 };

    if( sscanf( line, "%u %u", &interval.begin, &interval.end ) < 2 ) {
      fprintf( stderr, "Error: interval %lu can't be parsed, skipping\n", intervalNum );
      continue;
    }

    if( !(*consume_interval)( consumerState, &interval ) ) {
      break;
    }
  }

  free( line );

  if( ferror( stream ) != 0 ) {
    fprintf( stderr, "FATAL: Failed to fully read intervals file\n" );
    return false;
  }

  return true;
}


static bool
update_time_bounds( Interval * const bounds, Interval const * const interval ) {
   if( bounds->begin > interval->begin ) {
     bounds->begin = interval->begin;
   }

   if( bounds->end < interval->end ) {
     bounds->end = interval->end;
   }

   return true;
}


static void
write_counts( Bins const * const counts ) {
  for( size_t binIdx = 0; binIdx < counts->numBins; ++binIdx ) {
    printf( "%u %lu\n", counts->span.begin + ( unsigned int )binIdx, counts->bin[ binIdx ] );
  }
}
