mod = angular.module 'deputy.model', []
mod.factory 'DeputyModel', ['$injector', ($injector) ->

  defProp = Object.defineProperty

  class DeputyModel
    constructor: (deputyOptions, options={}) ->
      if !options.name
        throw new Error("new DeputyModel: you must provide a name")

      # Default Values
      @readOnly = options.readOnly ? []
      @compute = options.compute ? {}
      @unique = options.unique ? []

      @name = options.name
      @id = options.id ? deputyOptions.defaultIdProperty

      # TODO:
      # build a list of which property names will cause which computed
      # properties to be updated
      @compute = {}

      # TODO:
      # When an object of this model is destroyed, we must also destroy all of
      # the models with dependent references
      @dependentReferences = []

      @references = {}
      options.references ?= []
      options.references.forEach (refOptions) =>
        refDef = {}

        if refOptions.hasMany
          refDef.type = "hasMany"
          refDef.embedProperty = refOptions.hasMany
          refDef.serviceName =
            refOptions.service or
            deputyOptions.generateHasManyServiceName(refOptions.hasMany, @name)
          refDef.endpointName =
            refOptions.endpoint or
            deputyOptions.generateHasManyEndpointName(refOptions.hasMany, @name)
          refDef.buildQuery =
            refOptions.buildQuery or
            deputyOptions.defaultHasManyBuildQuery(this, refOptions)

          inverseForeignKeyProperty =
            refOptions.inverseForeignKeyProperty or
            deputyOptions.defaultInverseForeignKeyProperty(this, refOptions)

          # An index is required on the specified property. We can't access the
          # associated service yet, but shedule a check the first time we try
          # to access it.
          defProp refDef, 'inverseForeignKeyProperty',
            configurable: true
            get: ->
              if refDef.service.$store.indexes[inverseForeignKeyProperty]
                defProp refDef, 'inverseForeignKeyProperty', value: inverseForeignKeyProperty
                inverseForeignKeyProperty
              else
                throw new Error("DeputyModel: an index is required on inverseForeignKeyProperty")

          if refOptions.dependent
            @dependentReferences.push refDef

        else if refOptions.belongsTo
          refDef.type = "belongsTo"
          refDef.embedProperty = refOptions.belongsTo
          refDef.foreignKeyProperty =
            refOptions.foreignKeyProperty or
            deputyOptions.defaultForeignKeyProperty(this, refOptions)
          refDef.serviceName =
            refOptions.service or
            deputyOptions.generateBelongsToServiceName(refOptions.belongsTo, @name)
          refDef.endpointName =
            refOptions.endpoint or
            deputyOptions.generateBelongsToEndpointName(refOptions.belongsTo, @name)
          refDef.buildQuery =
            refOptions.buildQuery or
            deputyOptions.defaultBelongsToBuildQuery(this, refOptions)

          if refOptions.dependent
            throw new Error("new DeputyModel: dependent belongsTo references are unsupported")

        else
          throw new Error("new DeputyModel: unknown reference type in #{@name}")

        # Define the `service` and `endpoint` properties lazily to get around
        # inevitable circular depedencies (belongsTo -> hasMany -> belognsTo)
        defProp refDef, 'service',
          configurable: true
          get: ->
            service = $injector.get(refDef.serviceName)
            defProp refDef, 'service', value: service
            service
        defProp refDef, 'endpoint',
          configurable: true
          get: ->
            endpoint = refDef.service[refDef.endpointName]
            defProp refDef, 'endpoint', value: endpoint
            endpoint

        @references[refDef.embedProperty] = refDef
]