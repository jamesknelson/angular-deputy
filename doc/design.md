# angular-deputy

## API Design Rules

Schema
1. Each resource can be uniquely identified by a single id, available in a single property
2. A resource's id is never updated
3. An id is never null
4. Each association is specified by a single foreign key property which contains the above-mentioned id of the associated resource, or is otherwise null

Queries
1. It is possible to generate a query for a non-embedded associated resource solely from the referencing resource
2. Any endpoint which must be able to access the cache must also be able to generate a resource id from it's queries
3. For a given endpoint, `queryIdExtractor(queryGenerator(id)) = id` must be `true`

Responses
1. The id of resources handled by a request is always returned (for delete, get, patch, post, etc. - everything!)
2. Any endpoint which adds/updates data should return an object including all updated fields, with "undefined" if they have been deleted.
3. Any request to a selectable endpoint will supply *all* of the selected properties for every returned object, even if they are undefined


## Architecture

### Resource Store

There are 3 main "layers" to the angular-deputy resource store:

#### 1. LiveResource

LiveResource objects are read-only getters for the working copies of your data. They can automatically embed properties referencing associated resources.

LiveResource objects also have a number of helpers to get metadata about the state of the stored resource:

- `$getOutOfDate`
- `$isComplete`
- `$isUnreceived`

#### 2. Working copies

Hold the latest copy of each resource currently in use, including:

 - any changes made to the data but not yet saved
 - any errors which made it impossible to save the current version to the server
 - the status of the various properties in the resource, including the last time when we know the value was current (assuming it is current)

Working copies are stored in a WeakMap - so they will automatically be cleaned up once they are no long used by the application. They are kept up to date with changes, and new properties can be added as necessary.

#### 3. Offline cache

Resources are placed in an LRU offline cache in the order they are accessed, and kept up to date with the latest known "correct" copies of the resource (as specified by the server). This cache wil be queried for resources before the server is. A list of known properties is kept with each record, so that partial resources can be accurately saved for later.

#### A. Indexes

In addition to a store for resources, there is a similar store for indexes of those resources, with the same 3 layers.

### Services

While data is kept in stores, it is accessed through services.

There are two main types of services - **Resource Services** and **Index Services**. Resource services are tasked with providing access to individual resources, while index services index those resources, typically based on foreign keys, providing access to lists of resources with a given trait.

Resource services themselves come in two flavors - REST services (typically for querying for a specific resource), and streaming services which notify users of changes in realtime. It is important to note that multiple services may refer to the same resource, for example an index, streaming and resource service all referring to the same todo items. Also, one service call may return multiple types of objects, typically in the case where associations are embedded.

Resource stores are happily oblivious to the concept of services. They return what they are able to return, and forget about everything they can't. As such, the service which calls a store will need to check the return, and possibly query the remote service to fill out the response with the remaining required data.
