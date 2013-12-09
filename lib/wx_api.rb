# encoding: utf-8
require 'json'
require 'openssl'
require 'net/http'
require 'faraday'

module WeixinPublic

# this class is written based on the offical ducoment of Weixin platform, you can find the reference 
# at http://mp.weixin.qq.com/wiki/index.php
# good luck!
class WeixinAPIClient
  
  @@host_api = 'https://api.weixin.qq.com'
  def initialize(appid,app_secret,access_token=nil)
    @appid = appid
    @secret = app_secret
    @access_token = access_token
  end

  URL_ADVANCED = {
    :user_info  => "/cgi-bin/user/info",
    :menu       => "/cgi-bin/menu/create",
    :menu_get   => "/cgi-bin/menu/get",
    :user_list  => "/cgi-bin/user/get",
    :group_list => "/cgi-bin/groups/get",
    :user_change_group => "/cgi-bin/groups/members/update",
    :send => "/cgi-bin/message/custom/send",
  }

  def api_get_user_list(next_openid=nil)
    args = {}
    args = {next_openid:next_openid} if next_openid
    data = api_get(:user_list,args)
    return nil unless data
    data["data"]["openid"]
  end

  def api_get_user_info(openid)
    ret = api_get(:user_info,{openid:openid})
    return nil unless ret
    WeixinPublic::WeixinFan.new(oid:ret["openid"],nick_name:ret["nickname"],gender:ret["sex"],
                  country:ret["country"],province:ret["province"],city:ret["city"],
                  subscribe_time:Time.at(ret["subscribe_time"].to_i))
  end

  def api_send_message(oid,text)
    msg = {
      touser:oid,
      msgtype:"text",
      text:{content:text}
    }
    api_post(:send,msg)
  end

  def api_set_menu(menu)
    api_post(:menu,menu.to_json)
  end
  def api_get_menu
    data = api_get(:menu_get)
  end
  def api_get_group
    data = api_get(:group_list)
  end
  def api_change_group(oid,group_id)
    msg = {
      openid:oid,
      to_groupid:group_id
    }    
    data = api_post(:user_change_group,msg)
  end

  def get_api_token
    conn = Faraday.new(:url =>@@host_api) 
    response = conn.get "/cgi-bin/token?grant_type=client_credential" do |req|
      req.params['appid'] = @appid
      req.params['secret'] = @secret
    end
    @access_token = JSON.parse(response.body)["access_token"]
  end
  
  def access_token_updated=(block)
    @update_block = block
  end

  def api_get(url,args={})
    fire_update = false
    url = "#{URL_ADVANCED[url]}?"
    args.each{|k,v| url = url + "&#{k.to_s}=#{v.to_s}"}

    if !@access_token then
      get_api_token
      return nil unless @access_token
      fire_update = true
    end

    conn = Faraday.new(:url =>@@host_api) 
    response = conn.get url + "&access_token=#{@access_token}"
    ret = JSON.parse(response.body)
    if ret["errcode"] then #expired
      p ret
      if "42001"==ret["errcode"] then
        return nil unless get_api_token
        response = conn.get url + "&access_token=#{@access_token}"
        fire_update = true
      else
        return nil
      end
    end
    @update_block.call(@access_token) if (@update_block and fire_update)
    return ret 
  end

  def api_post(url,body)
    get_api_token unless @access_token
    conn = Faraday.new(:url => @@host_api)
    response = conn.post "#{URL_ADVANCED[url]}?access_token=#{@access_token}" do |req|
      req.body = body
    end
    p response.body
    return (JSON.parse(response.body)["errcode"] == 0)
  end
end

end