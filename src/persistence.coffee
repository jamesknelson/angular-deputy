class PersistentCache
  constructor: (name, capacity) ->
    # TODO: use localForage
    # TODO: need a way to specify the ids which are in active use, and
    # thus should not be dropped from the cache when capacity is in reach.

    @cache = $cacheFactory("$deputyCache:#{name}", capacity: capacity)

  get: (id) ->
    @cache.get(id)

  put: (id, obj) ->
    @cache.put(id, obj)

  remove: (id) ->
    @cache.remove(id)