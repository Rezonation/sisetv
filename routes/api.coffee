express = require 'express'
router = express.Router()
passport = require 'passport'
_ = require 'lodash'
multer = require 'multer'
upload = multer dest: 'temp/'
users = require '../app/users'
config = require '../app/config'
Slide = require '../app/slide'
User = require '../app/user'
fs = require 'fs'
bcrypt = require 'bcrypt-nodejs'
storage = require 'node-persist'
storage.initSync()

randomString = (len, charSet) ->
  charSet = charSet or 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789'
  st = ''
  for i in [0..len]
    randomPoz = Math.floor Math.random() * charSet.length
    st += charSet.substring randomPoz,randomPoz+1
  return st

router.use (req, res, next) ->
  res.respond = (data) ->
    res.json data: data
  res.fail = (msg) ->
    res.json error: msg
    res.status 400
  next()


router.get "/getContent", (req, res) ->
  content =
    content: []
    lastmodified: storage.getItemSync('lastmodified') or 1
  for user in users.getUsers()
    for slide in user.data.slides
      if slide.data.hidden
        continue
      content.content.push
        url: "content/#{slide.data.name}"
        type: slide.data.type
        delay: slide.data.duration
  res.json content

router.get "/getConfig", (req, res) ->
  res.json config.getConfig()

router.post "/registerUser", (req, res) ->
  if !req.body.registerID
    req.flash 'error', 'No register link ID!'
    return res.redirect '/admin'

  if !req.body.username or !req.body.password
    req.flash 'error', 'No username or password!'
    return res.redirect '/admin'

  for u in users.getUsers()
    if !u.data.registered and u.data.registerID == req.body.registerID
      u.data.username = req.body.username
      u.data.password = bcrypt.hashSync req.body.password
      u.data.registered = true
      users.save()
      req.login u, () ->
        return res.redirect '/admin/index'
  req.flash 'error', 'Invalid register link ID!'
  res.redirect '/admin'

router.use (req, res, next) ->
  if !req.user
    req.flash "error", "You need to be logged in to perform this action!"
    res.redirect "/admin/index"
  else
    next()

router.get '/logout', (req, res) ->
  req.logout()
  res.redirect '/admin'

router.get "/getUser", (req, res) ->
  res.respond req.user

router.post '/setSlides', (req, res) ->
  req.user.data.slides = req.body.slides.map (s) -> new Slide s
  users.save () ->
    storage.setItemSync('lastmodified', Date.now());
    res.respond req.user.data.slides

router.post '/addSlide', upload.single('file'), (req, res) ->
  if !req.body.duration
    req.body.duration = 10
  if !req.file
    req.flash 'error', 'No file uploaded!'
    return res.redirect '/admin'
  user = -1
  for u,i in users.getUsers()
    if u.data.username == req.user.data.username
      user = i
      break
  data =
    duration: parseInt req.body.duration
  data.fileName = req.file.originalname
  data.filePath = req.file.path
  if req.body.user
    if !req.user.data.admin
      fs.unlink req.file.path
      req.flash 'error', 'You need to be an admin to perform this action!'
      return res.redirect '/admin'
    user = req.body.user
  if user >= users.getUsers().length or user < 0
    fs.unlink req.file.path
    req.flash 'error', 'Could not find user!'
    return res.redirect '/admin'
  user = users.getUsers()[user]
  user.addSlide data, (err) ->
    users.save()
    storage.setItemSync('lastmodified', Date.now());
    if err
      req.flash 'error', err
    if user == req.user
      res.redirect '/admin/cc'
    else
      res.redirect '/admin/admin'
    fs.unlink req.file.path if fs.existsSync path

router.post '/deleteSlide', (req, res) ->
  if not req.body.id?
    return res.fail 'No slide ID provided!'
  user = -1
  for u,i in users.getUsers()
    if u.data.username == req.user.data.username
      user = i
      break
  if req.body.user
    if !req.user.data.admin
      return res.fail 'You need to be an admin to perform this action!'
    user = req.body.user
  user = users.getUsers()[user]
  if user >= users.getUsers().length or user < 0
    return res.fail 'Could not find user!'
  user.deleteSlide req.body.id, (err) ->
    storage.setItemSync('lastmodified', Date.now());
    if err
      return res.fail err
    users.save () ->
      res.respond user.data.slides


###
  ADMIN ONLY
###
router.use (req, res, next) ->
  if !req.user.data.admin
    req.flash "error", "You need to be an admin to perform this action!"
    res.redirect "/admin/index"
  else
    next()

router.post '/createRegisterLink', (req, res) ->
  if !req.body.displayName
    return res.fail 'No display name given!'
  code = randomString(30)
  users.createUser { displayName: req.body.displayName, registerID: code },
    () ->
      res.redirect '/admin/admin'


router.get '/getUsers', (req, res) ->
  res.respond users.getUsers()

router.post '/setUsers', (req, res) ->
  users.setUsers(req.body.users.map (u) -> new User u)
  users.save () ->
    res.respond users.getUsers()

router.post '/addUser', (req, res) ->
  if !req.body.username or !req.body.password
    return res.fail 'Missing username or password!'
  users.createUser req.body, () ->
    res.respond users.getUsers()

router.post '/deleteUser', (req, res) ->
  if !req.body.id
    return res.fail 'No user ID provided!'
  userList = users.getUsers()
  if req.body.id < 0 or req.body.id >= userList.length
    return res.fail 'Invalid user ID!'
  if userList[req.body.id].data.admin
    return res.fail 'The admin account cannot be deleted!'
  userList.splice req.body.id, 1
  users.save () ->
    res.respond users.getUsers()

module.exports = router