mod = angular.module 'deputy', [
  'deputy.model'
  'deputy.store'
]

angularDeputyOptions =

  # A base URL for all URLs handled by any resource service
  baseUrl: ''

  # If we aren't given a special way of naming a single non-object query
  # parameter, call it `id`
  resourceQueryGeneratorFactory: (model) ->
    (param) -> id: param

  # If we don't specify how to extract the id from a query or resource, assume
  # we can just do so using the "id" attribute of the associated model
  resourceIdExtractorFactory: (model) ->
    (query={}) -> query[model.id]


  indexQueryGeneratorFactory: (model, indexDef) ->
    props = indexDef.properties
    (param) ->
      if props.length == 1
        query = {}
        query[props[0]] = param
        query
      else
        throw new Error("Deputy: unable to generate query for end which requires multiple parameters. Please pass an object as query instead.")

  indexKeyExtractorFactory: (model, indexDef) ->
    props = indexDef.properties
    (query={}) ->
      props.map (p) -> query[p]


  guessHasManyEndpointName: (propertyName, modelName) ->
    'findBy'+modelName[0].toUpperCase()+modelName.substring(1)+'Id'

  hasManyQueryGeneratorFactory: (model, refDef) ->
    (resource) -> resource[refDef.foreignKeyProperty]


  guessBelongsToEndpointName: (propertyName, modelName) ->
    'get'

  belongsToQueryGeneratorFactory: (model, refDef) ->
    (resource) -> resource[refDef.foreignKeyProperty]

  # TODO: index range/order/filter support
  # function to get the list component of a returned index
  # function to get the total number of results from a returned index


mod.provider '$deputy', -> angular.extend(angularDeputyOptions, $get: RESTService)

RESTService = [
  '$http', '$rootScope', '$q', 'DeputyModel', 'DeputyStore'
  ($http,   $rootScope,   $q,   DeputyModel,   DeputyStore) ->

    # Utility to factor out the common parts of getter processing
    processGetActionOptions = (model, actionOptions, options) ->
      options = angular.extend({}, actionOptions, options)

      # De-sugar our data selector
      if options.select
        options._normalizedSelector = normalizeSelector(options.select, model)
      else if !options._normalizedSelector
        throw new Error("Deputy.get: `select` is required.")

      # Our query needs to be an object to pass through to $http
      if angular.isString(options.query) or angular.isNumber(options.query)
        options.query = actionOptions.queryGenerator(options.query)
      else
        options.query ?= {}

      options


    # Take a url with substitution positions marked with semi-colons.
    # Returns a function which turns query objects into substituted URLs
    # and another object of the remaining query parameters.
    urlBuilderFactory = (url) ->
      url = deputyOptions.baseUrl + url

      urlParams = {}
      url.split(/\W/).forEach (param) ->
        if !(new RegExp("^\\d+$").test(param)) and param and
            (new RegExp("(^|[^\\\\]):" + param + "(\\W|$)").test(url))
          urlParams[param] = true
      unescapedUrl = url.replace(/\\:/g, ':')

      (params) ->
        params = if params then angular.copy(params) else {}
        result =
          url: swapQueryIntoUrl(unescapedUrl, urlParams, params)
          query: params

    swapQueryIntoUrl = (url, urlParams, params) ->
      for urlParam, _ of urlParams
        val = params[urlParam] if params.hasOwnProperty(urlParam)
        if angular.isDefined(val) and val != null
          delete params[urlParam]
          encodedVal = encodeURI(val)
          url = url.replace new RegExp(":" + urlParam + "(\\W|$)", "g"),
            (match, p1) ->
              encodedVal + p1
        else
          url = url.replace new RegExp("(\/?):" + urlParam + "(\\W|$)", "g"),
            (match, leadingSlashes, tail) ->
              if tail.charAt(0) == '/' then tail else leadingSlashes + tail
      url

    # Add an endpoint to this deputy service
    generateEndpoint = (name, defn, defaults, store) ->

      model = store.model

      # We don't want to modify the original definition object in case the
      # definition is used for multiple endpoints
      defn = angular.copy(defn)

      action =
        if defn.action then defn.action
        else if Deputy[name] then name
        else if name.substring(0, 6) == 'findBy' then 'index'
        else throw new Error("new Dupty: #{name} endpoint has unknown action")

      defn.urlBuilder = urlBuilderFactory(
        if defn.url then defn.url
        else if Deputy[name] then model.name.toLowerCase()
        else name
      )

      # Remvoe unnecessary bits from defn
      delete defn.action
      delete defn.url

      # TODO: support unique indexes. These probably should be supported by
      #       get, not index - if available it lets us attempt to find the id
      #       by the indexed parameter instead of supplying it directly, even
      #       if the index is not complete.
      #       This will allow support for things like query by resource name
      #       instead of resource id, with makes pretty URLs possible.

      if action == "index"
        if name.substring(0, 6) == 'findBy'
          indexName = name.substring(6)
          defn.indexName = indexName[0].toLowerCase() + indexName.substring(1)

        indexDef = store.indexes[defn.indexName]

        defn.queryIndexKeyExtractor =
          defn.queryIndexKeyExtractor or
          defaults.queryIndexKeyExtractor or
          deputyOptions.defaultQueryIndexKeyExtractor(model, indexDef)
        defn.queryGenerator =
          defn.queryGenerator or
          defaults.indexQueryGenerator or
          deputyOptions.defaultIndexQueryGenerator(model, indexDef)

      else if action != "list"
        defn.queryIdExtractor =
          defn.queryIdExtractor or
          defaults.queryIdExtractor or
          deputyOptions.defaultQueryIdExtractor(model)
        defn.queryGenerator =
          defn.queryGenerator or
          defaults.resourceQueryGenerator or
          deputyOptions.defaultResourceQueryGenerator(model)

      RESTService[action](store, defn)

    class RESTService
      constructor: (name, options={}) ->
        if !options.endpoints
          throw new Error("new RESTService: you must provide endpoints")

        @$model = new DeputyModel deputyOptions,
          name: name
          references: options.references
          unique: options.unique
          compute: options.compute

        @$store = new DeputyStore deputyOptions, @$model,
          indexes: options.indexes
          cacheCapacity: options.cacheCapacity

        # TODO: listen to a websocket on a passed in URL for a stream of
        #       updates which we pass through handleResponse

        # Generate our endpoints
        for name, defn of options.endpoints
          defn = {} if defn == true
          this[name] = generateEndpoint(name, defn, options, @$store)

    # Creates endpoints for fetching a single resource
    # - method:   the HTTP method, defaults to GET
    # - url:      the URL to call the endpoint with (required)
    # - embedded: lists the referenced data which is embedded, and thus can
    #             supplied without calling other endpoints
    #
    # Other:
    # - queryGenerator:   generate a query object from a string/number
    # - queryIdExtractor: extract the desired id from query for cache retrieval
    RESTService.get = (store, actionOptions) ->
      model = store.model

      if actionOptions.embedded
        for reference in actionOptions.embedded
          if !model.references[reference]
            throw new Error("RESTService.get: unknown reference specified in `embedded`")

      actionOptions.method ?= 'GET'
      actionOptions.embedded ?= []

      # Run a HTTP GET on this endpoint's URL with the given query,
      # storing received data. If data is returned and it matches our query,
      # return the id.
      fetchRoot = (requestedId, query, body) ->
        {url, params} = actionOptions.urlBuilder(query)
        $http(
          method: actionOptions.method
          url: url
          query: params
          data: body
        ).then (response) ->
          receivedId = store.receiveData(response.data)

          if requestedId
            if !receivedId
              deleted = {}
              deleted[model.id] = requestedId
              store.receiveDelete(deleted)
              throw new Error("RESTService.get: fetched data no longer exists")
            else if requestedId != receivedId
              throw new Error("RESTService.get: endpoint returned wrong id")
          else if !receivedId
            throw new Error("RESTService.get: fetch did not return id")
          else
            receivedId

      fetchOutOfDateReferences = (storeWindow, refNames, refSelections, maxAge) ->
        outOfDate = storeWindow.resource.$getOutOfDate(refNames, maxAge)
        if outOfDate.length > 0
          $q.all refNames.map (refName) ->
            refDef = model.references[refName]

            endpointOptions =
              query: refDef.buildQuery(storeWindow.resource)
              _normalizedSelector: refSelections[refName]
              maxAge: maxAge

            if refDef.type == "belongsTo"
              endpointOptions.id = storeWindow.resource[refDef.foreignKeyProperty]

            if (Object.keys(endpointOptions.query).length == 0 and
                angular.isUndefined(endpointOptions.id))
              throw new Error("RESTService.get: empty query/id for selected reference")

            model[refName].endpoint(endpointOptions)
        else
          $q.when()

      # Return a resource
      #
      # - select:  choose what to download (required)
      # - query:   the query to pass through to the server
      # - id:      the specific id to return, defaults to an auto-generated id
      #            based on the query
      # - force:   force a refetch
      # - maxAge:  refetch once if the data is cached but older than specified
      (options={}) ->
        options = processGetActionOptions(model, actionOptions, options)
        query = options.query
        {values, references} = options._normalizedSelector

        # If possible, figure out what the desired resource's id is
        requestedId = options.id ? actionOptions.queryIdExtractor(query)

        # Figure out which selected data is available from this endpoint, and
        # which needs to be fetched from referenced endpoints
        rootSelected = values
        refSelected = []
        for refName in references
          if refName in actionOptions.embedded
            rootSelected.push refName
          else
            refSelected.push refName

        buildStoreWindow = (id) ->
          store.getResourceWindow(id, options._normalizedSelector)

        # Make available in this scope
        storeWindow = null

        # If possible, build window before fetching, so the resource will
        # already be in the store's working data store when we pass it to
        # receiveData
        if requestedId
          storeWindow = buildStoreWindow(requestedId)

        # Do a fetch on this endpoint's URL if specifically asked to, if we
        # don't know the requested resource's ID, or if the cached data for
        # that ID is out of date.
        isRootFetchRequired =
          options.force or
          !requestedId or
          storeWindow.resource.$isUnreceived() or
          storeWindow.resource.$getOutOfDate(rootSelected, options.maxAge).length > 0

        promise = if isRootFetchRequired
          # There is out of date data which can be returned directly by
          # this endpoint
          fetchRoot(requestedId, query, options.body).then (receivedId) ->

            # If we didn't know what we would receive, we still need to build
            # a storeWindow now that we do know.
            if !requestedId
              storeWindow = buildStoreWindow(receivedId)

            if storeWindow.resource.$getOutOfDate(rootSelected, options.maxAge).length > 0
              throw new Error("RESTService.get: selected data could not be fetched")

            # If we do a fetch on the root endpoint, we may receive new
            # keys for the referenced data, so we need to wait until they
            # would be stored before checking for out of date references
            fetchOutOfDateReferences(storeWindow, refSelected, references, options.maxAge)

        else
          fetchOutOfDateReferences(storeWindow, refSelected, references, options.maxAge)


        attachScope = (scope) ->
          storeWindow.register()
          scope.$on "$destroy", storeWindow.dispose
          storeWindow.resource

        promise = promise.then -> attachScope

        # Wait until after returning to dispose, so any attach called
        # immediately afterwards does not cause the store to move the
        # resource back into the cache
        promise.then -> setTimeout(storeWindow.dispose)

        # Sugar to make it easier to attach without waiting for the fetch
        # to complete, only available if ID is known from query
        if requestedId
          promise.attach = attachScope

        promise


    # Creates endpoints for fetching a collection of resources
    # - method:    the HTTP method, defaults to GET
    # - url:       the URL to call the endpoint with (required)
    # - embedded:  lists the referenced data which is embedded, and can thus be
    #              supplied without calling other endpoints.
    #              Note: currently an error is thrown if the user tries to
    #              select any referenced data not in here
    # - indexName: specify which index will be used from the store (required)
    #              When endpoint name starts with "findBy", defaults to the
    #              remainder of the endpoint name (with first letter lower
    #              cased)
    #
    # Other:
    # - queryGenerator:
    #     generate a query object from a string/number
    #     defaults to {id: query}
    # - queryIndexKeyExtractor:
    #     extract the required foreign key for the given index from a query
    #     object
    RESTService.index = (store, actionOptions={}) ->

      model = store.model

      if actionOptions.embedded
        for reference in actionOptions.embedded
          if !model.references[reference]
            throw new Error("RESTService.index: unknown reference specified in `embedded`")

      if !actionOptions.indexName
        throw new Error("RESTService.index: `indexName` is required!")

      actionOptions.method ?= 'GET'
      actionOptions.embedded ?= []

      fetchCollection = (requestedIndexKey, query, body) ->
        {url, params} = actionOptions.urlBuilder(query)
        $http(
          method: actionOptions.method
          url: url
          query: params
          data: body
        ).then (response) ->
          receivedIds = store.receiveData(
            response.data,
            actionOptions.indexName,
            requestedIndexKey
          )

          # TODO: check that received data's indexKey exists and
          #       matches the requested one


      # Return a collection of resources
      #
      # - select:  choose what to download (required)
      # - query:   the query to pass through to the server
      # - force:   force a refetch
      # - maxAge:  refetch once if the data is cached but older than specified
      #
      # TODO:
      # - query:    only return resources which match some query
      # - order:    the order in which resources should be sorted
      # - offest:   start form the nth returned resource
      # - limit:    the max number of resources to be returned
      # - prefetch: whether to automatically request adjacent windows once
      #             this main fetch is complete
      (options={}) ->
        options = processGetActionOptions(model, actionOptions, options)
        query = options.query
        {values, references} = options._normalizedSelector

        # Find what index key we're trying to get a list for
        requestedIndexKey = actionOptions.queryIndexKeyExtractor(query)
        if !requestedIndexKey
          throw new Error("RESTService.index: no index key can be read from query. Consider using list or partiallist instead.")

        # Build a list of all properties which will be on each resource
        selected = values
        for refName in references
          selected.push refName
          if refName not in actionOptions.embedded
            throw new Error("RESTService.index: reference #{refName} is not embedded, and so can't be selected")

        # Build window before fetching, so the index and resources will already
        # be in the store's working data store when we pass it to receiveData
        storeWindow = store.getIndexWindow(
          actionOptions.indexName,
          indexKey,
          options._normalizedSelector
        )

        # Do a fetch on this endpoint's URL if specifically asked to, if we
        # don't have the actual index yet, or if there are more than one out-
        # of-date resources in the collection
        isCollectionFetchRequired =
          options.force or
          storeWindow.collection.$isUnreceived()
        if !isCollectionFetchRequired
          outOfDateCount = storeWindow.collection.$getOutOfDateIds(selected, options.maxAge).length
          isCollectionFetchRequired = outOfDateCount > 1

        promise = if isCollectionFetchRequired or outOfDateCount == 1
          # Either the index is out of date, or there are multiple out of date
          # resources in the collection for this indexKey
          fetchCollection(requestedId, query, options.body).then (receivedId) ->
            if storeWindow.collection.$getOutOfDateIds(selected, options.maxAge).length > 0
              throw new Error("RESTService.get: selected data could not be fetched")
        else
          $q.when()


        attachScope = (scope) ->
          storeWindow.register()
          scope.$on "$destroy", storeWindow.dispose
          storeWindow.collection

        promise = promise.then -> attachScope

        # Wait until after returning to dispose, so any attach called
        # immediately afterwards does not cause the store to move the
        # resource back into the cache
        promise.then -> setTimeout(storeWindow.dispose)

        # Sugar to make it easier to attach without waiting for the fetch
        # to complete
        promise.attach = attachScope

        promise


    # Creates a special type of index endpoint which acts on the special "$all"
    # index, replacing it with each response
    RESTService.list = (store, actionOptions={}) ->
      # TODO:
      # Generate an appropriate index endpoint

    # Creates a special type of index endpoint which adds received resources to
    # the special "$all" index without replacing existing ones
    RESTService.partiallist = (store, actionOptions={}) ->

    # Creates endpoints for creating a resource or list of resources
    RESTService.post = (store, actionOptions={}) ->
      # TODO:
      # if model has any unique constraints,
      # - check to see if the store has an index for that constraint
      # - if so, and the store's index is marked as in date:
      #   - fail as duplicate if store can find it
      # - otherwise, post query
      #   - fail as duplicate if "conflict" is returned
      #   - otherwise the deputyHttp service will handle the response and
      #     updating the store
      # - return a liveObject to the created object, with field states set
      #   to saving:create, unless wait: true.
      # - assert wait == true *if* setting a unique field (where conflict is
      #   a possibility)
      # - if error, status will be set to error by deputyHttp. Types of error:
      #   * error:validation
      #   * error:server
      #   * error:connection
      (options={}) ->

    # Creates endpoints for deleting a resource or list of resources
    # TODO: it should be possible to delete from the working copy in the store,
    #       returning the deleted item, and then removing it from the
    #       persistent store or reinserting it into the working store once we
    #       receive a result.
    RESTService.delete = (store, actionOptions={}) ->
      (options={}) ->
        # TODO:
        # - send a delete request
        # - return a promise to the deleted id/ids which resolves when the
        #   request is complete
        # - deputyHttp will handle updating the store

    # Creates endpoints for updating a single resource
    RESTService.patch = (store, actionOptions={}) ->
      # TODO:
      # similar to post, except:
      # - don't fail as duplicate if the found resource is this resource
      # - give the option to transform the passed in body/response using
      #   $http's transformRequest / transformResponse config options
      # - don't return a liveObject, as we know the query so should be able
      #   to grab one from the store if required
      # - set all fields to saving:update instead of saving:create
      # - always return a promise which resolves upon success to nothing
      (options={}) ->

    RESTService
]