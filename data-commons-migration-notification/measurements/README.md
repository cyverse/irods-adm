# Survey Inputs

`build-recipients` reads a survey of the community-released collections rather than a list of
figures typed in by hand, so that no notice can claim a number that was not measured. The survey
itself is not in this repository: it describes the state of the Data Commons on the day it was
taken, and it goes stale.

Two files are needed. `example/` holds a working pair covering two invented collections, enough to
run the whole pipeline without touching the real survey.

## metadata

A JSON object keyed by collection name. Each value has a `path`, the collection's absolute iRODS
path, and a `meta` object holding that collection's AVUs. An AVU value may be a string or a list of
strings, since a collection can carry several `Contributor` values.

`Title`, `Creator`, `Contributor` and `Rights` are the attributes read. A collection missing all
four still gets a record; its notice just has less to say.

```json
{
  "example_soil_survey": {
    "path": "/iplant/home/shared/example_soil_survey",
    "meta": {
      "Title": "Example Soil Survey",
      "Creator": "Example Research Group",
      "Rights": "CC0 1.0 Universal",
      "Contributor": ["A. Example", "B. Example"]
    }
  }
}
```

This is the shape the legacy Data Commons `api_metadata` endpoint returns, one call per collection.

## publishable

A JSON object keyed by collection name, giving the counts the fixed mapping produces:

- `public`: how many folders directly under the collection are publicly readable, which is how many
  datasets the collection would get.
- `public_titled`: how many of those folders carry a title of their own. The rest arrive named after
  their directory with an empty description, which is the thing the notices have to be honest about.

Other keys are ignored, so a richer survey file can be passed as-is.

```json
{
  "example_soil_survey": {"public": 4, "public_titled": 1}
}
```

## Deriving the counts

`public` and `public_titled` come from walking one level under each collection, not from the
collection's own AVUs. Anything deeper than one level is reachable over WebDAV but is not a
catalogue entry, and a loose file directly under a collection is not published at all, so neither
counts toward `public`.
