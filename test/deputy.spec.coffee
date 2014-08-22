describe "Deputy", ->
  # Variables available over this entire fn 
  Deputy = null
  $httpBackend = null

  # Load required modules
  beforeEach angular.mock.module("deputy")

  # Initi HTTP mock backend and angular-deputy
  beforeEach inject ($injector) ->

    $httpBackend = $injector.get("$httpBackend")
    setupBackend($httpBackend, fixtures)

    unless Deputy
      Deputy = $injector.get("Deputy")

  afterEach ->
    $httpBackend.verifyNoOutstandingExpectation()
    $httpBackend.verifyNoOutstandingRequest()

  describe "provider", ->
    # TODO: test that options set on the provider are passed throuh to relevant methods

  describe "constructor", ->
    # TODO: test that options set on the deputy constructor are passed through to endpoint factories
    
    it "should fail if no endpoints are provided"

    it "should build a model with name, references, unique and compute properties"

    it "should build a store with index and resourceIdExtractor properties"

    it "should create endpoints for each of the passed through endpoint definitions"

  describe "urlBuilder", ->
    it "should substitute parameters into the url"

    it "should not pass substituted parameters as query parameters"

  describe "normalizeSelector", ->
    # TODO: tests for individual parts, and full test for this:
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

  describe "get", ->
    it "should generate a query with the supplied queryGenerator", ->

    it "should extract requeseted ID with the supplied queryIdExtractor", ->

    it "should return a promise", ->

    describe "when successful", ->
      it "should resolve it's promise to an attach function", ->

      it "should return a LiveResource with the selected properties from it's attach function", ->

      it "should update the store"

    describe "when desired resource is unknown", ->
      it "should make a request", ->

      it "should fail if no data is received", ->

      it "should return a promise with no attach property", ->

    describe "when desired resource is known", ->
      it "should fail if the received ID doesn't match the requested ID", ->

      it "should delete the requested ID from the store if it couldn't be retrieved", ->

      it "should fail if no data is received", ->

      it "should return a promise with an attach property", ->

      describe "when resource is in date", ->
        it "should not make any requests", ->

      describe "when resource is in date and force: true", ->
        it "should make a root request", ->

        it "should make no reference requests", ->

      describe "when only selected values (no references) are out of date", ->
        it "should make a root request", ->

        it "should make no reference requests", ->

      describe "only multilpe non-embedded references are out of date", ->
        it "should make no root request", ->

        it "should make multiple reference requests", ->

      describe "only embedded references are out of date", ->
        it "should make a root request", ->

        it "should make no reference requests", ->

      describe "both embedded and non-embedded references are out of date", ->
        it "should make a root request first", ->

        it "should make a reference request following the root request", ->

    afterEach ->
      # Test that there are no pending HTTP requests after the above tests
      # return

  describe "index", ->


  # describe "post", ->
  #   it "should not throw an exception if a duplicate is added to a unique index"