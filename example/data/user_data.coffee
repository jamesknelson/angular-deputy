mod = angular.module 'memamug.data.user', []
mod.factory 'User', ["Deputy", (Deputy) ->
  new Deputy 'User',
    endpoints:
      get: true
      patch: true
      delete: true
]