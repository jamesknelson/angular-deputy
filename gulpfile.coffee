gulp = require "gulp"
fs = require "fs"
path = require "path"
extend = require "extend"
karma = require('karma').server
$ = require("gulp-load-plugins")(camelize: true)

karmaConf = require("./karma.conf.coffee").karmaOptions

# When using the grunt task, test the compiler's output instead of the input
karmaConf.files.pop()
karmaConf.files.push('dist/angular-deputy.js')

paths =
  coffee: ["src/**/*.coffee"]
  build: "dist"
  main: "angular-deputy.js"

gulp.task "lint", ->
  gulp.src(paths.coffee)
    .pipe($.newer(path.join(paths.build, paths.main)))
    .pipe($.coffeelint(
      max_line_length:
        level: "ignore"
    ))
    .pipe($.coffeelint.reporter())

gulp.task "coffee", ["lint"], ->
  gulp.src(paths.coffee)
    .pipe($.plumber()) # Keep going even after an error
    .pipe($.sourcemaps.init())
      .pipe($.coffee(sourceMap: true))
      .pipe($.concat(paths.main))
    .pipe($.sourcemaps.write('.'))
    .on("error", $.util.log)
    .on("error", $.util.beep)
    .pipe(gulp.dest(paths.build))

gulp.task "clean", ->
  gulp.src(paths.build, read: false).pipe($.rimraf())

gulp.task "build", ["coffee"]

gulp.task "test", ["build"], (done) ->
  karma.start extend({}, karmaConf, {singleRun: true}), done

gulp.task "dist", ["clean"], ->
  gulp.start "build"
  # TODO: minify
  # TODO: run tests on minified version

gulp.task "tdd", ["build"], (done) ->
  # Start a Karma server which re-runs tests when dist/tests change
  karma.start extend({}, karmaConf, {singleRun: false, autoWatch: true}), done

  # Re-build when the source files change
  gulp.watch paths.coffee, ["coffee"]
