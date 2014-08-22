# TODO: set up a big test which uses all the features, using the following model:

#   studyListOptions =
#     action: 'partiallist'
#     method: 'POST'
#     force: true
#     select: [
#       'answer'
#       'active'
#       'locked'
#       question: ['question', 'type']
#       contact: [
#         'firstName'
#         'lastName'
#         photos: ['url', 'active', 'uses']
#       ]
#     ]

#   new Deputy 'Card',
#     references: [
#       { belongsTo: 'question' }
#       { belongsTo: 'contact' }
#     ]
#     unique: [
#       ['questionId', 'contactId']
#     ]
#     endpoints:
#       get: true
#       patch: true
#       delete: true
#       post: true
#       list: true
#       findByQuestionId: true
#       findByContactId: true
#       respond: studyListOptions

# ####
  
#   new Deputy 'Question',
#     references: [
#       { hasMany: 'cards', service: 'Card', dependent: 'destroy' }
#     ]
#     endpoints:
#       get: true
#       patch: true
#       post: true
#       delete: true
#       list: true

# ####

#   selectAll = [
#     'notes'
#     'active'
#     'name'
#     'source'
#     cards: [
#       'answer'
#       'active'
#       question: ['question']
#     ]
#   ]

#   new Deputy 'Contact',
#     readOnly: [
#       'linkedinId'
#       'facebookId'
#     ]
#     compute:
#       name: [cards: ['answer', question: ['question']], (cards) ->
#         # TODO: think of another way to do this. This will probably be awfully
#         #       slow, but trying to keep two separate pieces of data in different
#         #       resources in sync with every change also blows.
#       ]
#       source: ['linkedinId', 'facebookId', (linkedinId, facebookId) ->

#       ]
#     references: [
#       { hasMany: 'cards', service: 'Card', dependent: 'destroy' }
#     ]
#     index: [
#       'source'
#       'active'
#       ['source', 'active']
#     ]
#     endpoints:
#       get:
#         select: selectAll
#       list:
#         select: selectAll
#       patch: true
#       delete: true
#       findBySource: true
#       findByActive: true
#       findBySourceAndActive: true

# TESTS:
# - can't add another card with existing questionId, contactId