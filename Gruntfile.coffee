module.exports = (grunt) ->
  grunt.initConfig
    pkg: grunt.file.readJSON "package.json"
    clean:
      main:
        ["dist/**/*"]
    coffee:
      main:
        files: [
          expand: true,
          src: ["{bin,routes,app}/*.coffee"],
          dest: "dist/",
          ext: ".js"
        ]
        options:
          sourceMap: true
          sourceMapDir: "dist/sourcemap"
    copy:
      main:
        files: [
          expand: true,
          src: ["public/**", "views/**", "package.json", "LICENSE.txt", "!public/content/**"],
          dest: "dist/"
        ]


  grunt.loadNpmTasks 'grunt-contrib-coffee'
  grunt.loadNpmTasks 'grunt-contrib-clean'
  grunt.loadNpmTasks 'grunt-contrib-copy'
  grunt.registerTask 'default', ['clean:main', 'coffee', 'copy:main']
