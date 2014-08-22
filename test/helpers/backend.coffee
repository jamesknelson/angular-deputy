setupBackend = ($httpBackend, fixtures) ->
  $httpBackend.when("HEAD", "/questions").respond()
  $httpBackend.when("TRACE", "/questions").respond()
  $httpBackend.when("OPTIONS", "/questions").respond()

  $httpBackend.whenGET("/questions").respond(fixtures.questions)

  # TODO: questions with embedded cards, and then embedded contact for cards

  fixtures.questions.forEach (r) ->
    $httpBackend.whenGET("/questions/#{r.id}").respond(r)

  # $httpBackend.whenGET("/accounts").respond(accountsModel);
  # $httpBackend.whenGET("/accounts/do-something").respond(accountsDoSomethingModel);
  # $httpBackend.whenJSONP("/accounts").respond(accountsModel);
  # $httpBackend.whenGET("/accounts/0,1").respond(accountsModel);
  # $httpBackend.whenGET("/accounts/messages").respond(messages);
  # $httpBackend.whenGET("/accounts/1/message").respond(messages[0]);
  # $httpBackend.whenGET("/accounts/1/messages").respond(messages);
  # $httpBackend.whenGET("/accounts/0").respond(accountsModel[0]);
  # $httpBackend.whenGET("/accounts/1").respond(accountsModel[1]);
  # $httpBackend.whenJSONP("/accounts/1").respond(accountsModel[1]);
  # $httpBackend.whenGET("/accounts/1/transactions").respond(accountsModel[1].transactions);
  # $httpBackend.whenGET("/accounts/1/transactions/1").respond(accountsModel[1].transactions[1]);

  # $httpBackend.whenGET("/info").respond(infoModel);
  # $httpBackend.whenGET("/accounts/1/info").respond(infoModel);
  # $httpBackend.whenPUT("/info").respond(function(method, url, data) {
  #   return [200, data, ""];
  # });

  # $httpBackend.whenGET("/accountsHAL").respond(accountsHalModel);
  # $httpBackend.whenPUT("/accountsHAL/martin").respond(function(method, url, data) {
  #   accountsHalModel[0] = angular.fromJson(data);
  #   return [200, data, ""];
  # });

  # // Full URL
  # $httpBackend.whenGET('http://accounts.com/all').respond(accountsModel);

  # $httpBackend.whenPOST("/accounts").respond(function(method, url, data, headers) {
  #   var newData = angular.fromJson(data);
  #   newData.fromServer = true;
  #   return [201, JSON.stringify(newData), ""];
  # });

  # $httpBackend.whenPOST("/accounts/1/transactions").respond(function(method, url, data, headers) {
  #   return [201, "", ""];
  # });

  # $httpBackend.whenDELETE("/accounts/1/transactions/1").respond(function(method, url, data, headers) {
  #   return [200, "", ""];
  # });

  # $httpBackend.whenDELETE("/accounts/1").respond(function(method, url, data, headers) {
  #   return [200, "", ""];
  # });

  # $httpBackend.whenPOST("/accounts/1").respond(function(method, url, data, headers) {
  #   return [200, "", ""];
  # });

  # $httpBackend.whenPUT("/accounts/1").respond(function(method, url, data, headers) {
  #   accountsModel[1] = angular.fromJson(data);
  #   return [201, data, ""];
  # });

  $httpBackend.whenGET("/error").respond ->
    [500, {}, ""]

  # return the status code given
  # e.g.: /error/404 returns 404 Not Found
  urlRegex = /\/error\/(\d{3})/
  $httpBackend.whenGET(urlRegex).respond (method, url, data, headers) ->
    [url.match(urlRegex)[1], {}, ""]
