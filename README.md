# angular-deputy

Angular-deputy manages access to and storage of your application's data.

## Development

### Prepare your environment

- Install Node.js
- Install global dev dependencies: `npm install -g coffee-script gulp karma-cli`
- Install local dev dependencies: `npm install` from project root directory
- Install javascript dependencies for testing: `bower install`

### Build & Test

- Build the project: `gulp build`
- Run the test once suite by calling `gulp test`
- Automatically re-build and re-test the project when source/test files change: `gulp tdd`

### Release

- Set release version in `package.json`
- Create a distribution build: `gulp dist`
- (?) Create a temporary branch for release
- Force add dist/*
- Add git tag corresponding to vefrion from `package.json`
- Push changes and new tag: `git push --tags`
- Publish bower package
- (?) Remove temporary branch
- Bump version in `package.json`, add `-SNAPSHOT`
- Commit "bumped version after release" to master