# -*- encoding : utf-8 -*-
require File.expand_path(File.join(File.dirname(__FILE__), 'test_helper'))

class WeixinPublicTest < Test::Unit::TestCase
  def setup
    @client = WeixinPublicClient::WeixinPubClient.new('xyz@gmail.com','123','h00e64311efdcad015682762ccbe4f99097bd1ac75922b7a6470d225d94d5a227e796c791ca6a01a8c9','aVWBLC0Gc0VfdOYVgpsIdj0foetJ6Vye') 
    @fakeId = '1234567'#=>user who you want to send a message
    @pic_file = "avatar.jpg" 
  end


  def test_fans
    @client.get_fans.each {|f| p "#{f.fakeId}-#{f.nickName}"}
  end

  def test_send
    puts @client.send_message("hello",@fakeId)
  end

  def test_read
    @client.get_messages(@fakeId).each {|m| p "#{m.dateTime} << #{m.content}"} 
  end

  def ntest_upload
    puts @client.avatar_upload(@pic_file)
  end
end
