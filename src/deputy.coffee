class Deputy

  Deputy.defaults =

    # The default number of records of each type to keep in the persistent cache
    cacheCapacity: 1000

    defaultIdProperty: 'id'

    defaultIndexNamer: (properties) ->
      properties = [properties] if !angular.isArray(properties)
      properties.map(
        (part, i) ->
          if i == 0 then part else part[0].toUpperCase() + part.substring(1)
      ).join('And')

    defaultIndexKeyGenerator: (model, indexDef) ->
      props = indexDef.properties
      (resource={}) ->
        props.map((p) -> String(resource[p])).join(',')
    
    generateHasManyModelName: (propertyName, modelName) ->
      if window.inflect and window.inflect.singularize
        singular = inflect.singularize(propertyName)
        singular[0].toUpperCase() + singular.substring(1)
      else
        throw new Error("Deputy: to enable generateHasManyServiceName, please place an inflector supporting the `singularize` function at `window.inflect`.")
    
    generateBelongsToModelName: (propertyName, modelName) ->
      idless = propertyName.substring(0, propertyName.length-2)
      idless[0].toUpperCase() + idless.substring(1)
    
    # When we need to query a service to embed referenced resources, by default
    # query using the referenced id for belongsTo, or the referencing id for
    # hasMany
    defaultForeignKeyProperty: (model, refDef) ->
      refDef.belongsTo+'Id'
    defaultBelongsToBuildQuery: (model, refDef) ->
      (resource) -> resource[refDef.foreignKeyProperty]

    defaultInverseForeignKeyProperty: (model, refDef) ->
      model.name[0].toLowerCase()+model.name.substring(1)+'Id'
    defaultHasManyBuildQuery: (model, refDef) ->
      (resource) -> resource[refDef.foreignKeyProperty]

  # Change the format of a `select` option into an array of value property
  # names and an object linking reference property names to their selected
  # references/values
  #
  # example:
  # [
  #   'answer'
  #   'active'
  #   'locked'
  #   question: ['question', 'type']
  #   contact:
  #     firstName: true
  #     lastName: true
  #     photos: ['url', 'active', 'uses']
  #
  # ->
  # {
  #   values: ['answer', 'active', 'locked']
  #   references: {
  #     question: { values: ['question', 'type'] }
  #     contact: {
  #       values: ['firstName', 'lastName'],
  #       references: {
  #         photos: { values: ['url', 'active', 'uses'] }
  #       }
  #     }
  #   }
  # }
  Deputy.normalizeSelector = (select, model) ->
    if angular.isString(select)
      select = [select]

    values = []
    references = {}

    if angular.isArray(select)
      for def in select
        if angular.isString(def)
          values.push def
        else
          obj = normalizeSelector(def, model)
          Array.prototype.push.apply(values, obj.values)
          angular.extend(references, obj.references)
    else
      # Assume `select` is an object
      for property, def of select
        if def == true
          values.push property
        else
          references[property] = normalizeSelector(def, model)

    values.push(model.id) unless (model.id in values)

    { values: values, references: references }


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




  # Attempt to change the state of the selected properties/resources to the
  # givein state. If queuing is required, returns a promise. If this change
  # is illegal, returns a rejected promise. Otherwise returns null.
  runOrQueueStateChange: (id, newState, normalizedSelector=null) ->
    # eg.
    # if current state is "current"
    # - "undeletable" is illegal
    # - "deleting" is immediate
    # if current state is "updating"
    # - "deleting" would be queued (and cause an error if updating resolves to nonexistent)
    # - "current" would be immediate
    # - "detached" would be illegal
    # if current state is "detached"
    # - "deleting" is immediate
    # - "current" is ???
    # - "updating" is ???
    # - "undeletable" is illedal