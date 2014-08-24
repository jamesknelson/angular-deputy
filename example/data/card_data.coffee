mod = angular.module 'memamug.data.card', []
mod.factory 'Card', [
  "$deputyFactory", "$messageChannel", "$restChannelFactory"
  ($deputyFactory,   $messageChannel,   $restChannelFactory) ->
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

    # Returns a $deputyFactory.Deputy
    cardDeputy = $deputyFactory 'Card',
      references: [
        { belongsTo: 'question' }
        { belongsTo: 'contact' }
      ]
      unique: [
        ['questionId', 'contactId']
      ]

    # Attempt to keep this window's card deputy in sync with any other open
    # in the same browser
    # By default copies the name of the deputy itself
    $messageChannel.start cardDeputy

    # Returns a $restChannelFactory.RestChannel
    # By default copies the name of the deputy itself
    cardService = $restChannelFactory cardDeputy,
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