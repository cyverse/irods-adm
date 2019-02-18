#include <limits.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>


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

static bool parse_intervals( FILE *, ConsumeFunction, void * );

static bool update_time_bounds( Interval *, Interval const * );

static void write_counts( Bins const * );


int
main( int const argc, char * * const argv ) {
  if( argc < 2 ) {
    fprintf( stderr, "The intervals files is required as the first argument\n" );
    exit( EXIT_FAILURE );
  }

  char const * const intervalsFile = argv[ 1 ];
  FILE * const stream = fopen( intervalsFile, "r" );

  if( stream == NULL ) {
    fprintf( stderr, "Fatal: cannot open %s\n", intervalsFile );
    exit( EXIT_FAILURE );
  }

  Interval timeSpan = { UINT_MAX, 0 };

  if( !parse_intervals( stream, ( ConsumeFunction )&update_time_bounds, &timeSpan ) ) {
    fclose( stream );
    exit( EXIT_FAILURE );
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
    exit( EXIT_FAILURE );
  }

  rewind( stream );

  if( !parse_intervals( stream, ( ConsumeFunction )&bin_sessions, &counts ) ) {
    free( counts.bin );
    fclose( stream );
    exit( EXIT_FAILURE );
  }

  fclose( stream );
  write_counts( &counts );
  free( counts.bin );
  exit( EXIT_SUCCESS );
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
