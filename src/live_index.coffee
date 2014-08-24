mod = angular.module 'deputy.liveIndex', []
mod.factory 'LiveIndex', (LiveResource) ->
  (store, indexKey, normalizedSelector) ->
    
    # Unlike getResourceWindow, we are unable to prevent modifications to
    # arr by using getters, as we want the returned value to be usable as
    # a standard javascript array, and there seems to be no way to
    # accurately emulate that without ES6.
    indexReference = null
    collection = []

    detachListener = null
    embeddedWindowsDisposers = {}

    # Count the number of times someone has called dispose/register on us
    registerCount = 0

    # Helper which returns a list of ids of resources in this sollection
    # which are out of date.
    # Optionally can limit it to resources which are out of date for a
    # certain subset of their root properties/references by passing in an
    # array of strings.
    collection.$getOutOfDateIds = (limitTo, maxAge) ->
      # TODO - delegate out to the collection's resource windows

    # Returns false if we have a received an index within the maxAge limit,
    # even if it is incomplete
    collection.$isOutOfDate = (maxAge) ->
      # TODO - does this fn make sense?

    # Helper which returns true if we know all of the ids in the index, or
    # if we did at some point older than the max age.
    collection.$isComplete = ->
      # Is false if unreceived is true, or if the index has somehow
      # been invalidated since it was received
      !!indexReference.$deputyComplete

    # Helper which returns true if the index has not yet been received.
    collection.$isUnreceived = ->
      !!indexReference.$deputyUnreceived

    register = ->
      registerCount += 1
      if registerCount == 1
        # Set up our working copy of the index
        indexReference = store.getReference(indexKey)

        onIndexUpdate = (addedIds, removedIds) ->
          # Add windows for the new ids
          Array.prototype.push.apply collection, addedIds.map (id) ->
            # TODO: 
            embeddedWindow = newLiveResource(store.resourceStore, id, normalizedSelector)
            embeddedWindowsDisposers[id] = embeddedWindow.dispose
            embeddedWindow.resource

          # Remove old ids from the collection, then dispose of them.
          for id in removedIds
            collection.splice(collection.indexOf(id), 1)
            embeddedWindowsDisposers[id].dispose()
            embeddedWindowsDisposers[id] = null

        detachListener = store.onChange(indexKey, onIndexUpdate)

        # Need to call our onIndexUpdate manually once to set up the
        # initial window
        onIdUpdate(indexReference)

    dispose = ->
      registerCount -= 1
      if registerCount == 0
        store.disposeReference(indexKey)
        detachListener()

        # Dispose of our embedded windows
        for id, dispose in embeddedWindowsDisposers
          dispose() if dispose
          embeddedWindowsDisposers[id] = null

        indexReference = null

        # Unfortunately we can't make accessing the collection after disposal
        # cause an error, but we can wipe it.
        collection.length = 0

    register()

    # Public storeWindow API
    @collection = collection
    @dispose = dispose
    @register = register
