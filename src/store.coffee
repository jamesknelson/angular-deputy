mod = angular.module 'deputy.store', []

mod.factory 'DeputyStore', ["$cacheFactory", ($cacheFactory) ->

  # TODO: actually make this persistent :)
  class PersistentCache
    constructor: (name, capacity) ->
      @cache = $cacheFactory("$deputyCache:#{name}", capacity: capacity)

    get: (id) ->
      @cache.get(id)

    put: (id, obj) ->
      @cache.put(id, obj)

    remove: (id) ->
      @cache.remove(id)


  class DeputyStore
    constructor: (deputyOptions, @model, options={}) ->
      options.cacheCapacity ?= deputyOptions.cacheCapacity

      @workingCopies = {}
      @persistentCopies = new PersistentCache(@model.name, options.cacheCapacity)
      @propertyChangeListeners = {}

      @indexWorkingCopies = {}
      @indexPersistentCopies = {}
      @indexUpdateListeners = {}

      indexNamer = options.indexNamer ? deputyOptions.defaultIndexNamer

      # Build our index defs from passed in options
      @indexes = {}
      options.indexes ?= []
      options.indexes.forEach (index) =>
        if angular.isString(index)
          indexDef = { properties: [index] }
        else if angular.isArray(index)
          indexDef = { properties: index }
        else
          indexDef = index

        indexDef.name ?= indexNamer(indexDef.properties)
        @indexes[indexDef.name] = indexDef

      # Make sure any belongsTo associations have indexes
      for refName, refDef of @model.references
        if refDef.type == "belongsTo"
          indexName = refDef.foreignKeyProperty
          if angular.isUndefined(@indexes[indexName])
            @indexes[indexName] = { properties: [indexName], name: indexName }
          else if !@indexes[indexName]
            throw new Error("new DeputyStore: belongsTo properties need indexes on their foreign key property")

      # Make sure anything specified as "unique" has a unique index
      @model.unique.forEach (properties) =>
        properties = [properties] unless angular.isArray(properties)
        indexName = indexNamer(properties)
        indexDef = @indexes[indexName]
        if angular.isUndefined(indexDef)
          @indexes[indexName] = { properties: properties, unique: true, name: indexName }
        else if !indexDef or !indexDef.unique
          throw new Error("new DeputyStore: non-unique index conflicts with unique option")

      # Build our list of indexes which need to be updated for each property
      @propertyIndexes = {}
      for indexName, indexDef of @indexes
        do (indexName, indexDef) =>
          indexDef.makeKey = options.indexKeyGenerator or deputyOptions.defaultIndexKeyGenerator(@model, indexDef)
          indexDef.properties.forEach (propName) =>
            @propertyIndexes[propName] ?= []
            @propertyIndexes[propName].push indexDef

          # Set up stores for this index
          @indexWorkingCopies[indexName] = {}
          @indexPersistentCopies[indexName] =
            new PersistentCache("#{@model.name}:#{indexName}", options.cacheCapacity)
          @indexUpdateListeners[indexName] = {}


      # These should not be updated.
      Object.freeze(@propertyIndexes)
      Object.freeze(@indexes)
      Object.freeze(@indexWorkingCopies)
      Object.freeze(@indexPersistentCopies)
      Object.freeze(@indexUpdateListeners)

      # TODO:
      # set up list of properties which cause a computed value to be recomputed
      # (has many dependencies just result in it always re-occuring)


    # Let DeputyStore know that the given id is being used by someone new
    getWorkingCopyReference: (id) ->
      if workingCopy = @workingCopies[id]
        workingCopy.$deputyUseCount += 1
      else
        if persistentCopy = @persistentCopies.get(id)
          workingCopy = @workingCopies[id] = angular.copy(persistentCopy)
          workingCopy.$deputyUseCount = 1
        else
          workingCopy = @workingCopies[id] =
            $deputyUseCount: 1
            $deputyUnreceived: true
            $deputyState: {}

        @propertyChangeListeners[id] = {}

      workingCopy


    # Let DeputyStore know that the given id is no longer being used by one
    # of it's previous users
    disposeWorkingCopyReference: (id) ->
      workingCopy = @workingCopies[id]
      workingCopy.$deputyUseCount -= 1
      if workingCopy.$deputyUseCount == 0
        @propertyChangeListeners[id] = null
        delete @workingCopies[id]
      workingCopy.$deputyUseCount


    # Add a callback which will be passed the new and old values when the
    # given property changes on the working copy for this id.
    attachPropertyListener: (id, propertyName, cb) ->
      resourceListeners = @propertyChangeListeners[id]
      propertyChangeListeners = resourceListeners[propertyName] ?= []
      propertyChangeListeners.push cb

      detachListener = ->
        i = propertyChangeListeners.indexOf cb
        propertyChangeListeners.splice(i, 1) if i != -1


    getIndexWorkingCopyReference: (indexName, indexKey) ->
      if workingIndex = @indexWorkingCopies[indexName][indexKey]
        workingIndex.$deputyUseCount += 1
      else
        if persistentIndex = @indexPersistentCopies[indexName].get(id)
          workingIndex = angular.copy(persistentIndex)
          @indexWorkingCopies[indexName][indexKey] = workingIndex
          workingIndex.$deputyUseCount = 1
        else
          workingIndex = @indexWorkingCopies[indexName][indexKey] = []
          workingIndex.$deputyUseCount = 1
          workingIndex.$deputyComplete = false
          workingIndex.$deputyUnreceived = true

        @indexUpdateListeners[indexName][indexKey] = []

      workingIndex


    disposeIndexWorkingCopyReference: (indexName, indexKey) ->
      workingIndex = @indexWorkingCopies[indexName][indexKey]
      workingIndex.$deputyUseCount -= 1
      if workingIndex.$deputyUseCount == 0
        @indexUpdateListeners[indexName][indexKey] = null
        delete @indexWorkingCopies[indexName][indexKey]
      workingIndex.$deputyUseCount


    # Add a callback which will be passed the added and removed ids each
    # time the index working copy changes for the specified key
    attachIndexListener: (indexName, indexKey, cb) ->
      listeners = @indexUpdateListeners[indexName][indexKey]
      listeners.push cb

      detachListener = ->
        i = listeners.indexOf cb
        listeners.splice(i, 1) if i != -1


    replaceIndex: (indexName, indexKey, ids) ->
      # TODO:
      # - what about if we only have a persitently stored index?
      if workingIndex = @indexWorkingCopies[indexName][indexKey]
        # TODO:
        # - set index up-to-date time
        # - make index complete
        delete @indexWorkingCopies[indexName][indexKey].$deputyUnreceived


    # Mark an index as incomplete, over all keys unless a specific key is given
    invalidateIndex: (indexName, indexKey) ->
      # TODO:


    # Update all indexes based on the specific list of changes for the given
    # resource id, optionally ignoring changes to one specific index (in case
    # we received that entire index, and we want to entirely replace it)
    reindexResource: (id, changes, ignoredIndexName) ->
      # TODO:


    storeResource: (resource, ignoredIndexName) ->
      if id = resource[@model.id]
        workingCopy = @workingCopies[id]
        persistentCopy = @persistentCopies.get(id) or {$deputyState: {}}

        if workingCopy and workingCopy.$deputyUnreceived
          delete workingCopy.$deputyUnreceived

        newState = current: new Date().getTime()

        # Store flow:
        # 1. Update the working copy of everything that changes, including
        #    foreignKeyProperty inferred from embedded belongsTo resources.
        # 2. Recursively store embedded data. This must come after 1 in case
        #    referenced resources need to compute values using this resource's
        #    new properties.
        # 3. Calculate computed values. Note that they can safely refer to
        #    hasMany, hasOne and belongsTo referenced resources.
        # 4. If required, update the indexes based on list of changed values.
        # 5. If required, call index listeners on any updated indexes
        # 6. Call property listeners on any updated props/compueted props
        changes = {}
        for key, value of resource
          do (key, value) =>
            if refDef = @model.references[key]
              # If the foreign key for this association is stored on the other
              # model, make sure it is set correctly
              if (refDef.type == "hasMany" or refDef.type == "hasOne")
                indexName = refDef.inverseForeignKeyProperty
                indexId = id
                values = if angular.isArray(value) then value else [value]
                values.forEach (v) ->
                  if angular.isUndefined(v[indexName])
                    v[indexName] = id
                  else if v[indexName] != id
                    throw new Error("DeputyStore: Received embedded data referencing somebody else!")
              else if refDef.type == "belongsTo"
                console.log "finish this"
                # TODO:
                # set foreignKeyProperty on ourself if it isn't there already
                # If we do set foreignKeyProperty to a different value than exists,
                # add it to the change list

              refDef.service.$store.receiveData(value, indexName, indexId)
            else if @model.compute[key]
              throw new Error("DeputyStore: received a value for a computed property")
            else
              # TODO: keep track of updated keys and their old values for faster
              #       reindexing

              # Only update the working copy if it has not been marked as fixed
              if workingCopy and !(workingCopy[key] and workingCopy.$deputyState[key].fixed)
                workingCopy[key] = value
                workingCopy.$deputyState[key] = newState

              # Always update the persistent copy
              persistentCopy[key] = value
              persistentCopy.$deputyState[key] = newState

        # TODO: use new working copy to run updates on computed values, and
        # add any updated computed values to the change list. Use the change
        # list to limit computations to those computed values which have
        # actually changed. Run this before indexes updates, as we can still
        # index computed values. If working copy uses referenced data, just
        # do it without bothering to figure out if anything has changed.

        # TODO: if there is no existing working or persistent copy for
        # this resource, and we receive a resource missing some indexed
        # properties, mark those indexes as incomplete over all keys (as
        # it may be a newly added resource without the information needed
        # to index it, which would make the indexes incomplete).
        @reindexResource(id, changes, ignoredIndexName)

        # TODO: call the property listeners on all updated properties

        @persistentCopies.put(id, persistentCopy)

        id


    purgeResource: (resource) ->
      # First store any updates, in case they are needed to destroy dependents
      if id = @storeResource(resource, true)
        delete @workingCopies[id]
        @persistentCopies.remove(id)

        # TODO:
        # - remove from indexes
        # - if any associations with dependent: 'destroy', remove referenced
        #   resources too

        return id
      else
        throw new Error("DeputyStore: received delete instruction without id")


    receiveData: (data, indexName, indexKey) ->
      indexDef = @indexes[indexName]

      if angular.isArray(data)
        if indexDef and indexDef.unique and data.length > 1
          throw new Error("DeputyStore: tried to store multiple records on a unique index")
        receivedIds = data.map (r) -> @storeResource(r, indexName)
      else
        receivedIds = @storeResource(data, indexName)

      if indexDef
        replaceIndex(indexName, indexKey, receivedIds)

      receivedIds


    receiveDelete: (data) ->
      if angular.isArray(data)
        data.map purgeResource
      else
        purgeResource(data)


    # Return a read-only reference to the selected data, which is cleaned up
    # when there is no longer anything referencing it.
    getResourceWindow: (id, normalizedSelector) ->
      {values, references} = normalizedSelector

      # Names of properties which refer to embedded windows
      embeddedNames = Object.keys(references)

      # Keep a list of things we need to detach/dispose when we dispose ourself
      propertyListenerDetachers = []
      embeddedWindowsDisposers = {}

      # Where we keep the data/windows our getters currently refer to
      currentWorkingCopy = null
      currentEmbeddedData = {}

      # Count the number of times someone has called dispose/register on us
      localWorkingCopyReferences = 0

      # Creating a dummy object and attaching our getters to it's prototype is
      # counter-intuitive, but makes things a *lot* faster, as Mozilla
      # has horrifically slow defineProperty getters when used directly on
      # on object:
      # - https://bugzilla.mozilla.org/show_bug.cgi?id=626021
      # - http://jsperf.com/javascript-defineproperty-get-vs-standard-property
      LiveResource = ->
      LiveResource.prototype = {}
      resource = new LiveResource()

      # Helper which returns a list of all properties which are not available
      # or not in date.
      # Optionally can limit it to a certain subset of the root properties/
      # references by passing in an array of strings.
      resource.$getOutOfDate = (limitTo, maxAge) ->
        now = new Date().getTime()
        limitTo ?= values.concat(embeddedNames)
        outOfDate = limitTo.filter (key) ->
          if references[key]
            !currentEmbeddedData[key] or
            currentEmbeddedData[key].resource.$getOutOfDate()
          else
            # Note: this treats detached/saving data as in-date
            !currentWorkingCopy.$deputyState[key] or (
              currentWorkingCopy.$deputyState[key].current and
              (now - currentWorkingCopy.$deputyState[key].current) > maxAge
            )

      # Helper which returns true if all selected data has a state
      resource.$isComplete = ->
        valuesComplete = values.every (key) ->
          currentWorkingCopy.$deputyState[key]
        referencesComplete = embeddedNames.every (key) ->
          currentEmbeddedData[key] and
          !currentEmbeddedData[key].resource.$isUnreceived()

        valuesComplete and referencesComplete

      # Helper which returns true if the resource has no loaded data
      resource.$isUnreceived = ->
        !!currentWorkingCopy.$deputyUnreceived

      # Make read-only getters for the selected data, to prevent accidental
      # rewrites of our working copy. These should be inlined by the
      # optimizations in any modern browser.
      # TODO: test performance! it should be roughly equivalent to directly
      #       accessing the properties off the working copy
      values.forEach (prop) ->
        if prop[0] == "$"
          throw new Error("DeputyStore: you cannot select properties starting with '$'")
        Object.defineProperty LiveResource.prototype, prop,
          get: -> currentWorkingCopy[prop]
          enumerable: true
          configurable: false

      embeddedNames.forEach (prop) ->
        if prop[0] == "$"
          throw new Error("DeputyStore: you cannot select properties starting with '$'")
        Object.defineProperty LiveResource.prototype, prop,
          get: -> currentEmbeddedData[prop]
          enumerable: true
          configurable: false

      # Make the object read-only
      Object.freeze resource

      # Register a new user of this window
      register = =>
        localWorkingCopyReferences += 1
        if localWorkingCopyReferences == 1
          # Set our working copy for values on this resource
          currentWorkingCopy = @getWorkingCopyReference(id)

          # Set up windows for embedded references
          for refName, recurseNormalizedSelector of references
            do (refName, recurseNormalizedSelector) =>
              refDef = @model.references[refName]
              refStore = refDef.service.$store
              if refDef.type == "belongsTo"
                onIdUpdate = (newReferencedId, oldReferencedId) ->
                  if newReferencedId != oldReferencedId
                    if embeddedWindowsDisposers[refName]
                      embeddedWindowsDisposers[refName].dispose()

                    if newReferencedId
                      embeddedWindow = refStore.getResourceWindow(
                        newReferencedId,
                        recurseNormalizedSelector
                      )
                      embeddedWindowsDisposers[refName] = embeddedWindow.dispose
                      currentEmbeddedData[refName] = embeddedWindow.resource
                    else
                      embeddedWindowsDisposers[refName] = null
                      currentEmbeddedData[refName] = null

                propertyListenerDetachers.push(
                  @attachPropertyListener(id, refDef.foreignKeyProperty, onIdUpdate)
                )

                # Need to call our onIdUpdate manually once to set up the
                # initial window
                onIdUpdate(currentWorkingCopy[refDef.foreignKeyProperty])

              else if refDef.type == "hasMany"
                embeddedWindow = refStore.getIndexWindow(
                  refDef.inverseForeignKeyProperty
                  currentWorkingCopy[@model.id],
                  recurseNormalizedSelector
                )
                embeddedWindowsDisposers[refName] = embeddedWindow.dispose
                currentEmbeddedData[refName] = embeddedWindow.collection

      # Register that a previous user doesn't want to use the window anymore
      dispose = =>
        localWorkingCopyReferences -= 1
        if localWorkingCopyReferences == 0
          # Dispose the working copy for data stored on this resource
          @disposeWorkingCopyReference(id)

          # Every belongs to association will have an active property listener
          detach() for detach in propertyListenerDetachers
          propertyListenerDetachers.length = 0

          # Empty belongs to associations will not have a dispose method, so
          # we need to check for existence
          for refName, dispose in embeddedWindowsDisposers
            dispose() if dispose
            embeddedWindowsDisposers[refName] = null

          # Make sure our previous data doesn't continue to be accessible,
          # so any attempted access causes an error
          currentEmbeddedData[refName] = null for refName in embeddedNames
          currentWorkingCopy = null

      register()

      # Public storeWindow API
      storeWindow =
        resource: resource
        dispose: dispose
        register: register


    getIndexWindow: (indexName, indexKey, normalizedSelector) ->
      indexDef = @indexes[indexName]

      # Unlike getResourceWindow, we are unable to prevent modifications to
      # arr by using getters, as we want the returned value to be usable as
      # a standard javascript array, and there seems to be no way to
      # accurately emulate that without ES6.
      currentWorkingIndex = null
      currentCollection = []

      detachListener = null
      embeddedWindowsDisposers = {}

      # Count the number of times someone has called dispose/register on us
      localWorkingCopyReferences = 0

      # Helper which returns a list of ids of resources in this sollection
      # which are out of date.
      # Optionally can limit it to resources which are out of date for a
      # certain subset of their root properties/references by passing in an
      # array of strings.
      arr.$getOutOfDateIds = (limitTo, maxAge) ->
        # TODO - delegate out to the collection's resource windows

      # Returns false if we have a received an index within the maxAge limit,
      # even if it is incomplete
      arr.$isOutOfDate = (maxAge) ->
        # TODO - does this fn make sense?

      # Helper which returns true if we know all of the ids in the index, or
      # if we did at some point older than the max age.
      arr.$isComplete = ->
        # Is false if unreceived is true, or if the index has somehow
        # been invalidated since it was received
        !!currentWorkingIndex.$deputyComplete

      # Helper which returns true if the index has not yet been received.
      arr.$isUnreceived = ->
        !!currentWorkingIndex.$deputyUnreceived

      register = =>
        localWorkingCopyReferences += 1
        if localWorkingCopyReferences == 1
          # Set up our working copy of the index
          currentWorkingIndex = @getIndexWorkingCopyReference(indexName, indexKey)

          onIndexUpdate = (addedIds, removedIds) =>
            # Add windows for the new ids
            Array.prototype.push.apply currentCollection, addedIds.map (id) =>
              embeddedWindow = @getResourceWindow(id, normalizedSelector)
              embeddedWindowsDisposers[id] = embeddedWindow.dispose
              embeddedWindow.resource

            # Remove old ids from the collection, then dispose of them.
            for id in removedIds
              currentCollection.splice(currentCollection.indexOf(id), 1)
              embeddedWindowsDisposers[id].dispose()
              embeddedWindowsDisposers[id] = null

          detachListener = @attachIndexListener(indexName, indexKey, onIndexUpdate)

          # Need to call our onIndexUpdate manually once to set up the
          # initial window
          onIdUpdate(currentWorkingIndex)

      dispose = =>
        localWorkingCopyReferences -= 1
        if localWorkingCopyReferences == 0
          @disposeIndexWorkingCopyReference(indexName, indexKey)
          detachListener()

          # Dispose of our embedded windows
          for id, dispose in embeddedWindowsDisposers
            dispose() if dispose
            embeddedWindowsDisposers[id] = null

          currentWorkingIndex = null

          # Unfortunately we can't make accessing the collection after disposal
          # cause an error, but we can wipe it.
          currentCollection.length = 0

      register()

      # Public storeWindow API
      storeWindow =
        collection: currentCollection
        dispose: dispose
        register: register


    set: (id, property, state, value) ->
      # TODO:
      # assert that any indexed properties are present in the new or old
      # resource for this id

      # TODO:
      # check we're not updating the resource's id field

      # TODO:
      # Assert we're not setting any read only properties.

      # TODO:
      # if data is *current*, update known properties to ltc

      # TODO:
      # update working data, if the key exists in working data, but DO NOT
      # overwrite data for properties in a detached state (e.g.
      # saving:*, error:*) unless force: true. Instead, return an error
      # (not a failed assertion, because these things happen.)

      # TODO:
      # update any indexes.
      # if uniquely indexed property is updated, assert there is no conflict
      # (as any conflicts should be managed elsewhere)

      # TODO:
      # at least until we have proper websocket support:
      # use inter-page communication to find any other Stores using the same
      # persistent cache, and let them know they can update the item in their
      # weakmaps (if it is in use)

      # TODO:
      # return the key object, if it is a newly inserted resource

]