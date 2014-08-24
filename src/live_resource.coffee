# Return a read-only reference to the selected data, which is cleaned up
# when there is no longer anything referencing it.
mod = angular.module 'deputy.liveResource', []
mod.factory 'LiveResource', ->
  (store, id, normalizedSelector) ->
    model = store.model

    {values, references} = normalizedSelector

    # Names of properties which refer to embedded windows
    embeddedNames = Object.keys(references)

    # Keep a list of things we need to detach/dispose when we dispose ourself
    callbackDetachers = []
    embeddedWindowsDisposers = {}

    # Where we keep the data/windows our getters currently refer to
    resourceReference = null
    embeddedWindowData = {}

    # Count the number of times someone has called dispose/register on us
    registerCount = 0

    # Creating a dummy object and attaching our getters to it's prototype is
    # counter-intuitive, but makes things a *lot* faster, as Mozilla
    # has horrifically slow defineProperty getters when used directly on
    # on object:
    # - https://bugzilla.mozilla.org/show_bug.cgi?id=626021
    # - http://jsperf.com/javascript-defineproperty-get-vs-standard-property
    LiveResource = ->
    LiveResource.prototype = {}
    resource = new LiveResource()

    # Make read-only getters for the selected data, to prevent accidental
    # rewrites of our working copy. These should be inlined by the
    # optimizations in any modern browser.
    # TODO: test performance! it should be roughly equivalent to directly
    #       accessing the properties off the working copy
    values.forEach (prop) ->
      if prop[0] == "$"
        throw new Error("DeputyStore: you cannot select properties starting with '$'")
      Object.defineProperty LiveResource.prototype, prop,
        get: -> resourceReference[prop]
        enumerable: true
        configurable: false

    embeddedNames.forEach (prop) ->
      if prop[0] == "$"
        throw new Error("DeputyStore: you cannot select properties starting with '$'")
      Object.defineProperty LiveResource.prototype, prop,
        get: -> embeddedWindowData[prop]
        enumerable: true
        configurable: false


    # Helper which returns a list of all properties which are not available
    # or not in date.
    # Optionally can limit it to a certain subset of the root properties/
    # references by passing in an array of strings.
    resource.$getOutOfDate = (limitTo, maxAge) ->
      now = new Date().getTime()
      limitTo ?= values.concat(embeddedNames)
      outOfDate = limitTo.filter (key) ->
        if references[key]
          !embeddedWindowData[key] or
          embeddedWindowData[key].resource.$getOutOfDate()
        else
          # Note: this treats detached/saving data as in-date
          !resourceReference.$deputyState[key] or (
            resourceReference.$deputyState[key].current and
            (now - resourceReference.$deputyState[key].current) > maxAge
          )

    # Helper which returns true if all selected data has a state
    resource.$isComplete = ->
      valuesComplete = values.every (key) ->
        resourceReference.$deputyState[key]
      referencesComplete = embeddedNames.every (key) ->
        embeddedWindowData[key] and
        !embeddedWindowData[key].resource.$isUnreceived()

      valuesComplete and referencesComplete

    # Helper which returns true if the resource has no loaded data
    resource.$isUnreceived = ->
      !!resourceReference.$deputyUnreceived

    # Make the object read-only
    # TODO: test if this can be re-enabled without angular losing it's ability
    # to dirty check
    # Object.freeze resource

    # Register a new user of this window
    register = ->
      registerCount += 1
      if registerCount == 1
        # Set our working copy for values on this resource
        resourceReference = store.getReference(id)

        # Set up windows for embedded references
        for refName, recurseNormalizedSelector of references
          do (refName, recurseNormalizedSelector) ->
            refDef = model.references[refName]
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
                    embeddedWindowData[refName] = embeddedWindow.resource
                  else
                    embeddedWindowsDisposers[refName] = null
                    embeddedWindowData[refName] = null

              callbackDetachers.push(
                store.onPropertyChange(id, refDef.foreignKeyProperty, onIdUpdate)
              )

              # Need to call our onIdUpdate manually once to set up the
              # initial window
              onIdUpdate(resourceReference[refDef.foreignKeyProperty])

            else if refDef.type == "hasMany"
              embeddedWindow = refStore.getIndexWindow(
                refDef.inverseForeignKeyProperty
                resourceReference[model.id],
                recurseNormalizedSelector
              )
              embeddedWindowsDisposers[refName] = embeddedWindow.dispose
              embeddedWindowData[refName] = embeddedWindow.collection

    # Register that a previous user doesn't want to use the window anymore
    dispose = ->
      registerCount -= 1
      if registerCount == 0
        # Dispose the working copy for data stored on this resource
        store.disposeReference(id)

        # Every belongs to association will have an active property listener
        detach() for detach in callbackDetachers
        callbackDetachers.length = 0

        # Empty belongs to associations will not have a dispose method, so
        # we need to check for existence
        for refName, dispose in embeddedWindowsDisposers
          dispose() if dispose
          embeddedWindowsDisposers[refName] = null

        # Make sure our previous data doesn't continue to be accessible,
        # so any attempted access causes an error
        embeddedWindowData[refName] = null for refName in embeddedNames
        resourceReference = null

    register()

    # Public storeWindow API
    @resource = resource
    @dispose = dispose
    @register = register