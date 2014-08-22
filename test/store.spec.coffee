describe "getResourceWindow", ->
  describe "when only open resource window", ->
    it "should have associated working copy with use count of 1", ->

    it "should provide a nested window for a belongs to association", ->

    it "should update the nested belongs to window when it's foreign key changes", ->

    it "should provide a nested window for a has many association", ->

    describe "when fully disposed", ->
      it "should have no associated working copy", ->

      it "should not provide any nested windows for belongs to associations", ->

      it "should not provide any nested windows for has many assocations", ->

      describe "when used again", ->
        it "should have working copy", ->

        it "should still reflect updates to values", ->

        it "should provide an updated nested window if the foreign key has changed since disposal", ->

        it "should still update the nested belongs to window when it's foreign key changes", ->

  # ...