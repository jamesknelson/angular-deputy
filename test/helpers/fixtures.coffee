fixtures =
  contacts: [
    {id: 0, active: true, facebookId: 0, notes: "Met at Alice'ss"}
    {id: 1, active: true, linkedinId: 1, notes: "Met at Bob's"}
    {id: 2, active: false, linkedinId: 5, facebookId: 6, notes: "Met at Charlie's"}
  ]
  questions: [
    {id: 0, type: "import", question: "What is this person's name?"}
    {id: 1, type: "custom", question: "What is this person's birthday?"}
  ]
  cards: [
    {id: 0, active: true, questionId: 0, contactId: 0, answer: 'Dave'}
    {id: 1, active: true, questionId: 1, contactId: 0, answer: 'February 30th 2088'}
    {id: 2, active: false, questionId: 0, contactId: 1, answer: 'Esther'}
    {id: 3, active: true, questionId: 1, contactId: 1, answer: 'Hundreds of years BC'}
    {id: 4, active: true, questionId: 0, contactId: 2, answer: 'Fred'}
    {id: 5, active: true, questionId: 1, contactId: 2, answer: 'Yesterday'}
  ]

do (fixtures) ->
  buildFixtureIndexes = (name) ->
    fixtures[name+'ById'] = {}
    fixtures[name].forEach (r) -> fixtures[name+'ById'][r.id] = r

  buildFixtureIndexes('contacts')
  buildFixtureIndexes('questions')
  buildFixtureIndexes('cards')

  null