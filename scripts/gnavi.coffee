
BASE_URL = 'https://zunda-api.herokuapp.com'
PATH_GEO_CODER = '/api/yahoo_map/geo_coder'
PATH_CATEGORY = '/api/gnavi/category_small_search'
PATH_SEARCH_REST = '/api/gnavi/search_rest'
URL_GEO_CODER = BASE_URL + PATH_GEO_CODER
URL_CATEGORY = BASE_URL + PATH_CATEGORY
URL_SEARCH_REST = BASE_URL + PATH_SEARCH_REST
GNAVI_KEY_ID = process.env.GNAVI_KEY_ID

module.exports = (robot) ->

  robot.hear /^ぐるなび\s+(.+)\s+(.+)/i, (robot_res) ->

    out_msg = '\n'
    in_address = robot_res.match[1]
    in_category = robot_res.match[2]

    req_gc = robot_res.http(URL_GEO_CODER).query(query: in_address).get()
    req_ct = robot_res.http(URL_CATEGORY).get()
    coordinates = []
    cat_cd = ""
    Promise.all [req_gc, req_ct].map get
    .then (results)->
      for i, result of results
        for path, json of result
          if path.indexOf(PATH_GEO_CODER) == 0
            coordinates = get_coordinates json
          if path.indexOf(PATH_CATEGORY) == 0
            cats = get_categories json
            cat_cd = get_category_code in_category, cats
    .then ()->
      if cat_cd isnt ""
        if coordinates isnt [] and Object.keys(coordinates).length != 0
          params = {}
          params['category_s'] = cat_cd
          params['latitude'] = coordinates[1]
          params['longitude'] = coordinates[0]
          params['keyid'] = GNAVI_KEY_ID
          params['range'] = 5
          req_gc = robot_res.http(URL_SEARCH_REST).query(params).get()
          get req_gc
          .then (result)->
            url = Object.keys(result)[0]
            rests = Object.values(result)[0].result.rest
            for rest in rests
              image = rest.image_url.shop_image1
              out_msg += ("▪️ <#{rest.url}|#{rest.name}>\n")
              out_msg += (rest.address + '\n')
              unless Object.keys(image).length == 0
                out_msg += (image + '\n')
            robot_res.reply out_msg
        else
          robot_res.reply "\n住所がよくわからないなあ。"
      else
        robot_res.reply "\nカテゴリがよくわからないなあ。\n「ぐるなび　カテゴリ」でカテゴリの一覧を表示できるよ。"
    .catch (error)->
      robot.logger.info "error", error


  robot.hear /^ぐるなび$/i, (robot_res) ->
    robot_res.reply "「ぐるなび 住所 カテゴリ」だよ"

  robot.hear /^ぐるなび\s+カテゴリ$/i, (robot_res) ->
    req_ct = robot_res.http(URL_CATEGORY).get()
    get req_ct
    .then (result)->
      json = result[PATH_CATEGORY]
      cats = get_categories json
      # out_msg = '\n'
      names = []
      for cat in cats
        names.push cat.category_s_name
        # out_msg += "#{cat.category_s_name} / "
      robot_res.reply "\n#{names.join(' / ')}"


get_categories = (json) ->
  json.result.category_s

get_category_code = (name, categories) ->
  result = ""
  for i, category of categories
    if category.category_s_name == name
      result = category.category_s_code
      break
  result

get_coordinates = (json) ->
  if json.result.ResultInfo.Count > 0
    coordinates = json.result.Feature[0].Geometry.Coordinates.split(",")
  else
    coordinates = []
  coordinates

get = (request)->
  new Promise (resolve)->
    request (err, response, body) ->
      if err
        reject("NG")
      else
        result = {}
        path = response.req.path
        json = JSON.parse body
        result[path] = json
        resolve(result)
