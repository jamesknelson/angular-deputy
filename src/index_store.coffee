mod = angular.module 'deputy.indexStore', []
mod.constant 'DeputyIndexStore', ->

  class DeputyIndexStore
    constructor: (deputyOptions, @resourceStore, options={}) ->    


    getReference: (indexKey) ->
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


    disposeReference: (indexKey) ->
      workingIndex = @indexWorkingCopies[indexName][indexKey]
      workingIndex.$deputyUseCount -= 1
      if workingIndex.$deputyUseCount == 0
        @indexUpdateListeners[indexName][indexKey] = null
        delete @indexWorkingCopies[indexName][indexKey]
      workingIndex.$deputyUseCount


    # Add a callback which will be passed the added and removed ids each
    # time the index working copy changes for the specified key
    onChange: (indexKey, cb) ->
      listeners = @indexUpdateListeners[indexName][indexKey]
      listeners.push cb

      detachListener = ->
        i = listeners.indexOf cb
        listeners.splice(i, 1) if i != -1


    replace: (indexKey, ids) ->
      # TODO:
      # - what about if we only have a persitently stored index?
      if workingIndex = @indexWorkingCopies[indexName][indexKey]
        # TODO:
        # - set index up-to-date time
        # - make index complete
        delete @indexWorkingCopies[indexName][indexKey].$deputyUnreceived


    # Mark an index as incomplete, optionally over only the given keys
    invalidate: (indexKey) ->
      # TODO: