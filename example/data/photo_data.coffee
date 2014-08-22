mod = angular.module 'memamug.data.photo', []
mod.factory 'Photo', ["Deputy", (Deputy) ->
  new Deputy 'Photo',
    references: [
      { belongsTo: 'contact' }
    ]
    endpoints:
      get: true
      patch: true
      findByContactId: true
]