require 'test/unit'
require 'weixin_public'
require 'openssl'
OpenSSL::SSL::VERIFY_PEER = OpenSSL::SSL::VERIFY_NONE
class WeixinPublicTest < Test::Unit::TestCase
  def setup
    @client = WeixinPublic::WeixinPubClient.new('zxy@gmail.com','123','sig','bMbmzRlrzlr5zjYNcoDWvSrtDZS06nki[cert]')
    @fakeId = "1234567" #=>user who you want to send a message
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
