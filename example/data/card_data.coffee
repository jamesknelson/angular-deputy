mod = angular.module 'memamug.data.card', []
mod.factory 'Card', ["Deputy", (Deputy) ->
  studyListOptions =
    action: 'partiallist'
    method: 'POST'
    force: true
    select: [
      'answer'
      'active'
      'locked'
      question: ['question', 'type']
      contact: [
        'firstName'
        'lastName'
        photos: ['url', 'active', 'uses']
      ]
    ]

  new Deputy 'Card',
    references: [
      { belongsTo: 'question' }
      { belongsTo: 'contact' }
    ]
    unique: [
      ['questionId', 'contactId']
    ]

    endpoints:
      get: true
      patch: true
      delete: true
      post: true
      list: true
  
      findByQuestionId: true
      findByContactId: true

      respond: studyListOptions
      undo: studyListOptions
]