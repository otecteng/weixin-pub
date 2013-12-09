# encoding: utf-8
require "weixin_public/version"
require 'digest'
require 'json'
require 'openssl'
require 'net/http'
require 'nokogiri'
require 'faraday'


module WeixinPublic

#this class is hack of http protocol of Weixin Web site, any upgrade of the service might effect its working
#this package only wrapp part of the functions, including fans manage and message manage, but, be careful! 
class WeixinObject
  def initialize(params = nil)
    if params
    params.each { |var,val| self.send "#{var}=", val if self.class.instance_methods.include?(var.to_sym)}
    end
  end

  def to_hash
    hash = {}
    instance_variables.each {|var| hash[var.to_s.delete("@")] = instance_variable_get(var) if var.to_s != "@id" }
    hash
  end
end
class AppFile < WeixinObject
  attr_accessor :file_id,:name,:type,:size,:update_time,:play_length
end
class AppMsg < WeixinObject
  attr_accessor :app_id,:title,:time,:file_id,:content_url
end

class WeixinFan < WeixinObject
  attr_accessor :id,:fake_id,:nick_name,:remark_name,:group_id,:user_name,:signature,
                :city,:province,:country,:gender,:oid,:subscribe_time
  def initialize(params = nil)
    super(params)
    self.fake_id = id if id
  end
end

class WeixinGroup < WeixinObject
  attr_accessor :id,:name,:remark_name,:cnt
end

class WeixinPubUser < WeixinObject
  attr_accessor :nick_name,:fake_id,:username,:service_type,:is_wx_verify,:signature,:country,:province,:city,:verifyInfo,:bindUserName,:account,:total_friend_cnt,
                :appid,:plugin_token,:is_dev_reply_open,:is_quick_reply_open,:is_biz_menu_open,
                :original_username,:app_id,:app_secret,:callback_url,:callback_token,
                :media_ticket
end

class WeixinMessage < WeixinObject
  attr_accessor :id,:type,:fakeid,:nick_name,:date_time,:content,:source,:msg_status,:has_reply,:refuse_reason

  def filePath
    file_type = {"2"=>"jpg","3"=>"mp3","4"=>"mp4"}[@type]
    "#{@id}.#{file_type}"
  end

  def fileType
    filetype={"2"=>"image/jpg","3"=>"audio/mp3","4"=>"video/mp4"}[@type]
  end
end


class WeixinPubClient
  @@host = 'https://mp.weixin.qq.com'
  URL_LIST = {
    :login    => "/cgi-bin/login",
    :home     => "/cgi-bin/home?t=home/index",
    :advance  =>"/cgi-bin/advanced?action=dev&t=advanced/dev",
    :messages =>"/cgi-bin/message?t=message/list",
    :fans     =>"/cgi-bin/contactmanage?t=user/index",

    :filepage =>"/cgi-bin/filepage?t=media/list",
    :service  =>"/cgi-bin/store?action=index&t=service/index",
    :settings =>"/cgi-bin/settingpage?t=setting/index&action=index",
    :mode_dev =>"/cgi-bin/advanced?action=dev&t=advanced/dev",
    :mode_switch=>"/cgi-bin/skeyform?form=advancedswitchform",
    :talk     =>"/cgi-bin/singlesendpage?t=message/send",
    :contact  =>"/cgi-bin/getcontactinfo?t=ajax-getcontactinfo",
    :callback =>"/cgi-bin/callbackprofile?t=ajax-response",
    :appmsg_r =>"/cgi-bin/appmsg?t=media/appmsg_list&action=list",    
    :appmsg_w =>"/cgi-bin/operate_appmsg",
    :send_single   =>"/cgi-bin/singlesend?t=ajax-response",
    :send_mass     =>"/cgi-bin/masssend?t=ajax-response",
    :fans_edit=>"/cgi-bin/modifycontacts",
    :avatar_w =>"/cgi-bin/filetransfer?action=upload_material"
  }
  
  def self.create(user)
    return WeixinPubClient.new(user.wx_user,user.wx_pswd)
  end

  def initialize(username,password,appid=nil,app_secret=nil,access_token=nil)
    @username = username
    @password = password
    @cookie = ""
    @conn = Faraday.new(:url => 'https://mp.weixin.qq.com')
    @access_token = access_token
    @conn_multipart = Faraday.new(:url => 'https://mp.weixin.qq.com') do |faraday|
      faraday.request :multipart
      faraday.adapter :net_http      
    end
  end
  

  def login(username=nil,password=nil)
    @username = username if username
    @password = password if password
    puts "login with #{@username}-------#{@password}"
    pwd = Digest::MD5.hexdigest(@password)

    params = {"username"=>@username,"pwd"=>pwd,"imgcode"=>'',"f"=>'json'} 
    ret = request(:post,URL_LIST[:login],params,referer(:login))
    return 'login failed' if !ret.headers["set-cookie"] 
    ret.headers["set-cookie"].split(',').each do |c|
      @cookie << c.split(';')[0] <<";"
    end
    msg = JSON.parse(ret.body)["ErrMsg"]
    @token = msg[msg =~ /token/..-1].split('=')[1]
    ret = request(:get,URL_LIST[:home],{},@@host)
    return ret.status.to_s
  end

  def get_home_info # we do not use it
    return if !@cookie && login(@username,@password) =~ /failed/
    ret = request(:get,"#{URL_LIST[:home]}&f=json",{},referer(:home))
    info = JSON.parse(ret.body)
  end

  def get_settings
    return if !@cookie && login(@username,@password) =~ /failed/
    ret = request(:get,"#{URL_LIST[:settings]}&f=json",{},referer(:settings))
    info = JSON.parse(ret.body)
    media_ticket=info["base_resp"]["media_ticket"]
    info_user = info["user_info"]
    info_setting = info["setting_info"]
    @user = WeixinPubUser.new(
      media_ticket:media_ticket,
      nick_name:info_user["nick_name"],
      fake_id:info_user["fake_id"],
      service_type:info_user["service_type"],
      signature:info_setting["intro"]["signature"],
      country:info_setting["country"],
      province:info_setting["province"],
      total_friend_cnt:info_setting["total_fans_num"],
      username:info_setting["username"],            
      original_username:info_setting["original_username"],
    )   
    ret = request(:get,"#{URL_LIST[:advance]}&f=json",{},referer(:advance))
    info = JSON.parse(ret.body)["advanced_info"]
    @user.is_quick_reply_open = info["is_quick_reply_open"]
    @user.is_dev_reply_open = info["is_dev_reply_open"]
    info=info["dev_info"]
    @user.app_id = info["app_id"]
    @user.app_secret = info["app_key"]
    @user.callback_url= info["callback_url"]
    @user.callback_token=info["callback_token"]
    
    return @user
  end

  def get_fans(fan_newest_id=nil,type=0,groupid=0)
    return if !@cookie && login(@username,@password) =~ /failed/
    i,ret = 0,[]
    loop do
      res = request(:get,
        "#{URL_LIST[:fans]}&pagesize=50&pageidx=#{i}&type=#{type}&groupid=#{groupid}&f=json",{},
        referer(:fans))
      begin
        data = JSON.parse(res.body)
        fans = JSON.parse(data["contact_list"])["contacts"].map {|f| WeixinFan.new(f)}
        break if fans.length == 0
        if fan_newest_id
          idx = fans.index{|fan| fan.id.to_i == fan_newest_id.to_i}
          if idx
            fans = fans[0,idx]
            exit = true
          end
        end
        ret = fans + ret    
        break if exit     
        i += 1
      rescue Exception => e
        p e
        break
      end
    end
    ret
  end

  def get_messages(lastmsgid=0,count=20)
    return if !@cookie && login(@username,@password) =~ /failed/
    lastmsgid = lastmsgid ||= 0
    ret,offset =[], 0
    loop do
      res = request(:get,"#{URL_LIST[:messages]}&offset=#{offset}&count=#{count}&day=7&f=json",{},nil)
      messages = JSON(JSON.parse(res.body)["msg_items"])["msg_item"].map {|m| WeixinMessage.new(m)} 
      break if messages.length == 0
      if messages[-1].id <= lastmsgid
        idx = messages.index{|m| m.id == lastmsgid}
        messages = messages[0,idx]
      end
      ret = ret + messages
      offset = offset + count
    end
    ret
  end
#/cgi-bin/singlesendpage?t=message/send&action=index&tofakeid=3153415&token=1818029131&lang=zh_CN&f=json
  def get_talk(fakeId)
    return if !@cookie && login(@username,@password) =~ /failed/              
    ret = request(:get,"#{URL_LIST[:talk]}&action=index&tofakeid=#{fakeId}&f=json",{},referer(:talk)).body
    messages = JSON.parse(ret)["page_info"]["msg_items"]["msg_item"]
    ret = []
    messages.each do |m| 
      ret << WeixinMessage.new(m)
      ret[-1].date_time = Time.at(m["date_time"].to_i)
    end
    ret
  end
  
  def get_contactor(fakeId)
    return if !@cookie && login(@username,@password) =~ /failed/
    contact_info = JSON.parse(request(:post,"#{URL_LIST[:contact]}&fakeid=#{fakeId}&f=json",{},referer(:contact)).body)["contact_info"]
    ret = WeixinFan.new(contact_info)
    ret.id = ret.fake_id = fakeId
    ret
  end

  def get_dev_status
    return get_settings.is_dev_reply_open.to_i == 1
  end
  #type:1 -edit mode 2 -dev mode  4 -auto-reply
  def set_dev_mode(type=1,on_off = 0) 
    return nil if !@cookie && login(@username,@password) =~ /failed/
    ret = request(:post,URL_LIST[:mode_switch],{:flag=>on_off,:type=>type,:ajax=>1},nil)
  end
  
  def set_dev_callback(url, token)
    return nil if !@cookie && login(@username,@password) =~ /failed/
    ret = request(:post,"#{URL_LIST[:callabck]}&lang=zh_CN",{:url=>url,:callback_token=>token,:ajax=>1},nil)
  end

  def switch_dev_mode
    set_dev_mode(4,0)
    set_dev_mode(1,0)
    set_dev_mode(2,1)
  end

  def get_file_lst(type=2,count=50)
    return nil if !@cookie && login(@username,@password) =~ /failed/
    url = "#{URL_LIST[:filepage]}&begin=0&count=#{count}&type=#{type}&f=json"
    ret = JSON.parse(request(:get,url,{},referer(:filepage)).body)
    ret["page_info"]["file_item"].map do |i|
      AppFile.new(i)
    end
  end

  def get_appmsg_lst(type=10,count=20)
    return nil if !@cookie && login(@username,@password) =~ /failed/
    url = "#{URL_LIST[:appmsg_r]}&begin=0&count=#{count}&type=#{type}&f=json"
    ret = JSON.parse(request(:get,url,{},referer(:appmsg_r)).body)
    ret["app_msg_info"]["item"].map do |i|
      AppMsg.new(i)
    end
  end

  def send_message(content,reciever,type="1")
    return if !@cookie && login(@username,@password) =~ /failed/
    body = {"error"=>false,"ajax"=>1,"f"=>"json","type"=>type,"tofakeid"=>reciever}
    case type
    when "1"
      body["content"] = content
    when "2"
      body["file_id"] = content
      body["fileid"] = content
    when "10"
      body["app_id"] = content
      body["appmsgid"] = content    
    end
    ret = request(:post,URL_LIST[:send_single],body,referer(:send_single))
    p ret
    return ret.status == 200
  end
  
  def send_mass(message)
    return if !@cookie && login(@username,@password) =~ /failed/
    body = {"type"=>1,"content"=>message,"error"=>"false","needcomment"=>0,
            "groupid"=>-1,"sex"=>0,"country"=>'',"city"=>'',"province"=>'',"synctxweibo"=>0,"synctxnews"=>0,
          "ajax"=>1}
          #"https://mp.weixin.qq.com/cgi-bin/masssendpage"
    ret = request(:post,URL_LIST[:send_mass],body,referer(:send_mass))
  end

  def change_group(fakeId,contacttype=1) # default, put into blacklist
    return if !@cookie && login(@username,@password) =~ /failed/
    body = {"contacttype"=>contacttype,"tofakeidlist"=>fakeId,"action"=>"modifycontacts"}
    ret = request(:post,URL_LIST[:fans_edit],body,referer(:fans_edit))
  end




  def request(method,url,params,referer)
    @conn.headers["Cookie"] = @cookie
    @conn.headers["Referer"] = referer if referer
    begin
    if method == :post then
      ret = @conn.post do |req|
        req.url url
        req.body = params
        req.body['token']=@token if @token
      end
    else
      ret = @conn.get do |req|
        @conn.params = params
        req.url url
        @conn.params['token']=@token
        @conn.params['lang']="zh_CN"
      end
    end
  rescue=>e
    p e
    return nil
  end
    ret
  end




  def map_fans(gifts,time_created=nil)#map fans from gifts id to fakeid
    ret = []
    messages = {}    
    get_fans().each do |fan|
      msg = get_messages_text(fan.fakeId)
      messages[fan.fakeId] = msg
    end
    gifts.each do |g|
      messages.each do |k,v|
        if v.find { |i| i.content =~ /#{g}/} then
          ret << {:giftId=>g,:fakeId=>k} 
          messages.delete(k)
          break
        end
      end
    end
    ret
  end

  def get_messages_number_new(lastmsgid)
    return if !@cookie && login(@username,@password) =~ /failed/
    res = request(:post,"/cgi-bin/getnewmsgnum?t=ajax-getmsgnum&lastmsgid=#{lastmsgid}")
    ret = JSON.parse(res.body)["newTotalMsgCount"]
  end
    
  def get_groups
    return if !@cookie && login(@username,@password) =~ /failed/
    res = request(:get,
        "/cgi-bin/contactmanage?t=user/index&pagesize=10&pageidx=0&type=0&groupid=0&lang=zh_CN",{},
        'https://mp.weixin.qq.com/cgi-bin/contactmanage?t=user/index&pagesize=10&pageidx=0&type=0&groupid=0&lang=zh_CN')
    data = JSON.parse(JSON.parse(Nokogiri::HTML(res.body))["group_list"])["groups"].map{ |f| WeixinGroup.new(f) }
  end


  def get_nickname
    return "" if !@user
    return @user.nick_name
  end
  
  def set_callback(callback,token)
    return nil if !@cookie && login(@username,@password) =~ /failed/
    res = request(:post,
                  "/cgi-bin/callbackprofile?t=ajax-response&lang=zh_CN",
                  {  url:callback,
                     callback_token:token},
                  nil)
    JSON.parse(res.body)['ret']=="0"
  end

  def url_avatar
    "/cgi-bin/getheadimg?fakeid=#{@fakeid}&token=#{@token}"
  end
  def url_code_qr  
    "/cgi-bin/getqrcode?fakeid=#{@fakeid}&style=1&action=download&token=#{@token}"
  end  
  def referer(url)
    "#{@@host}#{URL_LIST[url]}"
  end
  def user
    @user
  end
end

end