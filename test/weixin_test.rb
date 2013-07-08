require 'test/unit'
require 'weixin_public'
#require File.expand_path('../../lib/weixin_public.rb', __FILE__)
require 'openssl'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
class WeixinPublicTest < Test::Unit::TestCase
  def setup
    @client = WeixinPublic::WeixinPubClient.new('xyz@gmail.com','abc')
    @fakeId = "1234567" #=>user who you want to send a message
    @pic_file = "avatar.jpg" 
  end

  def ntest_fans
    @client.get_fans.each {|f| p "#{f.fakeId}-#{f.nickName}"}
  end

  def ntest_create_appmsg
  	@client.create_appmsg(Time.new.to_s,'/home/liteng/teng.png','conetnt')
  end

  def ntest_app_lst
  	po = @client.get_appmsg_lst.each{|m| print "#{m.appId}-#{m.time}\n"}  	
  end

  def ntest_send
    puts @client.send_message("hello",@fakeId)
  end

  def ntest_send
    puts @client.send_appmsg("hello",@fakeId)
  end

  def ntest_read
    @client.get_messages(@fakeId).each {|m| p "#{m.dateTime} << #{m.content}"} 
  end

  def ntest_upload
    puts @client.avatar_upload(@pic_file)
  end

  def test_set_callback
    @client.operadvancedfunc(2,1)
    @client.set_dev_callback("http://wxpt2.cfapps.io/","abc")
  end
end
