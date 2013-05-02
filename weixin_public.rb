require 'digest'
require 'faraday'
require 'json'
require 'net/http'
require 'nokogiri'

module  WeixinPublicClient
class AppMsg
  attr_accessor :appId,:title,:time
  def initialize(appId,title,time)
    @appId=appId
    @title=title
    @time=time
  end
end

class WeixinFan
  attr_accessor :fakeId,:nickName,:remarkName,:groupId
  def initialize(params)
    params.each{|var,val| self.send "#{var}=", val}
  end
end

class WeixinMessage
  attr_accessor :fileId,:source,:fakeId,:hasReply,:nickName,:remarkName,:dateTime,:id,:type,:content
  def initialize(params)
    params.each{|var,val| self.send "#{var}=", val}
  end

  def filePath
    file_type = {"2"=>"jpg","3"=>"mp3","4"=>"mp4"}[@type]
    "#{@id}.#{file_type}"
  end

  def fileType
    filetype={"2"=>"image/jpg","3"=>"audio/mp3","4"=>"video/mp4"}[@type]
  end
end

  
class WeixinPubClient
  def initialize(username,password)
    @username=username
    @password=password
    @conn = Faraday.new(:url => 'http://mp.weixin.qq.com')
    @conn_multipart = Faraday.new(:url => 'http://mp.weixin.qq.com') do |faraday|
      faraday.request :multipart
      faraday.adapter :net_http      
    end
  end
  

  def login(username,pwd)
    @cookie=''
    params = {"username"=>username,"pwd"=>Digest::MD5.hexdigest(pwd),"imgcode"=>'',"f"=>'json',"register"=>0} 
    ret = request(:post,'/cgi-bin/login?lang=zh_CN',params,nil)
    return 'login failed' if !ret.headers["set-cookie"] 
    ret.headers["set-cookie"].split(',').each do |c|
      @cookie << c.split(';')[0] <<";"
    end
    msg = JSON.parse(ret.body)["ErrMsg"]
    puts msg
    @token = msg[msg =~ /token/..-1].split('=')[1]
    ret = request(:get,"/cgi-bin/indexpage?token=#{@token}&t=wxm-index&lang=zh_CN",{"f"=>'json'},nil)
    return ret.status.to_s
  end
  
  def get_fans
    login(@username,@password) if !@cookie
    ret = []
    for i in 0..100 do
      res = request(:get,"/cgi-bin/contactmanagepage?t=wxm-friend&lang=zh_CN&pagesize=&pageidx=0&type=0&groupid=0&pageidx=#{i}",{},nil)
      doc = Nokogiri::HTML(res.body)
      fans = JSON.parse(doc.css('#json-friendList').to_s[/\[.*?\]/m])
      puts "fans.length=#{fans.length}"
      break if fans.length == 0
      fans.each do |u|
        ret<< WeixinFan.new(:fakeId=>u["fakeId"],:nickName=>u["nickName"],:remarkName=>u["remarkName"],:groupId=>["groupId"])
      end
    end
    ret
  end
  
  def get_posts
    login(@username,@password) if !@cookie
    ret = request(:get,"/cgi-bin/operate_appmsg?sub=list&t=wxm-appmsgs-list-new&type=10&pageIdx=0&pagesize=10&subtype=3&f=json",{},nil)
    doc = Nokogiri::HTML(ret.body)
    posts = doc.css('#json-msglist').to_s
    posts = JSON.parse(posts[posts.index(/{/)..posts.rindex(/}/)])["list"]
    ret = []
    posts.each do |po|
      ret << AppMsg.new(po["appId"],po["title"],po["time"])
    end
    ret
  end
   
  def get_messages(fakeId,download=false)
    login(@username,@password) if !@cookie
    #doc.force_encoding('gbk')
    #doc.encode!("utf-8", :undef => :replace, :invalid => :replace)
    doc = Nokogiri::HTML(request(:get,"/cgi-bin/singlemsgpage?fromfakeid=#{fakeId}&msgid=&source=&count=20&t=wxm-singlechat&f=json",{},"https://mp.weixin.qq.com/cgi-bin/getmessage").body) 
    messages = doc.css('#json-msgList').to_s.encode("UTF-8", "UTF-8",:invalid => :replace)
    messages = JSON.parse(messages[messages.index(/\[/)..messages.rindex(/\]/)])
    ret = []
    messages.each do |m| 
      next if m["type"]=="10" || m["fakeId"]!=fakeId
      ret << WeixinMessage.new(:dateTime=>Time.at(m["dateTime"].to_i),:id=>m["id"],:type=>m["type"],:content=>m["content"],:fileId=>m["fileId"]) if m["type"]!="10"
      if download then
        download_file(ret[-1])
      end
    end
    ret
  end
  
  def download_file(message)
    url="/cgi-bin/downloadfile?msgid=#{message.id}&source="
    avatar_download(message.filePath,url)
  end
  
  def send_message(content,type,reciever)
    return if !@cookie && login(@username,@password) =~ /failed/
    body = {"error"=>false,"ajax"=>1,"f"=>"json","type"=>type,"tofakeid"=>reciever}
    if type == "1"
      body["content"]=content
    else
      body["fid"]= content
      body["fileid"]=content
    end
    body["tofakeid"]=reciever if reciever
    ret = request(:post,"/cgi-bin/singlesend?t=ajax-response&lang=zh_CN",body,"http://mp.weixin.qq.com/cgi-bin/singlemsgpage")
    puts ret.body
  end
  
  def send_post(appmsgid,reciever)
    login(@username,@password) if !@cookie
    body = {"error"=>false,"ajax"=>1,"f"=>"json","tofakeid"=>reciever,"fid"=>appmsgid,"appmsgid"=>appmsgid,"type"=>10}
    ret = request(:post,"/cgi-bin/singlesend?t=ajax-response&lang=zh_CN",body,"http://mp.weixin.qq.com/cgi-bin/singlemsgpage")
  end


  def avatar_upload(avatar,type="image/png")
    login(@username,@password) if !@cookie
    payload = { :uploadFile => Faraday::UploadIO.new(avatar, type)}
    @conn_multipart.headers["Cookie"] = @cookie
    @conn_multipart.headers["Referer"]="http://mp.weixin.qq.com/cgi-bin/indexpage"
    ret=@conn_multipart.post "/cgi-bin/uploadmaterial?cgi=uploadmaterial&type=0&token=#{@token}&t=iframe-uploadfile&lang=zh_CN&formId=null&f=json",payload
    return ret.body.to_s[/\'.*?\'/m][1..-2] if ret.body =~ /suc/m
    return nil
  end
  
  def avatar_download(file,url)
    puts "download-#{url}"
    ret = request(:get,url,{},nil)
    File.open(file, 'wb') { |fp| fp.write(ret.body) }
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
