mod = angular.module 'memamug.data.contact', []
mod.factory 'Contact', ["Deputy", (Deputy) ->
  selectAll = [
    'notes'
    'active'
    'firstName'
    'lastName'
    'company'
    'position'
    'birthday'
    'source'
    cards: [
      'answer'
      'active'
      question: ['question']
    ]
  ]

  new Deputy 'Contact',
    readOnly: [
      'linkedinId'
      'facebookId'
    ]
    compute:
      firstName: [cards: ['answer', question: ['question']], (cards) ->
        # TODO: think of another way to do this. This will probably be awfully
        #       slow, but trying to keep two separate pieces of data in different
        #       resources in sync with every change also blows.
      ]
      lastName: [

      ]
      company: [

      ]
      position: [

      ]
      birthday: [

      ]
      source: ['linkedinId', 'facebookId', (linkedinId, facebookId) ->

      ]
    references: [
      { hasMany: 'photos', service: 'Photo', dependent: 'destroy' }
      { hasMany: 'cards', service: 'Card', dependent: 'destroy' }
    ]
    index: [
      'source'
      'active'
      ['source', 'active']
    ]
    endpoints:
      get:
        select: selectAll

      list:
        select: selectAll

      patch: true
      delete: true

      findBySource: true
      findByActive: true
      findBySourceAndActive: true
]