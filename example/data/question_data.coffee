mod = angular.module 'memamug.data.question', []
mod.factory 'Question', ["Deputy", (Deputy) ->
  new Deputy 'Question',
    references: [
      { hasMany: 'cards', service: 'Card', dependent: 'destroy' }
    ]
    endpoints:
      get: true
      patch: true
      post: true
      delete: true
      list: true
]