mod = angular.module 'deputy.resourceStore', []
mod.constant 'DeputyResourceStore', ->

  class DeputyIndexStore
    constructor: (deputyOptions, @model, options={}) ->


    # Let DeputyStore know that the given id is being used by someone new
    getReference: (id) ->
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

        @propertyChangeCallbacks[id] = {}

      workingCopy


    # Let DeputyStore know that the given id is no longer being used by one
    # of it's previous users
    disposeReference: (id) ->
      workingCopy = @workingCopies[id]
      workingCopy.$deputyUseCount -= 1
      if workingCopy.$deputyUseCount == 0
        @propertyChangeCallbacks[id] = null
        delete @workingCopies[id]
      workingCopy.$deputyUseCount


    # Add a callback which will be passed the new and old values when the
    # given property changes on the working copy for this id.
    onPropertyChange: (id, propertyName, cb) ->
      resourceCallbacks = @propertyChangeCallbacks[id]
      propertyChangeCallbacks = resourceCallbacks[propertyName] ?= []
      propertyChangeCallbacks.push cb

      detachListener = ->
        i = propertyChangeCallbacks.indexOf cb
        propertyChangeCallbacks.splice(i, 1) if i != -1


    # ---
    # NOT YET REFACTORED
    # ---   


    # Update all indexes based on the specific list of changes for the given
    # resource id, optionally ignoring changes to one specific index (in case
    # we received that entire index, and we want to entirely replace it)
    reindexResource: (id, changes, ignoredIndexName) ->
      # TODO:


    storeResource: ({propertyStates, workingProperties, masterProperties, masterVersion}) ->
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
        # 5. If required, call index callbacks on any updated indexes
        # 6. Call property callbacks on any updated props/compueted props
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

        # TODO: call the property callbacks on all updated properties

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


]