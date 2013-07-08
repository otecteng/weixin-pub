require "weixin_public/version"
require 'digest'
require 'json'
require 'openssl'
require 'net/http'
require 'nokogiri'
require 'faraday'

module WeixinPublic

class WeixinObject
  def initialize(params)
    params.each { |var,val| self.send "#{var}=", val if self.class.instance_methods.include?(var.to_sym)}
  end
end

class AppMsg < WeixinObject
  attr_accessor :appId,:title,:time
end

class WeixinFan < WeixinObject
  attr_accessor :fakeId,:nickName,:remarkName,:groupId
end

class WeixinMessage < WeixinObject
  attr_accessor :fileId,:source,:fakeId,:hasReply,:nickName,:remarkName,:dateTime,:id,:type,:content

  def filePath
    file_type = {"2"=>"jpg","3"=>"mp3","4"=>"mp4"}[@type]
    "#{@id}.#{file_type}"
  end

  def fileType
    filetype={"2"=>"image/jpg","3"=>"audio/mp3","4"=>"video/mp4"}[@type]
  end
end

  
class WeixinPubClient
  def initialize(username,password,sig=nil,cert=nil)
    @username=username
    @password=password
    @sig = sig
    @cert = cert
    @conn = Faraday.new(:url => 'https://mp.weixin.qq.com')
    @conn_multipart = Faraday.new(:url => 'https://mp.weixin.qq.com') do |faraday|
      faraday.request :multipart
      faraday.adapter :net_http      
    end
  end
  

  def login(username,pwd)
    puts "login with#{username}-#{pwd}"
    pwd = Digest::MD5.hexdigest(pwd)

    @cookie = @cert?"cert=#{@cert}":""
    params = {"username"=>username,"pwd"=>pwd,"imgcode"=>'',"f"=>'json'} 
    ret = request(:post,'/cgi-bin/login?lang=zh_CN',params,nil)
    return 'login failed' if !ret.headers["set-cookie"] 
    ret.headers["set-cookie"].split(',').each do |c|
      @cookie << c.split(';')[0] <<";"
    end
    msg = JSON.parse(ret.body)["ErrMsg"]
    @token = msg[msg =~ /token/..-1].split('=')[1]
    ret = request(:get,"/cgi-bin/indexpage?token=#{@token}&t=wxm-index&lang=zh_CN",{"f"=>'json'},nil)
    return ret.status.to_s
  end
  
  def get_fans
    return if !@cookie && login(@username,@password) =~ /failed/
    ret = []
    for i in 0..100 do
      res = request(:get,"/cgi-bin/contactmanagepage?t=wxm-friend&lang=zh_CN&pagesize=&pageidx=0&type=0&groupid=0&pageidx=#{i}",{},nil)
      doc = Nokogiri::HTML(res.body)
      fans = JSON.parse(doc.css('#json-friendList').to_s[/\[.*?\]/m])
      break if fans.length == 0
      fans.each { |f| ret<< WeixinFan.new(f) }
    end
    ret
  end
   
  def get_messages(fakeId,download=false)
    return if !@cookie && login(@username,@password) =~ /failed/
    #doc.force_encoding('gbk')
    #doc.encode!("utf-8", :undef => :replace, :invalid => :replace)
    doc = Nokogiri::HTML(request(:get,"/cgi-bin/singlemsgpage?fromfakeid=#{fakeId}&msgid=&source=&count=20&t=wxm-singlechat&f=json",{},"https://mp.weixin.qq.com/cgi-bin/getmessage").body) 
    messages = doc.css('#json-msgList').to_s.encode("UTF-8", "UTF-8",:invalid => :replace)
    messages = JSON.parse(messages[messages.index(/\[/)..messages.rindex(/\]/)])
    ret = []
    messages.each do |m| 
      next if m["type"]=="10" || m["fakeId"]!=fakeId
      if m["type"]!="10" then
        ret << WeixinMessage.new(m)
        ret[-1].dateTime = Time.at(m["dateTime"].to_i)
      end
      if download then
        download_file(ret[-1])
      end
    end
    ret
  end
  
  def get_messages_number_new(lastmsgid)
    return if !@cookie && login(@username,@password) =~ /failed/
    res = request(:post,"/cgi-bin/getnewmsgnum?t=ajax-getmsgnum&lastmsgid=#{lastmsgid}")
    ret = JSON.parse(res.body)["newTotalMsgCount"]
  end

  def get_messages_today(lastmsgid=0,step=50)
    return if !@cookie && login(@username,@password) =~ /failed/
    offset = 0
    ret = []
    loop do
      params = {"t"=>"ajax-message","lang"=>"zh_CN","count"=>'50',"timeline"=>'1','day'=>'0','cgi'=>'getmessage','offset'=>offset} 
      res = request(:post,"/cgi-bin/getmessage",params,nil)
      messages = JSON.parse(res.body)
      n = 0
      messages.each do |m| 
        break if m["id"].to_i <= lastmsgid
        ret << WeixinMessage.new(m)
          ret[-1].dateTime = Time.at(m["dateTime"].to_i)
          n = n+1
      end
      break if n < step
      offset = offset + step
    end
    ret
  end
  
  def download_file(message)
    url="/cgi-bin/downloadfile?msgid=#{message.id}&source="
    avatar_download(message.filePath,url)
  end
  
  def send_message(content,reciever,type="1")
    return if !@cookie && login(@username,@password) =~ /failed/
    body = {"error"=>false,"ajax"=>1,"f"=>"json","type"=>type,"tofakeid"=>reciever}
    if type == "1"
      body["content"]=content
    else
      body["fid"]= content
      body["fileid"]=content
    end
    ret = request(:post,"/cgi-bin/singlesend?t=ajax-response&lang=zh_CN",body,"https://mp.weixin.qq.com/cgi-bin/singlemsgpage")
  end
  
  def send_appmsg(appmsgid,reciever)
    return if !@cookie && login(@username,@password) =~ /failed/
    body = {"error"=>false,"ajax"=>1,"f"=>"json","tofakeid"=>reciever,"fid"=>appmsgid,"appmsgid"=>appmsgid,"type"=>10}
    ret = request(:post,"/cgi-bin/singlesend?t=ajax-response&lang=zh_CN",body,"https://mp.weixin.qq.com/cgi-bin/singlemsgpage")
  end


  def avatar_upload(avatar,type="image/png")
    return nil if !@cookie && login(@username,@password) =~ /failed/
    payload = { :uploadFile => Faraday::UploadIO.new(avatar, type)}
    @conn_multipart.headers["Cookie"] = @cookie
    @conn_multipart.headers["Referer"]="http://mp.weixin.qq.com/cgi-bin/indexpage"
    ret=@conn_multipart.post "/cgi-bin/uploadmaterial?cgi=uploadmaterial&type=0&token=#{@token}&t=iframe-uploadfile&lang=zh_CN&formId=null&f=json",payload
    return ret.body.to_s[/\'.*?\'/m][1..-2] if ret.body =~ /suc/m
    return nil
  end

  def create_appmsg(title,avatar,content,desc="")
    return nil if !@cookie && login(@username,@password) =~ /failed/
    if avatar =~ /^http/ then
    end
    fileid = avatar_upload(avatar)
    return nil if !fileid
    params = {:error=>false,:count=>1,:title0=>title,:digest0=>desc,:content0=>content,:fileid0=>fileid,:ajax=>1,:sub=>"create"} 
    ret = request(:post,"/cgi-bin/operate_appmsg?t=ajax-response&lang=zh_CN",params,"https://mp.weixin.qq.com/cgi-bin/operate_appmsg")
    print ret.body
    lst=get_appmsg_lst
    return lst[0].appId if lst
    return nil
  end

  def get_appmsg_lst
    return nil if !@cookie && login(@username,@password) =~ /failed/
    ret = request(:get,"/cgi-bin/operate_appmsg?sub=list&t=wxm-appmsgs-list-new&type=10&pageIdx=0&pagesize=10&subtype=3&f=json",{},nil)
    doc = Nokogiri::HTML(ret.body)
    posts = doc.css('#json-msglist').to_s
    posts = JSON.parse(posts[posts.index(/{/)..posts.rindex(/}/)])["list"]
    ret = []
    posts.each {|po| ret << AppMsg.new(po)}
    ret
  end

  def avatar_download(file,url)
    puts "download-#{url}"
    ret = request(:get,url,{},nil)
    File.open(file, 'wb') { |fp| fp.write(ret.body) }
  end

  #type:1 -edit mode 2 -dev mode  4 -auto-reply
  def operadvancedfunc(type=1,on_off = 0)
    return nil if !@cookie && login(@username,@password) =~ /failed/
    ret = request(:post,"/cgi-bin/operadvancedfunc?op=switch&lang=zh_CN",{:flag=>on_off,:type=>type,:ajax=>1},nil)
  end

  def switch_dev_mode
    operadvancedfunc(4,0)
    operadvancedfunc(1,0)
    operadvancedfunc(2,1)
  end

  def set_dev_callback(url, token)
    return nil if !@cookie && login(@username,@password) =~ /failed/
    ret = request(:post,"/cgi-bin/callbackprofile?t=ajax-response&lang=zh_CN",{:url=>url,:callback_token=>token,:ajax=>1},nil)
  end

  def request(method,url,params,referer)
    @conn.headers["Cookie"] = @cookie
    @conn.headers["Referer"] = referer if referer
    if method == :post then
      ret = @conn.post do |req|
        req.url url
        req.body = params
        req.body['token']=@token
      end
    else
      ret = @conn.get do |req|
        req.url url
        @conn.params['token']=@token
        #@conn.params['lang']="zh_CN"
      end
    end
    ret
  end

end

end
